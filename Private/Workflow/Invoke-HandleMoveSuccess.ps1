function Invoke-HandleMoveSuccess {
    <#
    .SYNOPSIS
        Handle folder rename/move result, target folder move, and audio file reload.
    .DESCRIPTION
        After Invoke-OMFolderRename completes, this function handles:
        - WhatIf preview messages
        - Updating album path and reloading audio files from new path
        - Moving album to TargetFolder if specified
        - Cleaning up empty parent folders
        - Setting TargetFolderMoved flag in Context

    .PARAMETER Context
        Hashtable with mutable shared state: Album, AudioFiles, PairedTracks,
        RefreshTracks, TargetFolderMoved, IsSingleAlbumPath.
    #>
    param(
        $MoveResult,
        [bool]$UseWhatIf,
        [string]$OldPath,
        [string]$TargetFolder,
        [switch]$NonInteractive,
        [switch]$GoC,
        [hashtable]$Context
    )

    if ($MoveResult -and $MoveResult.Success) {
        if ($UseWhatIf) {
            Write-Host "WhatIf: album would be moved:" -ForegroundColor Yellow
            Write-Host -NoNewline -ForegroundColor Green "Old: "
            Write-Host $OldPath
            Write-Host -NoNewline -ForegroundColor Green "New: "
            Write-Host $MoveResult.NewAlbumPath
            if ($MoveResult.NewAlbumPath -ne $OldPath -and -not ($NonInteractive -or $GoC) -and -not $UseWhatIf) {
                Read-Host -Prompt "Press Enter to continue"
            }
            else {
                Write-Verbose "NonInteractive/goC/WhatIf or no-path-change: skipping pause after move."
            }
            Write-Host "Album saved. Choose 's' to skip to next album, or select another option." -ForegroundColor Yellow
        }
        else {
            if ($MoveResult.NewAlbumPath -ne $OldPath) {
                # Folder was moved/renamed - update album and reload audio files from new location
                $Context.Album = Get-Item -LiteralPath $MoveResult.NewAlbumPath

                # Dispose old TagFile handles before reload to avoid orphaned handles
                if ($Context.PairedTracks -and $Context.PairedTracks.Count -gt 0) {
                    foreach ($pt in $Context.PairedTracks) {
                        if ($pt.AudioFile -and $pt.AudioFile.TagFile) {
                            try { $pt.AudioFile.TagFile.Dispose() } catch { }
                        }
                    }
                }

                # Reload audio files with fresh TagLib handles from the NEW album path
                $Context.AudioFiles = Reload-OMAudioFiles -AlbumPath $Context.Album.FullName
                # Update paired tracks with reloaded audio files to reflect updated tags
                if ($Context.PairedTracks -and $Context.PairedTracks.Count -gt 0) {
                    for ($i = 0; $i -lt [Math]::Min($Context.PairedTracks.Count, $Context.AudioFiles.Count); $i++) {
                        $Context.PairedTracks[$i].AudioFile = $Context.AudioFiles[$i]
                    }
                }
                $Context.RefreshTracks = $true
            }

            # Handle TargetFolder move if specified
            if ($TargetFolder) {
                Write-Verbose "TargetFolder specified: $TargetFolder"
                $currentPath = $Context.Album.FullName
                $folderName = Split-Path $currentPath -Leaf
                $originalParentFolder = Split-Path $currentPath -Parent
                Write-Verbose "Current album path: $currentPath"
                Write-Verbose "Folder name: $folderName"

                # Get AlbumArtist from the first audio file's tags
                $albumArtistName = 'Unknown Artist'
                $audioFiles = $Context.AudioFiles
                if ($audioFiles -and $audioFiles.Count -gt 0 -and $audioFiles[0].PSObject.Properties['FilePath']) {
                    Write-Verbose "Found $($audioFiles.Count) audio files for AlbumArtist extraction"
                    try {
                        $firstFilePath = $audioFiles[0].FilePath
                        Write-Verbose "Reading AlbumArtist from: $firstFilePath"
                        if ($audioFiles[0].PSObject.Properties['TagFile'] -and $audioFiles[0].TagFile) {
                            try { $audioFiles[0].TagFile.Dispose() } catch { }
                            Write-Verbose "Disposed existing TagFile handle"
                        }
                        $tempTag = [TagLib.File]::Create($firstFilePath)
                        try {
                            Write-Verbose "Reloaded TagFile for AlbumArtist check"
                            if ($tempTag.Tag.AlbumArtists -and $tempTag.Tag.AlbumArtists.Count -gt 0) {
                                $albumArtistName = $tempTag.Tag.AlbumArtists[0]
                                Write-Verbose "Read AlbumArtist from saved tags for TargetFolder: $albumArtistName"
                            }
                            elseif ($tempTag.Tag.FirstAlbumArtist) {
                                $albumArtistName = $tempTag.Tag.FirstAlbumArtist
                                Write-Verbose "Read FirstAlbumArtist from saved tags for TargetFolder: $albumArtistName"
                            }
                            else {
                                Write-Verbose "No AlbumArtist found in tags, using default: $albumArtistName"
                            }
                        }
                        finally {
                            $tempTag.Dispose()
                        }
                    }
                    catch {
                        Write-Warning "Could not extract AlbumArtist from tags: $($_.Exception.Message)"
                    }
                }

                # Sanitize album artist name for folder creation
                $albumArtistName = Approve-PathSegment -Segment $albumArtistName -Replacement '_' -CollapseRepeating -Transliterate

                # Ensure target directory exists
                if (-not (Test-Path -LiteralPath $TargetFolder)) {
                    Write-Verbose "Creating target directory: $TargetFolder"
                    New-Item -Path $TargetFolder -ItemType Directory -Force | Out-Null
                }

                # Create artist subdirectory in target folder
                $artistFolder = Join-Path $TargetFolder $albumArtistName
                if (-not (Test-Path -LiteralPath $artistFolder)) {
                    Write-Verbose "Creating artist directory: $artistFolder"
                    New-Item -Path $artistFolder -ItemType Directory -Force | Out-Null
                }

                # Calculate target path with duplicate handling
                $targetPath = Join-Path $artistFolder $folderName
                if (Test-Path -LiteralPath $targetPath) {
                    $n = 2
                    while (Test-Path -LiteralPath (Join-Path $artistFolder "$folderName ($n)")) {
                        $n++
                    }
                    $targetPath = Join-Path $artistFolder "$folderName ($n)"
                    Write-Verbose "Duplicate folder detected. Using: $targetPath"
                }

                # Move album to target folder
                Write-Host "Moving album to target folder: $targetPath" -ForegroundColor Cyan
                $cwdInsideForTarget = $false
                $resolvedCurrentPath = (Resolve-Path -LiteralPath $currentPath -ErrorAction SilentlyContinue).ProviderPath
                $cwdNow = (Get-Location).ProviderPath
                if ($resolvedCurrentPath -and $cwdNow -and
                    ($cwdNow -eq $resolvedCurrentPath -or $cwdNow.StartsWith($resolvedCurrentPath + [System.IO.Path]::DirectorySeparatorChar))) {
                    $cwdInsideForTarget = $true
                    Push-Location -LiteralPath (Split-Path -Parent $resolvedCurrentPath)
                }
                try {
                    Move-Item -LiteralPath $currentPath -Destination $targetPath -Force
                }
                finally {
                    if ($cwdInsideForTarget) {
                        Pop-Location
                        if (Test-Path -LiteralPath $targetPath -PathType Container) {
                            Set-Location -LiteralPath $targetPath
                        }
                    }
                }

                # Clean up empty parent folder
                $shouldCleanupParent = $originalParentFolder -and
                                       (Test-Path -LiteralPath $originalParentFolder) -and
                                       (-not $Context.IsSingleAlbumPath)

                if ($shouldCleanupParent) {
                    $remainingItems = @(Get-ChildItem -LiteralPath $originalParentFolder -Force)
                    if ($remainingItems.Count -eq 0) {
                        Write-Verbose "Removing empty parent folder: $originalParentFolder"
                        Remove-Item -LiteralPath $originalParentFolder -Force
                        Write-Host "Cleaned up empty folder: $originalParentFolder" -ForegroundColor Gray
                    }
                    else {
                        Write-Verbose "Parent folder not empty ($(($remainingItems.Count)) items remaining), keeping it"
                    }
                }
                elseif ($Context.IsSingleAlbumPath) {
                    Write-Verbose "Single album mode: Skipping parent folder cleanup to preserve original folder structure"
                }

                # Update album and reload audio files from new location
                $Context.Album = Get-Item -LiteralPath $targetPath

                # Dispose old TagLib handles before reloading
                if ($Context.PairedTracks -and $Context.PairedTracks.Count -gt 0) {
                    foreach ($pt in $Context.PairedTracks) {
                        if ($pt.AudioFile -and $pt.AudioFile.TagFile) {
                            try { $pt.AudioFile.TagFile.Dispose() } catch { }
                        }
                    }
                }

                # Reload audio files with fresh TagLib handles from the target path
                $Context.AudioFiles = Reload-OMAudioFiles -AlbumPath $Context.Album.FullName

                # Update paired tracks with reloaded audio files
                if ($Context.PairedTracks -and $Context.PairedTracks.Count -gt 0) {
                    for ($i = 0; $i -lt [Math]::Min($Context.PairedTracks.Count, $Context.AudioFiles.Count); $i++) {
                        $Context.PairedTracks[$i].AudioFile = $Context.AudioFiles[$i]
                    }
                }

                # Album has been moved to target folder
                $Context.TargetFolderMoved = $true
                Write-Host "Album saved and moved to target folder." -ForegroundColor Green
            }

            # After TargetFolder logic, show appropriate message
            if ($TargetFolder) {
                # Already handled above with TargetFolderMoved
            }
            elseif ($MoveResult.NewAlbumPath -ne $OldPath) {
                Write-Host "Album saved and folder renamed. Choose 's' to skip to next album, or select another option." -ForegroundColor Yellow
            }
            else {
                Write-Verbose "Move result indicates no change to album path; continuing."
                Write-Host "Album saved. Choose 's' to skip to next album, or select another option." -ForegroundColor Yellow
            }
        }
    }
    else {
        Write-Warning "Move failed or was skipped. Move result: $MoveResult"
    }
}

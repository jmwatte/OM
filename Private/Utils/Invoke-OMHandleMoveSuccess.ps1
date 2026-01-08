function Invoke-OMHandleMoveSuccess {
    <#
    .SYNOPSIS
        Handles post-move operations after album folder is moved.
    
    .DESCRIPTION
        Updates State with new album path, reloads audio files, updates paired tracks,
        and optionally moves album to TargetFolder.
    
    .PARAMETER MoveResult
        The result object from the folder move operation.
    
    .PARAMETER UseWhatIf
        Whether running in WhatIf mode.
    
    .PARAMETER OldPath
        The original album path before the move.
    
    .PARAMETER State
        The workflow State object to update.
    
    .PARAMETER TargetFolder
        Optional target folder to move the album to after tagging.
    
    .PARAMETER Context
        UI context for Show-Message calls.
    
    .PARAMETER NonInteractive
        Whether running in non-interactive mode.
    
    .PARAMETER GoC
        Whether to continue automatically (goC flag).
    
    .PARAMETER AudioFiles
        Current audio files collection (for TargetFolder move).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $MoveResult,
        
        [Parameter(Mandatory)]
        [bool]$UseWhatIf,
        
        [Parameter(Mandatory)]
        [string]$OldPath,
        
        [Parameter(Mandatory)]
        [PSCustomObject]$State,
        
        [string]$TargetFolder,
        
        $Context,
        
        [switch]$NonInteractive,
        
        [switch]$GoC,
        
        $AudioFiles
    )

    if (-not $MoveResult -or -not $MoveResult.Success) {
        Write-Warning "Move failed or was skipped. Move result: $MoveResult"
        return
    }

    if ($UseWhatIf) {
        Show-Message -Message "WhatIf: album would be moved:" -ForegroundColor Yellow -Context $Context
        Show-Message -Message "Old: " -ForegroundColor Green -NoNewline -Context $Context
        Show-Message -Message $OldPath -Context $Context
        Show-Message -Message "New: " -ForegroundColor Green -NoNewline -Context $Context
        Show-Message -Message $MoveResult.NewAlbumPath -Context $Context
        if ($MoveResult.NewAlbumPath -ne $OldPath -and -not ($NonInteractive -or $GoC) -and -not $UseWhatIf) {
            Prompt-PressEnter -Context $Context
        }
        else {
            Write-Verbose "NonInteractive/goC/WhatIf or no-path-change: skipping pause after move."
        }
        Show-Message -Message "Album saved. Choose 's' to skip to next album, or select another option." -ForegroundColor Yellow -Context $Context
        return
    }

    # Not WhatIf - actual move occurred
    if ($MoveResult.NewAlbumPath -eq $OldPath) {
        Write-Verbose "Move result indicates no change to album path; continuing."
        # Even if folder wasn't renamed, check if we need to move to TargetFolder
        if (-not $TargetFolder) {
            Show-Message -Message "Album saved. Choose 's' to skip to next album, or select another option." -ForegroundColor Yellow -Context $Context
            return
        }
        # TargetFolder specified - proceed to move logic below
    }
    else {
        # Folder was moved/renamed - update State and reload audio files
        $State.Album = Get-Item -LiteralPath $MoveResult.NewAlbumPath
        $State.AudioFiles = Reload-OMAudioFiles -AlbumPath $State.Album.FullName

        # Update paired tracks with reloaded audio files
        if ($State.PairedTracks -and $State.PairedTracks.Count -gt 0) {
            for ($i = 0; $i -lt [Math]::Min($State.PairedTracks.Count, $State.AudioFiles.Count); $i++) {
                if ($State.PairedTracks[$i].AudioFile.TagFile) {
                    try { $State.PairedTracks[$i].AudioFile.TagFile.Dispose() } catch { Write-Verbose "Dispose failed: $($_.Exception.Message)" }
                }
                $State.PairedTracks[$i].AudioFile = $State.AudioFiles[$i]
            }
        }
        $State.RefreshTracks = $true  # Trigger display refresh
    }

    # Handle TargetFolder move if specified
    if ($TargetFolder) {
        Write-Verbose "TargetFolder specified: $TargetFolder"
        $currentPath = $State.Album.FullName
        $folderName = Split-Path $currentPath -Leaf
        $originalParentFolder = Split-Path $currentPath -Parent
        Write-Verbose "Current album path: $currentPath"
        Write-Verbose "Folder name: $folderName"

        # Get AlbumArtist from the first audio file's tags (use State.AudioFiles which has updated paths)
        $albumArtistName = 'Unknown Artist'
        if ($State.AudioFiles -and $State.AudioFiles.Count -gt 0 -and $State.AudioFiles[0].PSObject.Properties['FilePath']) {
            Write-Verbose "Found $($State.AudioFiles.Count) audio files for AlbumArtist extraction"
            try {
                $firstFilePath = $State.AudioFiles[0].FilePath
                Write-Verbose "Reading AlbumArtist from: $firstFilePath"
                # Dispose old handle if exists
                if ($State.AudioFiles[0].PSObject.Properties['TagFile'] -and $State.AudioFiles[0].TagFile) {
                    try { $State.AudioFiles[0].TagFile.Dispose() } catch { Write-Verbose "Dispose failed: $($_.Exception.Message)" }
                    Write-Verbose "Disposed existing TagFile handle"
                }
                # Reload file to read current saved tags
                $tempTag = [TagLib.File]::Create($firstFilePath)
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
                $tempTag.Dispose()
            }
            catch {
                Write-Warning "Could not extract AlbumArtist from tags: $($_.Exception.Message)"
            }
        }

        # Sanitize album artist name for folder creation
        $albumArtistName = Approve-PathSegment -Segment $albumArtistName

        # Ensure target directory exists
        if (-not (Test-Path -LiteralPath $TargetFolder)) {
            Write-Verbose "Creating target directory: $TargetFolder"
            New-Item -Path $TargetFolder -ItemType Directory -Force | Out-Null
        }

        # Create artist subdirectory in target folder
        $artistFolder = Join-PathSafe $TargetFolder $albumArtistName
        if (-not (Test-Path -LiteralPath $artistFolder)) {
            Write-Verbose "Creating artist directory: $artistFolder"
            New-Item -Path $artistFolder -ItemType Directory -Force | Out-Null
        }

        # Calculate target path with duplicate handling
        $targetPath = Join-PathSafe $artistFolder $folderName
        if (Test-Path -LiteralPath $targetPath) {
            $n = 2
            while (Test-Path -LiteralPath (Join-PathSafe $artistFolder "$folderName ($n)")) {
                $n++
            }
            $targetPath = Join-PathSafe $artistFolder "$folderName ($n)"
            Write-Verbose "Duplicate folder detected. Using: $targetPath"
        }

        # Move album to target folder
        if ([string]::IsNullOrWhiteSpace($currentPath)) { throw "Invoke-OMHandleMoveSuccess: currentPath is empty" }
        if ([string]::IsNullOrWhiteSpace($targetPath)) { throw "Invoke-OMHandleMoveSuccess: targetPath is empty" }
        Send-Message -Message "Moving album to target folder: $targetPath" -Color Cyan
        Move-Item -LiteralPath $currentPath -Destination $targetPath -Force

        # Clean up empty parent folder if appropriate
        $shouldCleanupParent = $originalParentFolder -and 
                               (Test-Path -LiteralPath $originalParentFolder) -and
                               (-not $State.IsSingleAlbumPath)

        if ($shouldCleanupParent) {
            $remainingItems = @(Get-ChildItem -LiteralPath $originalParentFolder -Force)
            if ($remainingItems.Count -eq 0) {
                Write-Verbose "Removing empty parent folder: $originalParentFolder"
                Remove-Item -LiteralPath $originalParentFolder -Force
                Show-Message -Message "Cleaned up empty folder: $originalParentFolder" -ForegroundColor Gray -Context $Context
            }
            else {
                Write-Verbose "Parent folder not empty ($(($remainingItems.Count)) items remaining), keeping it"
            }
        }
        elseif ($State.IsSingleAlbumPath) {
            Write-Verbose "Single album mode: Skipping parent folder cleanup to preserve original folder structure"
        }

        # Update State with new location
        $State.Album = Get-Item -LiteralPath $targetPath
        $State.AudioFiles = Reload-OMAudioFiles -AlbumPath $State.Album.FullName

        # Update paired tracks with reloaded audio files
        if ($State.PairedTracks -and $State.PairedTracks.Count -gt 0) {
            for ($i = 0; $i -lt [Math]::Min($State.PairedTracks.Count, $State.AudioFiles.Count); $i++) {
                if ($State.PairedTracks[$i].AudioFile.TagFile) {
                    try { $State.PairedTracks[$i].AudioFile.TagFile.Dispose() } catch { Write-Verbose "Dispose failed: $($_.Exception.Message)" }
                }
                $State.PairedTracks[$i].AudioFile = $State.AudioFiles[$i]
            }
        }
    }

    Show-Message -Message "Album saved and folder moved. Choose 's' to skip to next album, or select another option." -ForegroundColor Yellow -Context $Context
}

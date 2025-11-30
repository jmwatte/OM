function Move-OMTags {
<#
.SYNOPSIS
    Moves album folders and renames files based on audio tags.

.DESCRIPTION
    Move-OMTags processes album folders, moves them to a target directory structure organized by AlbumArtist,
    and renames individual audio files according to a specified pattern. The folder is renamed to "Year - Album"
    format, and files are renamed using tag values like DiscNumber, TrackNumber, and Title.

    This function leverages Get-OMTags to read existing tags and supports -WhatIf for previewing changes.

.PARAMETER Path
    The path to the album folder to process. Can be provided via pipeline.

.PARAMETER TargetFolder
    The root directory where organized albums will be moved. AlbumArtist subfolders will be created here.

.PARAMETER FileRenamePattern
    Template string for renaming files. Supports placeholders like {Disc}, {Track}, {Title}, etc.
    Defaults to "{Disc}.{Track} - {Title}".
    Auto-padding: When {Track} or {Disc} are used without a format specifier, they are
    automatically zero-padded based on TrackCount/DiscCount (e.g., 100 tracks → D3 → 001..100).
    Explicit formats like {Track:D2} or {Disc:D3} override auto-padding.

.PARAMETER WhatIf
    Preview changes without applying them.

.PARAMETER PassThru
    Return detailed operation results for each moved album instead of just the new paths.

.EXAMPLE
    Move-OMTags -Path "C:\Music\Unsorted\Album" -TargetFolder "C:\Music\Organized"

    Moves the album to C:\Music\Organized\AlbumArtist\Year - Album and renames files to "1.1 - Title.mp3" format.

.EXAMPLE
    Move-OMTags -Path "C:\Music\Album" -TargetFolder "C:\Organized" -FileRenamePattern "{Track:D2} - {Title}"

    Moves album and renames files to "01 - Title.mp3" (zero-padded track numbers, no disc number).

.EXAMPLE
    Move-OMTags -Path "C:\Music\Album" -TargetFolder "C:\Organized" -FileRenamePattern "{Artist} - {Title}"

    Moves album and renames files using artist name in filename: "Artist Name - Song Title.mp3".

.EXAMPLE
    Get-OMTags -Path "C:\Music\Albums" -Details | Move-OMTags -TargetFolder "C:\Organized" -WhatIf

    Preview moving and renaming for all albums in the directory.

.EXAMPLE
    Move-OMTags -Path "C:\Music\Album" -TargetFolder "C:\Organized" | Get-OMTags

    Moves the album and pipes the new path to Get-OMTags to read the tags from the moved location.

.NOTES
    Requires TagLib-Sharp for tag reading.
    Uses Approve-PathSegment for safe folder names.
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$TargetFolder,

        [Parameter(Mandatory = $false)]
        [string]$FileRenamePattern = "{Disc}.{Track} - {Title}",

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )

    begin {
        # Ensure TagLib is loaded
        $tagLibLoaded = [System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.FullName -like '*TagLib*' }
        if (-not $tagLibLoaded) {
            Write-Error "TagLib-Sharp is required. Run Get-OMTags first to load it."
            return
        }

        # Import Expand-RenamePattern from Set-OMTags if not available
        if (-not (Get-Command Expand-RenamePattern -ErrorAction SilentlyContinue)) {
            Write-Error "Expand-RenamePattern function not found. Ensure Set-OMTags is loaded."
            return
        }

        $results = @()
    }

    process {
        try {
            # Resolve path to absolute if it's relative
            $resolvedPath = if ([System.IO.Path]::IsPathRooted($Path)) {
                $Path
            } else {
                $currentLocation = Get-Location
                Join-Path $currentLocation.Path $Path
            }
            
            # Validate source path
            if (-not (Test-Path -LiteralPath $resolvedPath -PathType Container)) {
                Write-Warning "Path not found or not a directory: $resolvedPath"
                return
            }

            # Get tags for all files in the album
            $tags = Get-OMTags -Path $resolvedPath -Details
            if (-not $tags -or $tags.Count -eq 0) {
                Write-Warning "No audio files with tags found in: $Path"
                return
            }

            # Force garbage collection to release any lingering TagLib file handles
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
            Start-Sleep -Milliseconds 100

            # Sort tags by Disc and Track numbers numerically to avoid string sorting issues
            # This ensures cd1, cd2, ..., cd9, cd10, cd11 instead of cd1, cd10, cd11, ..., cd2
            $tags = $tags | Sort-Object -Property @{Expression={if($_.Disc){[int]$_.Disc}else{0}}}, @{Expression={if($_.Track){[int]$_.Track}else{0}}}

            # Determine AlbumArtist (use first non-empty value)
            $albumArtist = $null
            foreach ($tag in $tags) {
                if ($tag.AlbumArtists -and $tag.AlbumArtists.Count -gt 0) {
                    $albumArtist = $tag.AlbumArtists[0]
                    break
                }
            }
            if (-not $albumArtist) {
                Write-Warning "No AlbumArtist found in tags for: $Path"
                return
            }

            # Sanitize AlbumArtist for folder name
            $safeArtistName = Approve-PathSegment -Segment $albumArtist -Replacement '_' -CollapseRepeating -Transliterate

            # Determine Year and Album from tags or folder name
            $year = $null
            $albumName = $null
            foreach ($tag in $tags) {
                if ($tag.Year) { $year = $tag.Year; break }
            }
            foreach ($tag in $tags) {
                if ($tag.Album) { $albumName = $tag.Album; break }
            }
            if (-not $albumName) {
                $albumName = Split-Path -Leaf $Path
            }

            # Sanitize album name
            $safeAlbumName = Approve-PathSegment -Segment $albumName -Replacement '_' -CollapseRepeating -Transliterate

            # Construct new folder name
            $newFolderName = if ($year) { "$year - $safeAlbumName" } else { $safeAlbumName }

            # Ensure target directory exists
            if (-not (Test-Path -LiteralPath $TargetFolder)) {
                New-Item -Path $TargetFolder -ItemType Directory -Force | Out-Null
            }

            # Create artist subdirectory
            $artistFolder = Join-Path $TargetFolder $safeArtistName
            if (-not (Test-Path -LiteralPath $artistFolder)) {
                New-Item -Path $artistFolder -ItemType Directory -Force | Out-Null
            }

            # Calculate target path with duplicate handling
            $targetPath = Join-Path $artistFolder $newFolderName
            if (Test-Path -LiteralPath $targetPath) {
                $n = 2
                while (Test-Path -LiteralPath (Join-Path $artistFolder "$newFolderName ($n)")) {
                    $n++
                }
                $targetPath = Join-Path $artistFolder "$newFolderName ($n)"
            }

            # Move the folder - use simple approach with retry logic for file locks
            $folderMoved = $false
            if ($PSCmdlet.ShouldProcess($resolvedPath, "Move to $targetPath")) {
                # Ensure source path is absolute
                $sourcePath = $resolvedPath
                
                # Check if source contains a single album subfolder
                $sourceContents = Get-ChildItem -LiteralPath $sourcePath -Directory
                $actualSourcePath = $sourcePath
                
                # If source is an artist folder with a single album subfolder, use that as source
                if ($sourceContents.Count -eq 1 -and $sourceContents[0].Name -like "*$albumName*") {
                    $actualSourcePath = $sourceContents[0].FullName
                    Write-Verbose "Detected single album subfolder: $($sourceContents[0].Name)"
                }
                
                # Use a temporary folder to avoid conflicts
                $tempGuid = [System.Guid]::NewGuid().ToString()
                $tempPath = Join-Path $artistFolder $tempGuid
                
                # Retry logic for file lock issues
                $maxRetries = 3
                $retryCount = 0
                $moveSuccess = $false
                
                while (-not $moveSuccess -and $retryCount -lt $maxRetries) {
                    try {
                        # Move source to temp location first
                        Move-Item -LiteralPath $actualSourcePath -Destination $tempPath -Force -ErrorAction Stop
                        
                        # Then rename temp to final name
                        Move-Item -LiteralPath $tempPath -Destination $targetPath -Force -ErrorAction Stop
                        
                        $moveSuccess = $true
                    }
                    catch {
                        $retryCount++
                        $errorMessage = $_.Exception.Message
                        if ($errorMessage -like "*being used by another process*" -or $errorMessage -like "*cannot access the file*") {
                            Write-Verbose "File lock detected, retrying ($retryCount/$maxRetries)... Error: $errorMessage"
                            [System.GC]::Collect()
                            [System.GC]::WaitForPendingFinalizers()
                            Start-Sleep -Milliseconds (200 * $retryCount)
                        }
                        else {
                            # Not a file lock issue, don't retry
                            Write-Error "Failed to move folder: $errorMessage"
                            Write-Error "Source: $actualSourcePath"
                            Write-Error "Temp: $tempPath"
                            Write-Error "Target: $targetPath"
                            return
                        }
                    }
                }
                
                if (-not $moveSuccess) {
                    Write-Error "Failed to move folder after $maxRetries attempts (file locks): $actualSourcePath"
                    return
                }
                
                # Clean up parent folder if it's now empty
                if ($actualSourcePath -ne $sourcePath) {
                    if ((Get-ChildItem -LiteralPath $sourcePath -Force).Count -eq 0) {
                        Remove-Item -LiteralPath $sourcePath -Recurse -Force
                    }
                }
                
                $folderMoved = $true
                Write-Host "Moved folder to: $targetPath" -ForegroundColor Green
            }

            # Rename files
            $renamedFiles = @()
            foreach ($tag in $tags) {
                # Find the actual file location in the moved folder
                $fileName = Split-Path $tag.Path -Leaf
                $currentFilePath = if ($folderMoved) {
                    # Search for the file in target folder (including subdirectories)
                    $foundFiles = Get-ChildItem -LiteralPath $targetPath -Filter $fileName -Recurse -File
                    if ($foundFiles) {
                        $foundFiles[0].FullName
                    } else {
                        Write-Warning "Cannot find file '$fileName' in target folder. Skipping rename."
                        continue
                    }
                } else {
                    $tag.Path
                }
                
                # Auto zero-padding for Track/Disc when pattern omits explicit format
                # Derive widths from counts; fall back to sensible defaults
                $padTrack = if ($tag.TrackCount -and [int]$tag.TrackCount -gt 0) { ($tag.TrackCount).ToString().Length } else { 2 }
                $padDisc  = if ($tag.DiscCount  -and [int]$tag.DiscCount  -gt 0) { ($tag.DiscCount).ToString().Length  } else { 1 }

                $effectivePattern = $FileRenamePattern
                if ($effectivePattern -notmatch '\{Track:[^}]+\}') {
                    $effectivePattern = $effectivePattern -replace '\{Track\}', "{Track:D$padTrack}"
                }
                if ($effectivePattern -notmatch '\{Disc:[^}]+\}') {
                    $effectivePattern = $effectivePattern -replace '\{Disc\}', "{Disc:D$padDisc}"
                }

                $newFileName = Expand-RenamePattern -Pattern $effectivePattern -TagObject $tag -FileExtension ([System.IO.Path]::GetExtension($tag.Path))
                
                # Keep the file in its current subdirectory (CD1, CD2, etc), just rename it
                $currentFileDir = Split-Path $currentFilePath -Parent
                $newFilePath = Join-Path $currentFileDir $newFileName

                if ($PSCmdlet.ShouldProcess($currentFilePath, "Rename to $newFileName")) {
                    Move-Item -LiteralPath $currentFilePath -Destination $newFilePath -Force
                    $renamedFiles += [PSCustomObject]@{
                        OriginalPath = $currentFilePath
                        NewPath      = $newFilePath
                        NewName      = $newFileName
                    }
                }
            }

            if ($renamedFiles.Count -gt 0) {
                Write-Host "Renamed $($renamedFiles.Count) files" -ForegroundColor Green
            }

            # Prepare result for output
            $result = [PSCustomObject]@{
                NewPath = $targetPath
            }
            if ($PassThru) {
                $result | Add-Member -MemberType NoteProperty -Name OriginalPath -Value $resolvedPath
                $result | Add-Member -MemberType NoteProperty -Name AlbumArtist -Value $albumArtist
                $result | Add-Member -MemberType NoteProperty -Name Year -Value $year
                $result | Add-Member -MemberType NoteProperty -Name Album -Value $albumName
                $result | Add-Member -MemberType NoteProperty -Name RenamedFiles -Value $renamedFiles
            }
            $results += $result

        } catch {
            Write-Error "Failed to process $resolvedPath`: $($_.Exception.Message)"
        }
    }

    end {
        if ($PassThru) {
            return $results
        } else {
            return $results.NewPath
        }
    }
}

Set-Alias -Name MOT -Value Move-OMTags -Description "Alias for Move-OMTags"
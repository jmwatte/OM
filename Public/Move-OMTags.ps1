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

.PARAMETER WhatIf
    Preview changes without applying them.

.PARAMETER PassThru
    Return information about the moved folder and renamed files.

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
    Move-OMTags -Path "C:\Music\Classical" -TargetFolder "C:\Organized" -FileRenamePattern "{Track:D2} - {Composers} - {Title}" -PassThru

    For classical music, renames files to "01 - Composer - Title.mp3" and returns operation results.

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

            # Move the folder using a manual copy approach to avoid nesting
            $folderMoved = $false
            if ($PSCmdlet.ShouldProcess($resolvedPath, "Move to $targetPath")) {
                # Ensure source path is absolute
                $sourcePath = $resolvedPath
                
                # Check if source contains a single album subfolder or is the album folder itself
                $sourceContents = Get-ChildItem -LiteralPath $sourcePath -Directory
                $actualSourcePath = $sourcePath
                
                # If source is an artist folder with a single album subfolder, use that as source
                if ($sourceContents.Count -eq 1 -and $sourceContents[0].Name -like "*$albumName*") {
                    $actualSourcePath = $sourceContents[0].FullName
                    Write-Verbose "Detected single album subfolder: $($sourceContents[0].Name)"
                }
                
                # Create target directory
                New-Item -Path $targetPath -ItemType Directory -Force | Out-Null
                
                # Get all items from actual source
                $allItems = Get-ChildItem -LiteralPath $actualSourcePath -Recurse -Force
                
                # Create subdirectories in target (relative to actual source)
                $directories = $allItems | Where-Object { $_.PSIsContainer }
                foreach ($dir in $directories) {
                    $relativePath = $dir.FullName.Substring($actualSourcePath.Length).TrimStart('\', '/')
                    if ($relativePath) {
                        $targetDir = Join-Path $targetPath $relativePath
                        if (-not (Test-Path -LiteralPath $targetDir)) {
                            New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
                        }
                    }
                }
                
                # Move all files (relative to actual source)
                $files = $allItems | Where-Object { -not $_.PSIsContainer }
                foreach ($file in $files) {
                    $relativePath = $file.FullName.Substring($actualSourcePath.Length).TrimStart('\', '/')
                    $targetFile = Join-Path $targetPath $relativePath
                    $targetFileDir = Split-Path $targetFile -Parent
                    if (-not (Test-Path -LiteralPath $targetFileDir)) {
                        New-Item -Path $targetFileDir -ItemType Directory -Force | Out-Null
                    }
                    Move-Item -LiteralPath $file.FullName -Destination $targetFile -Force
                }
                
                # Remove empty source directory (and parent if it was artist folder)
                if ($actualSourcePath -ne $sourcePath) {
                    Remove-Item -LiteralPath $actualSourcePath -Recurse -Force
                    # Also remove parent if now empty
                    if ((Get-ChildItem -LiteralPath $sourcePath -Force).Count -eq 0) {
                        Remove-Item -LiteralPath $sourcePath -Recurse -Force
                    }
                } else {
                    Remove-Item -LiteralPath $sourcePath -Recurse -Force
                }
                
                $folderMoved = $true
                Write-Host "Moved folder to: $targetPath" -ForegroundColor Green
            }

            # Rename files
            $renamedFiles = @()
            foreach ($tag in $tags) {
                # Determine current file location based on whether folder was actually moved
                $currentFilePath = if ($folderMoved) {
                    Join-Path $targetPath $tag.FileName
                } else {
                    $tag.Path
                }
                
                # Debug: Check if file actually exists at expected location
                if ($folderMoved -and -not (Test-Path -LiteralPath $currentFilePath)) {
                    Write-Verbose "File not found at expected location: $currentFilePath"
                    # Try to find the file in subdirectories
                    $foundFiles = Get-ChildItem -LiteralPath $targetPath -Filter $tag.FileName -Recurse -File
                    if ($foundFiles) {
                        $currentFilePath = $foundFiles[0].FullName
                        Write-Verbose "Found file at: $currentFilePath"
                    } else {
                        Write-Warning "Cannot find file '$($tag.FileName)' in target folder. Skipping rename."
                        continue
                    }
                }
                
                $newFileName = Expand-RenamePattern -Pattern $FileRenamePattern -TagObject $tag -FileExtension ([System.IO.Path]::GetExtension($tag.Path))
                $newFilePath = Join-Path $targetPath $newFileName

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

            # Prepare result for PassThru
            if ($PassThru) {
                $result = [PSCustomObject]@{
                    OriginalPath = $resolvedPath
                    NewPath      = $targetPath
                    AlbumArtist  = $albumArtist
                    Year         = $year
                    Album        = $albumName
                    RenamedFiles = $renamedFiles
                }
                $results += $result
            }

        } catch {
            Write-Error "Failed to process $resolvedPath`: $($_.Exception.Message)"
        }
    }

    end {
        if ($PassThru) {
            return $results
        }
    }
}

Set-Alias -Name MOT -Value Move-OMTags -Description "Alias for Move-OMTags"
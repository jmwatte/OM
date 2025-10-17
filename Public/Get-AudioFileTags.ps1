function Get-AudioFileTags {
<#
.SYNOPSIS
    Reads audio file tags using TagLib-Sharp with enhanced classical music support.

.DESCRIPTION
    This function scans a folder or processes individual audio files to extract metadata
    using TagLib-Sharp. It provides special handling for classical music with proper
    composer, performer, and album artist distinction.

.PARAMETER Path
    The path to a folder containing audio files or a single audio file.

.PARAMETER IncludeComposer
    Include detailed composer and classical music analysis in the output.

.PARAMETER LogTo
    Optional path to log detailed tag information for debugging.

.PARAMETER MaxFileSizeMB
    Maximum file size in MB to process (default: 500MB). Larger files are skipped to avoid performance issues.

.PARAMETER AllTags
    Include all available tag properties from the audio file, not just the standard ones.

.OUTPUTS
    Array of PSCustomObject with comprehensive tag fields including classical music metadata, or a single summary object if -Summary is specified. If -AllTags is specified, all TagLib tag properties are included.

.EXAMPLE
    Get-AudioFileTags -Path "C:\Music\Arvo Pärt\1999 - Alina" -IncludeComposer
    
    Reads all audio files with classical music analysis.

.NOTES
    Requires TagLib-Sharp assembly to be loaded.
    Supported formats: .mp3, .flac, .m4a, .ogg, .wav, .wma, .ape (where supported by TagLib)
    Author: jmw
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [switch]$IncludeComposer,
        
        [string]$LogTo,
        
        [long]$MaxFileSizeMB = 500,
        
        [switch]$ShowProgress,
        
        [switch]$Summary,
        
        [switch]$AllTags
    )

    begin {
        # Supported audio file extensions
        $supportedExtensions = @('.mp3', '.flac', '.m4a', '.ogg', '.wav', '.wma', '.ape')
        
        # Extensions that should be skipped without warning
        $excludedExtensions = @('.dll', '.exe', '.pdb', '.xml', '.config', '.json', '.txt', '.md', '.ps1', '.psm1')

        # Check for TagLib-Sharp and offer installation if missing
        $tagLibLoaded = [System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.FullName -like '*TagLib*' }
        
        if (-not $tagLibLoaded) {
            # Try to find and load TagLib-Sharp
            $moduleDir = Split-Path $PSScriptRoot -Parent
            $tagLibPaths = @(
                (Join-Path $moduleDir "lib\TagLib.dll"),                                   # Module lib folder (preferred)
                (Join-Path $PSScriptRoot '..\TagLib-Sharp.dll'),                          # Module root (legacy)
                (Join-Path $PSScriptRoot 'TagLib-Sharp.dll'),                             # Private folder (legacy)
                "$env:USERPROFILE\.nuget\packages\taglib*\lib\*\TagLib.dll",              # NuGet packages
                "$env:USERPROFILE\.nuget\packages\taglibsharp*\lib\*\TagLib.dll",
                "$env:USERPROFILE\.nuget\packages\taglibsharp*\**\TagLib.dll"
            )
            
            $tagLibPath = $null
            foreach ($pathb in $tagLibPaths) {
                if ($pathb -like "*\*") {
                    # Handle wildcard paths for NuGet packages
                    $found = Get-ChildItem -Path $pathb -Recurse -ErrorAction SilentlyContinue | 
                             Where-Object { $_.Name -eq 'TagLib.dll' } | 
                             Select-Object -First 1
                    if ($found) {
                        $tagLibPath = $found.FullName
                        break
                    }
                } elseif (Test-Path $pathb) {
                    $tagLibPath = $pathb
                    break
                }
            }
            
            # If still not found, try a broader search
            if (-not $tagLibPath) {
                $packagesDir = "$env:USERPROFILE\.nuget\packages"
                if (Test-Path $packagesDir) {
                    $found = Get-ChildItem -Path $packagesDir -Name "TagLib.dll" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
                    if ($found) {
                        $tagLibPath = Join-Path $packagesDir $found
                    }
                }
            }
            
            if (-not $tagLibPath) {
                # TagLib-Sharp not found - offer to install
                Write-Host "TagLib-Sharp is required for track tag reading but is not installed." -ForegroundColor Yellow
                Write-Host ""                
                
                # Only prompt if running interactively
                if ([Environment]::UserInteractive -and -not $env:CI) {
                    Write-Host "Would you like to install TagLib-Sharp now? [Y/n]: " -NoNewline -ForegroundColor Cyan
                    $response = Read-Host
                    if ($response -eq '' -or $response -match '^[Yy]') {
                        # Use the helper function if available
                        if (Get-Command Install-TagLibSharp -ErrorAction SilentlyContinue) {
                            try {
                                Install-TagLibSharp
                                Write-Host ""
                                Write-Host "Please restart PowerShell and run your command again to use TagLib-Sharp." -ForegroundColor Yellow
                            } catch {
                                Write-Warning "Installation helper failed: $($_.Exception.Message)"
                                Write-Host "Please try manual installation: Install-Package TagLibSharp" -ForegroundColor Yellow
                            }
                        } else {
                            Write-Host "Installing TagLib-Sharp..." -ForegroundColor Green
                            try {
                                Install-Package TagLibSharp -Scope CurrentUser -Force -SkipDependencies -ErrorAction Stop
                                Write-Host "✓ TagLib-Sharp installed successfully!" -ForegroundColor Green
                                Write-Host "Please restart PowerShell and try again." -ForegroundColor Yellow
                            } catch {
                                Write-Warning "Failed to install TagLib-Sharp: $($_.Exception.Message)"
                                Write-Host ""
                                Write-Host "To install TagLib-Sharp:" -ForegroundColor Yellow
                                Write-Host "  Install-Package TagLibSharp -Force" -ForegroundColor White
                                Write-Host "  -or-" -ForegroundColor Yellow  
                                Write-Host "  Download from: https://www.nuget.org/packages/TagLibSharp/" -ForegroundColor White
                            }
                        }
                    }
                } else {
                    Write-Host "To install TagLib-Sharp:" -ForegroundColor Yellow
                    Write-Host "  Install-Package TagLibSharp" -ForegroundColor White
                    Write-Host "  -or- Use: Install-TagLibSharp (helper function)" -ForegroundColor White
                }
                
                return @()
            }
            
            try {
                Add-Type -Path $tagLibPath
                Write-Verbose "Loaded TagLib-Sharp from $tagLibPath"
            } catch {
                Write-Warning "Failed to load TagLib-Sharp from $tagLibPath`: $($_.Exception.Message)"
                Write-Host "Please try reinstalling TagLib-Sharp:" -ForegroundColor Yellow
                Write-Host "  Install-Package TagLibSharp -Force" -ForegroundColor White
                return @()
            }
        }
    }

    process {
        $results = @()

        # Determine if Path is a file or folder
        if (Test-Path -LiteralPath $Path -PathType Leaf) {
            # Single file - validate it's an audio file
            $fileExtension = [System.IO.Path]::GetExtension($Path).ToLower()
            if ($excludedExtensions -contains $fileExtension) {
                Write-Verbose "Skipping non-audio file: $(Split-Path $Path -Leaf)"
                return @()
            } elseif ($supportedExtensions -contains $fileExtension) {
                $files = @($Path)
            } else {
                Write-Warning "File '$Path' is not a supported audio format"
                return @()
            }
        } elseif (Test-Path -LiteralPath $Path -PathType Container) {
            # Directory - scan for audio files, excluding system/library folders and non-audio files
            $files = Get-ChildItem -LiteralPath $Path -File -Recurse | 
                     Where-Object { 
                         $_.Extension.ToLower() -in $supportedExtensions -and
                         $_.FullName -notlike "*\lib\*" -and
                         $_.FullName -notlike "*\bin\*" -and
                         $_.FullName -notlike "*\.git\*"
                     } | 
                     Select-Object -ExpandProperty FullName
        } else {
            Write-Warning "Path '$Path' does not exist or is not accessible."
            return @()
        }

        Write-Verbose "Processing $($files.Count) audio files (max size: $MaxFileSizeMB MB)"
        
        # Initialize progress tracking
        $processedCount = 0
        $errorCount = 0
        $startTime = Get-Date

        foreach ($file in $files) {
            $processedCount++
            
            # Show progress for large collections
            if ($ShowProgress -and $files.Count -gt 10) {
                $percentComplete = [math]::Round(($processedCount / $files.Count) * 100, 1)
                $elapsed = (Get-Date) - $startTime
                $estimatedTotal = if ($processedCount -gt 0) { $elapsed.TotalSeconds * ($files.Count / $processedCount) } else { 0 }
                $remaining = [TimeSpan]::FromSeconds([math]::Max(0, $estimatedTotal - $elapsed.TotalSeconds))
                
                Write-Progress -Activity "Reading Audio File Tags" `
                              -Status "Processing file $processedCount of $($files.Count) ($percentComplete%)" `
                              -CurrentOperation "$(Split-Path $file -Leaf)" `
                              -PercentComplete $percentComplete `
                              -SecondsRemaining $remaining.TotalSeconds
            }
            
            try {
                Write-Verbose "Reading tags from: $(Split-Path $file -Leaf)"
                
                try {
                    # Check if file is accessible before attempting to read
                if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
                    Write-Warning "File no longer exists: $(Split-Path $file -Leaf)"
                    $errorCount++
                    continue
                }
                
                # Check file size again in case it changed
                $fileInfo = Get-Item -LiteralPath $file
                if ($fileInfo.Length -gt ($MaxFileSizeMB * 1MB)) {
                    Write-Verbose "Skipping large file: $(Split-Path $file -Leaf) ($([math]::Round($fileInfo.Length / 1MB, 1)) MB)"
                    continue
                }
                $fileObj = [TagLib.File]::Create($file)
                #$fileObj = $null
                try {
                    $tag = $fileObj.Tag
                    $properties = $fileObj.Properties
                } catch {
                    # Handle TagLib-specific errors
                    if ($_.Exception.Message -like "*not supported*" -or $_.Exception.Message -like "*corrupted*") {
                        Write-Verbose "Unsupported or corrupted file: $(Split-Path $file -Leaf)"
                    } else {
                        Write-Warning "TagLib error reading '$(Split-Path $file -Leaf)': $($_.Exception.Message)"
                    }
                    $errorCount++
                    continue
                }

                # Extract comprehensive tag information with proper array handling
                $artists = @()
                if ($tag -and $tag.Performers) {
                    if ($tag.Performers -is [array]) {
                        $artists = $tag.Performers
                    } else {
                        $artists = @($tag.Performers)
                    }
                }
                
                $albumArtists = @()
                if ($tag -and $tag.AlbumArtists) {
                    if ($tag.AlbumArtists -is [array]) {
                        $albumArtists = $tag.AlbumArtists
                    } else {
                        $albumArtists = @($tag.AlbumArtists)
                    }
                }
                
                $composers = @()
                if ($tag -and $tag.Composers) {
                    if ($tag.Composers -is [array]) {
                        $composers = $tag.Composers
                    } else {
                        $composers = @($tag.Composers)
                    }
                }
                
                $genres = @()
                if ($tag -and $tag.Genres) {
                    if ($tag.Genres -is [array]) {
                        $genres = $tag.Genres
                    } else {
                        $genres = @($tag.Genres)
                    }
                }

                # Create comprehensive tag object with writable array properties
                $normalizedTag = [PSCustomObject]@{
                    Path            = $file
                    FileName        = [System.IO.Path]::GetFileName($file)
                    Title           = if ($tag -and $tag.Title) { $tag.Title } else { [System.IO.Path]::GetFileNameWithoutExtension($file) }
                    Artists         = $artists
                    AlbumArtists    = $albumArtists
                    Album           = if ($tag -and $tag.Album) { $tag.Album } else { $null }
                    Track           = if ($tag -and $tag.Track) { $tag.Track } else { $null }
                    TrackCount      = if ($tag -and $tag.TrackCount) { $tag.TrackCount } else { $null }
                    Disc            = if ($tag -and $tag.Disc) { $tag.Disc } else { $null }
                    DiscCount       = if ($tag -and $tag.DiscCount) { $tag.DiscCount } else { $null }
                    Year            = if ($tag -and $tag.Year) { $tag.Year } else { $null }
                    Genres          = $genres
                    Composers       = $composers
                    Comment         = if ($tag -and $tag.Comment) { $tag.Comment } else { $null }
                    Lyrics          = if ($tag -and $tag.Lyrics) { $tag.Lyrics } else { $null }
                    Duration        = if ($properties -and $properties.Duration) { $properties.Duration } else { [TimeSpan]::Zero }
                    DurationSeconds = if ($properties -and $properties.Duration) { [double]$properties.Duration.TotalSeconds } else { 0.0 }
                    Bitrate         = if ($properties -and $properties.AudioBitrate) { $properties.AudioBitrate } else { 0 }
                    SampleRate      = if ($properties -and $properties.AudioSampleRate) { $properties.AudioSampleRate } else { 0 }
                    Format          = [System.IO.Path]::GetExtension($file).TrimStart('.')
                }
                
                # Add read-only convenience properties (singular forms) for easy access
                # These are derived from the array properties and should not be modified directly
                $artistValue = if ($artists.Count -gt 0) { $artists[0] } else { $null }
                $normalizedTag | Add-Member -MemberType ScriptProperty -Name 'Artist' -Value {
                    if ($this.Artists.Count -gt 0) { $this.Artists[0] } else { $null }
                } -SecondValue { throw "Artist is read-only. Modify Artists array instead." }
                
                $normalizedTag | Add-Member -MemberType ScriptProperty -Name 'AlbumArtist' -Value {
                    if ($this.AlbumArtists.Count -gt 0) { $this.AlbumArtists[0] } else { if ($this.Artists.Count -gt 0) { $this.Artists[0] } else { $null }}
                } -SecondValue { throw "AlbumArtist is read-only. Modify AlbumArtists array instead." }
                
                $normalizedTag | Add-Member -MemberType ScriptProperty -Name 'Genre' -Value {
                    if ($this.Genres.Count -gt 0) { $this.Genres[0] } else { $null }
                } -SecondValue { throw "Genre is read-only. Modify Genres array instead." }
                
                $normalizedTag | Add-Member -MemberType ScriptProperty -Name 'Composer' -Value {
                    if ($this.Composers.Count -gt 0) { $this.Composers[0] } else { $null }
                } -SecondValue { throw "Composer is read-only. Modify Composers array instead." }

                # Add classical music analysis if requested
                if ($IncludeComposer) {
                    # Enhanced composer extraction (checking comment field as fallback)
                    $composer = $null
                    if ($composers.Count -gt 0) {
                        $composer = $composers[0]
                    } elseif ($tag.Comment -match 'Composer:\s*(.+)') {
                        $composer = $matches[1].Trim()
                    } elseif ($artists -contains "Arvo Pärt" -or $artists -contains "Arvo Part") {
                        $composer = "Arvo Pärt"
                    }

                    # Detect if this is classical music
                    $isClassical = $false
                    $classicalIndicators = @(
                        ($null -ne $composer),
                        ($genres -contains "Classical"),
                        ($normalizedTag.Album -match "(?i)(symphony|concerto|sonata|quartet|opera|oratorio|cantata|mass|requiem|preludes|etudes)"),
                        (($artists -join " ") -match "(?i)(orchestra|symphony|philharmonic|ensemble|quartet|choir|philharmonie)")
                    )
                    $isClassical = $classicalIndicators -contains $true

                    # Analyze contributors for classical music
                    $contributingArtists = @()
                    $conductor = $null
                    if ($isClassical) {
                        foreach ($artist in $artists) {
                            if ($artist -match "(?i)(orchestra|symphony|philharmonic|philharmonie)") {
                                $contributingArtists += @{ Type = "Orchestra"; Name = $artist }
                            } elseif ($artist -match "(?i)(conductor|dirigent)") {
                                $conductor = $artist -replace "(?i),?\s*(conductor|dirigent)", ""
                                $contributingArtists += @{ Type = "Conductor"; Name = $conductor }
                            } elseif ($artist -ne $composer) {
                                $contributingArtists += @{ Type = "Performer"; Name = $artist }
                            }
                        }
                    }

                    # Suggest organization strategy for classical music
                    $suggestedAlbumArtist = $null
                    if ($isClassical) {
                        if ($composer) {
                            $suggestedAlbumArtist = $composer
                        } elseif ($conductor) {
                            $suggestedAlbumArtist = $conductor
                        } elseif ($albumArtists.Count -gt 0) {
                            $suggestedAlbumArtist = $albumArtists[0]
                        } elseif ($artists.Count -gt 0 -and $artists[0] -notmatch "(?i)(orchestra|symphony|philharmonic|various)") {
                            $suggestedAlbumArtist = $artists[0]
                        }
                    }

                    # Add classical music analysis properties (Composer/Composers already in base object)
                    Add-Member -InputObject $normalizedTag -MemberType NoteProperty -Name "IsClassical" -Value $isClassical
                    Add-Member -InputObject $normalizedTag -MemberType NoteProperty -Name "ContributingArtists" -Value $contributingArtists
                    Add-Member -InputObject $normalizedTag -MemberType NoteProperty -Name "Conductor" -Value $conductor
                    Add-Member -InputObject $normalizedTag -MemberType NoteProperty -Name "SuggestedAlbumArtist" -Value $suggestedAlbumArtist
                }

                # If AllTags is requested, add all TagLib tag properties
                if ($AllTags) {
                    $tag.PSObject.Properties | ForEach-Object {
                        if (-not $normalizedTag.PSObject.Properties.Match($_.Name)) {
                            try {
                                Add-Member -InputObject $normalizedTag -MemberType NoteProperty -Name $_.Name -Value $_.Value
                            } catch {
                                # Skip invalid property names or duplicates
                                Write-Verbose "Skipping tag property '$($_.Name)': $($_.Exception.Message)"
                            }
                        }
                    }
                }

                $results += $normalizedTag
                
                # Log detailed information if requested
                if ($LogTo) {
                    $logEntry = @{
                        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                        File = $normalizedTag.FileName
                        Tags = $normalizedTag
                    }
                    $logEntry | ConvertTo-Json -Depth 10 | Add-Content -Path $LogTo
                }
                
                } finally {
                    # Always clean up TagLib resources
                    if ($fileObj) {
                        try {
                            $fileObj.Dispose()
                        } catch {
                            Write-Verbose "Warning: Could not dispose TagLib file object for $(Split-Path $file -Leaf)"
                        }
                    }
                }
                
            } catch {
                $errorCount++
                $errorMsg = "Failed to read tags from '$(Split-Path $file -Leaf)': $($_.Exception.Message)"
                Write-Warning $errorMsg
                
                # Log error if requested
                if ($LogTo) {
                    $errorEntry = @{
                        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                        File = $(Split-Path $file -Leaf)
                        Error = $_.Exception.Message
                    }
                    $errorEntry | ConvertTo-Json | Add-Content -Path $LogTo
                }
            }
        }
        
        # Clear progress display
        if ($ShowProgress -and $files.Count -gt 10) {
            Write-Progress -Activity "Reading Audio File Tags" -Completed
        }
        
        # Performance summary
        $endTime = Get-Date
        $duration = $endTime - $startTime
        $successCount = $results.Count
        
        Write-Verbose "Tag reading complete: $successCount successful, $errorCount errors in $([math]::Round($duration.TotalSeconds, 1))s"
        
        if ($errorCount -gt 0 -and $errorCount -lt $files.Count) {
            Write-Host "Tag reading: $successCount/$($files.Count) files processed successfully" -ForegroundColor Yellow
        } elseif ($successCount -gt 0) {
            Write-Verbose "All $successCount files processed successfully"
        }

        # If Summary is requested, create a summary object with unique values
        if ($Summary) {
            $summaryObj = [PSCustomObject]@{}
            if ($results.Count -gt 0) {
                $properties = $results[0].PSObject.Properties.Name
                foreach ($prop in $properties) {
                    $allValues = @()
                    foreach ($result in $results) {
                        $value = $result.$prop
                        if ($value -is [array]) {
                            $allValues += $value
                        } else {
                            $allValues += $value
                        }
                    }
                    $uniqueValues = $allValues | Where-Object { $_ -ne $null -and $_ -ne '' } | Select-Object -Unique | Sort-Object
                    $summaryObj | Add-Member -MemberType NoteProperty -Name $prop -Value ($uniqueValues -join ', ')
                }
            }
            return $summaryObj
        } else {
            return $results
        }
    }
}
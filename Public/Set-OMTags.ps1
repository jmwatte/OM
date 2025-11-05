function Expand-RenamePattern {
    <#
    .SYNOPSIS
        Expands a rename pattern template with tag values and formatting.
    
    .PARAMETER Pattern
        The template string containing placeholders like {Title}, {Artist}, etc.
    
    .PARAMETER TagObject
        The tag object containing the values to substitute.
    
    .PARAMETER FileExtension
        The original file extension to preserve if not included in pattern.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Pattern,
        
        [Parameter(Mandatory)]
        [PSCustomObject]$TagObject,
        
        [Parameter(Mandatory)]
        [string]$FileExtension
    )
    
    $result = $Pattern
    
    # Find all placeholders in the pattern using regex
    $placeholders = [regex]::Matches($result, '\{([^}]+)\}')
    
    foreach ($match in $placeholders) {
        $placeholder = $match.Groups[1].Value
        $fullMatch = $match.Value
        
        # Split property name and format specifier
        $parts = $placeholder -split ':', 2
        $propertyName = $parts[0]
        $formatSpecifier = if ($parts.Count -gt 1) { $parts[1] } else { $null }
        
        # Get the value from the tag object
        $value = $TagObject.$propertyName
        
        # Handle array properties - take first item for singular properties
        if ($value -is [array] -and $value.Count -gt 0) {
            $value = $value[0]
        }
        
        # Apply case transformations
        if ($formatSpecifier) {
            switch ($formatSpecifier) {
                'Upper' { $value = $value.ToString().ToUpper() }
                'Lower' { $value = $value.ToString().ToLower() }
                'TitleCase' { $value = (Get-Culture).TextInfo.ToTitleCase($value.ToString().ToLower()) }
                'SentenceCase' { 
                    $text = $value.ToString()
                    if ($text.Length -gt 0) {
                        $value = $text.Substring(0,1).ToUpper() + $text.Substring(1).ToLower()
                    }
                }
                default {
                    # Handle numeric formatting like D2
                    if ($value -is [int] -or $value -is [uint32]) {
                        try {
                            $value = "{0:$formatSpecifier}" -f [int]$value
                        } catch {
                            # If formatting fails, use original value
                        }
                    }
                }
            }
        }
        
        # Replace null/empty values with empty string
        if ($null -eq $value -or '' -eq $value) {
            $value = ''
        }
        
        # Replace the placeholder with the value
        $result = $result -replace [regex]::Escape($fullMatch), $value
    }
    
    # Clean up any remaining invalid characters for filenames
    $result = $result -replace '[<>:"/\\|?*]', ''
    
    # Trim whitespace
    $result = $result.Trim()
    
    # Add extension if not present and pattern doesn't already have one
    if ($result -notmatch '\.[a-zA-Z0-9]{2,4}$' -and $FileExtension) {
        $result += $FileExtension
    }
    
    return $result
}

function Set-OMTags {
<#
.SYNOPSIS
    Updates audio file tags with flexible input methods and PowerShell-style pipeline support.

.DESCRIPTION
    Set-OMTags provides a modern, PowerShell-native interface for modifying audio file metadata.
    It supports three distinct workflow patterns to accommodate different use cases:
    
    1. SIMPLE MODE: Apply the same tag updates to one or more files using a hashtable
    2. PIPELINE MODE: Process Get-OMTags output with optional tag overrides
    3. TRANSFORM MODE: Use a scriptblock for complex per-file conditional logic
    
    The function leverages TagLib-Sharp for reliable tag writing across multiple audio formats
    (FLAC, MP3, M4A, OGG, etc.) and provides built-in support for -WhatIf, -Confirm, and -PassThru
    for safe, testable tag modifications.
    
    WRITABLE PROPERTIES:
    - Title, Album, Year, Track, TrackCount, Disc, DiscCount
    - Artists (array), AlbumArtists (array), Genres (array), Composers (array)
    
    READ-ONLY PROPERTIES:
    - Path, FileName, Format, Duration, Bitrate, SampleRate

.PARAMETER Path
    Path to an audio file. Can be a single file or provided via pipeline.
    Supports standard PowerShell aliases: -FilePath, -LiteralPath
    
    Used in Simple and Transform modes.

.PARAMETER Tags
    Hashtable of tag updates to apply uniformly across files.
    Keys must match writable property names (case-insensitive).
    
    SIMPLE MODE (required): Apply these tags directly
    PIPELINE MODE (optional): Override piped tags with these values
    
    Example: @{Artist="Henryk Górecki"; Year=2012; Genres=@("Classical","Requiem")}

.PARAMETER InputObject
    PSCustomObject tag object from Get-OMTags pipeline.
    Automatically extracts the Path property and uses all other properties as tag values.
    
    Used in Pipeline mode.

.PARAMETER Transform
    Scriptblock that receives the current tag object as $_ and returns the modified version.
    The scriptblock MUST return the modified object (typically end with: ; $_)
    
    The $_ variable contains a deep copy of the current tags with all writable properties.
    You can modify array properties (Genres, Artists, etc.) directly and safely.
    
    Example: { $_.Genres = @("Classical","Requiem"); $_.Year = 2012; $_ }

    .PARAMETER RenamePattern
    Template string for renaming files based on tag values after successful tag updates.
    Use placeholders like {Title}, {Artist}, {Album}, {Track}, {Year}, etc.
    Supports format specifiers like {Track:D2} for zero-padded track numbers.
    Supports case formatting: {Title:Upper}, {Title:Lower}, {Title:TitleCase}, {Title:SentenceCase}
    
    The file extension is automatically preserved. If the pattern doesn't include an extension,
    the original extension is appended.
    
    Examples:
    - "{Track:D2} - {Title}" → "01 - Song Title.mp3"
    - "{Artist:Upper} - {Album} - {Track:D2} - {Title}" → "ARTIST - Album - 01 - Song.mp3"
    - "{Year} - {Title:TitleCase}" → "2023 - Song Title.flac"
    
    Note: Renaming only occurs after successful tag updates.

.PARAMETER RenumberTracks
    Automatically renumber tracks starting from the specified number.
    Useful for fixing track numbering in albums where tracks are out of order or missing numbers.
    
    The tracks will be numbered sequentially in the order the files are processed.
    Combine with sorting if you need specific ordering (e.g., by filename).
    
    Example: -RenumberTracks 1 (starts numbering from 1)

.PARAMETER PassThru
    Return the updated tag objects after writing changes.
    
    Without -WhatIf: Returns freshly-read tags from disk (reflects actual saved state)
    With -WhatIf: Returns the proposed tag objects (shows what would be written)
    
    Useful for verification, chaining operations, or capturing results.

.PARAMETER Force
    Skip confirmation prompts and apply changes immediately.
    Overrides ConfirmPreference. Use with caution in automated scripts.

.PARAMETER WhatIf
    Preview changes without writing them to disk.
    Shows ShouldProcess messages for each file that would be modified.
    Combine with -PassThru to see proposed tag values.

.PARAMETER Confirm
    Prompt for confirmation before making changes to each file.
    Useful for interactive review of batch operations.

.EXAMPLE
    Set-OMTags -Path "song.flac" -Tags @{Year=2012; Album="Symphony No. 3"}
    
    SIMPLE MODE: Update Year and Album tags on a single file.

.EXAMPLE
    Set-OMTags -Path "song.flac" -Tags @{Genres=@("Classical","Requiem")} -WhatIf
    
    Preview tag changes without writing. Shows what would be updated.

.EXAMPLE
    Get-OMTags -Path "C:\Music\Album" | Set-OMTags -Tags @{AlbumArtist="Stefania Woytowicz"}
    
    PIPELINE MODE: Apply same AlbumArtist to all files in a directory.

.EXAMPLE
    Get-OMTags -Path "C:\Music\Album" | Set-OMTags -Tags @{Year=2023} -PassThru | 
        Format-Table FileName, Year, Album
    
    Update Year and display results in a table with -PassThru.

.EXAMPLE
    Get-OMTags -Path "C:\Music" | Where-Object { -not $_.Year } | 
        Set-OMTags -Tags @{Year=2023} -Verbose
    
    Find files missing Year tag and set to 2023 with verbose output.

.EXAMPLE
    Get-OMTags -Path "album" | Set-OMTags -Transform { 
        $_.Genres = @("Classical","Requiem")
        $_
    } -WhatIf -PassThru
    
    TRANSFORM MODE: Set genres using scriptblock. Preview with -WhatIf, return results with -PassThru.

.EXAMPLE
    Get-OMTags -Path "album" | Set-OMTags -Transform {
        if ($_.Title -match "^\d+\s+") {
            $_.Title = $_.Title -replace "^\d+\s+", ""
        }
        $_
    } -PassThru
    
    CONDITIONAL TRANSFORM: Remove leading track numbers from titles only where they exist.

.EXAMPLE
    Get-OMTags -Path "album" | Set-OMTags -Transform {
        # Fix common misspellings
        if ($_.Artists -contains "Gorecki") {
            $_.Artists = @("Henryk Górecki")
        }
        # Ensure array properties are arrays
        if ($_.Genres -isnot [array]) {
            $_.Genres = @($_.Genres)
        }
        # Add genre if not present
        if ($_.Genres -notcontains "Classical") {
            $_.Genres += "Classical"
        }
        $_
    }
    
    COMPLEX TRANSFORM: Multiple conditional modifications in one pass.

.EXAMPLE
    Get-OMTags -Path "album" | Set-OMTags -Transform {
        # Classical music: use composer as album artist
        if ($_.Genres -contains "Classical" -and $_.Composers.Count -gt 0) {
            $_.AlbumArtists = @($_.Composers[0])
        }
        $_
    } -WhatIf -PassThru | Format-List FileName, AlbumArtists, Composers
    
    Classical album artist optimization with preview and formatted output.

.EXAMPLE
    $results = Get-OMTags -Path "album" | Set-OMTags -Transform {
        # Standardize genre capitalization
        $_.Genres = $_.Genres | ForEach-Object { 
            (Get-Culture).TextInfo.ToTitleCase($_.ToLower()) 
        }
        $_
    } -PassThru
    
    Transform genres to Title Case and capture results in a variable.

.EXAMPLE
    Get-OMTags -Path "album" | Set-OMTags -Transform {
        # Ensure track numbers are sequential
        $_.Track = $script:trackNumber++
        $_
    } -Confirm
    
    Renumber tracks with confirmation prompts (note: requires $trackNumber initialized outside).

.EXAMPLE
    # Fix incomplete multi-disc tags
    $disc1 = Get-OMTags -Path "album\Disc 1"
    $disc2 = Get-OMTags -Path "album\Disc 2"
    
    $disc1 | Set-OMTags -Tags @{Disc=1; DiscCount=2}
    $disc2 | Set-OMTags -Tags @{Disc=2; DiscCount=2}
    
    Set disc numbers across multiple directories.

.EXAMPLE
    Get-OMTags -Path "album" | Set-OMTags -Tags @{Year=2023} -RenamePattern "{Track:D2} - {Title}"
    
    Update Year and rename files to "01 - Song Title.mp3" format.

.EXAMPLE
    Get-OMTags -Path "album" | Set-OMTags -Tags @{AlbumArtist="Composer"} -RenamePattern "{Artist:Upper} - {Title:TitleCase}"
    
    Update AlbumArtist and rename files with uppercase artist and title case title.

.EXAMPLE
    Get-OMTags -Path "album" | Set-OMTags -RenumberTracks 1
    
    Automatically renumber tracks starting from 1 for all files in the album.

.EXAMPLE
    Get-OMTags -Path "album" | Sort-Object FileName | Set-OMTags -RenumberTracks 5
    
    Sort files by filename first, then renumber tracks starting from 5.

.NOTES
    Requirements:
    - TagLib-Sharp assembly must be loaded (automatically loaded by Get-OMTags)
    - Supported formats: FLAC, MP3, M4A, OGG, WMA, WAV (format-dependent)
    
    Important:
    - Transform scriptblocks MUST return the modified object (end with ; $_)
    - Array properties (Genres, Artists, etc.) must be arrays: @("value") not "value"
    - Singular properties (Genre, Artist) are read-only convenience accessors
    - Always test with -WhatIf first when making bulk changes
    
    Performance:
    - Each file is read, modified, and written individually (no batching)
    - Use -Verbose to track progress on large collections
    - Consider -WhatIf for dry runs on 100+ files to verify logic
    
    For album-level Spotify integration with automatic tag enhancement, use Start-OM with -FixTags.
    
    Author: jmw
    Module: OM
    Version: 1.0
#>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium', DefaultParameterSetName = 'Pipeline')]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ParameterSetName = 'Simple')]
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ParameterSetName = 'Transform')]
        [Alias('FilePath', 'LiteralPath')]
        $Path,
        
        [Parameter(ParameterSetName = 'Simple')]
        [hashtable]$Tags,
        
        [Parameter(Mandatory = $true, ParameterSetName = 'Transform')]
        [scriptblock]$Transform,
        
        [Parameter()]
        [string]$RenamePattern,
        
        [Parameter()]
        [int]$RenumberTracks,
        
        [Parameter()]
        [switch]$PassThru,
        
        [Parameter()]
        [switch]$Force
    )
    
    begin {
        # Check for TagLib-Sharp
        $tagLibLoaded = [System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.FullName -like '*TagLib*' }
        
        if (-not $tagLibLoaded) {
            Write-Error "TagLib-Sharp is required but not loaded. Please run Get-OMTags first to load it, or install: Install-Package TagLibSharp"
            return
        }
        
        $processedCount = 0
        $errorCount = 0
        $results = @()
        $trackCounter = if ($PSBoundParameters.ContainsKey('RenumberTracks')) { $RenumberTracks } else { 0 }
        
        Write-Verbose "Starting tag update process"
    }
    
    process {
        # Detect input type
        if ($Path -is [PSCustomObject] -or $Path -is [PSObject]) {
            $isPipelineInput = $true
            $filePath = $Path.Path
            $currentTags = $Path
        } elseif ($Path -is [string]) {
            if ($Path -match '^@{Directory=(.+?); FileName=(.+?);') {
                $directory = $matches[1]
                $fileName = $matches[2]
                $filePath = Join-Path $directory $fileName
                $isPipelineInput = $true
                $currentTags = Get-OMTags -Path $filePath
            } elseif ($Path -match '^OMTagObject:(.*)$') {
                $filePath = $matches[1]
                $isPipelineInput = $true
                $currentTags = Get-OMTags -Path $filePath
            } else {
                $isPipelineInput = $false
                $filePath = $Path
                $currentTags = Get-OMTags -Path $filePath
            }
        } else {
            Write-Warning "Invalid input type: $($Path.GetType().FullName)"
            return
        }
        
        if (-not $filePath) {
            Write-Warning "No file path provided"
            return
        }
        
        # Validate file exists
        if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
            Write-Warning "File not found: $filePath"
            $errorCount++
            return
        }
        
        try {
            # Read current tags if not already provided via pipeline
            if (-not $isPipelineInput) {
                Write-Verbose "Reading current tags from: $(Split-Path $filePath -Leaf)"
                $currentTags = Get-OMTags -Path $filePath
                
                if (-not $currentTags) {
                    Write-Warning "Could not read tags from: $(Split-Path $filePath -Leaf)"
                    $errorCount++
                    return
                }
            }
            
            # Determine new tag values
            $newTags = if ($PSCmdlet.ParameterSetName -eq 'Transform') {
                # Execute transform scriptblock - create proper deep copy with all properties
                $updated = [PSCustomObject]@{
                    Path            = $currentTags.Path
                    FileName        = $currentTags.FileName
                    Title           = $currentTags.Title
                    Artists         = if ($currentTags.Artists) { @($currentTags.Artists) } else { @() }
                    AlbumArtists    = if ($currentTags.AlbumArtists) { @($currentTags.AlbumArtists) } else { @() }
                    Album           = $currentTags.Album
                    Track           = $currentTags.Track
                    TrackCount      = $currentTags.TrackCount
                    Disc            = $currentTags.Disc
                    DiscCount       = $currentTags.DiscCount
                    Year            = $currentTags.Year
                    Genres          = if ($currentTags.Genres) { @($currentTags.Genres) } else { @() }
                    Composers       = if ($currentTags.Composers) { @($currentTags.Composers) } else { @() }
                    Comment         = if ($currentTags.Comment) { $currentTags.Comment } else { $null }
                    Lyrics          = if ($currentTags.Lyrics) { $currentTags.Lyrics } else { $null }
                    Duration        = $currentTags.Duration
                    DurationSeconds = $currentTags.DurationSeconds
                    Bitrate         = $currentTags.Bitrate
                    SampleRate      = $currentTags.SampleRate
                    Format          = $currentTags.Format
                }
                # Invoke the transform with $updated as $_ in the scriptblock's scope
                # Use ForEach-Object pattern to properly set $_
                $result = $updated | ForEach-Object $Transform
                # Return the result (Transform must return the modified object)
                if ($result) { $result } else { $updated }
            } else {
                # Simple or Pipeline mode - apply hashtable updates to current tags
                $updated = [PSCustomObject]@{
                    Path            = $currentTags.Path
                    FileName        = $currentTags.FileName
                    Title           = $currentTags.Title
                    Artists         = if ($currentTags.Artists) { @($currentTags.Artists) } else { @() }
                    AlbumArtists    = if ($currentTags.AlbumArtists) { @($currentTags.AlbumArtists) } else { @() }
                    Album           = $currentTags.Album
                    Track           = $currentTags.Track
                    TrackCount      = $currentTags.TrackCount
                    Disc            = $currentTags.Disc
                    DiscCount       = $currentTags.DiscCount
                    Year            = $currentTags.Year
                    Genres          = if ($currentTags.Genres) { @($currentTags.Genres) } else { @() }
                    Composers       = if ($currentTags.Composers) { @($currentTags.Composers) } else { @() }
                    Comment         = if ($currentTags.Comment) { $currentTags.Comment } else { $null }
                    Lyrics          = if ($currentTags.Lyrics) { $currentTags.Lyrics } else { $null }
                    Duration        = $currentTags.Duration
                    DurationSeconds = $currentTags.DurationSeconds
                    Bitrate         = $currentTags.Bitrate
                    SampleRate      = $currentTags.SampleRate
                    Format          = $currentTags.Format
                }
                
                # Apply Tags hashtable if provided
                if ($Tags) {
                    foreach ($key in $Tags.Keys) {
                        if ($updated.PSObject.Properties.Name -contains $key) {
                            $updated.$key = $Tags[$key]
                        } else {
                            Write-Warning "Property '$key' does not exist on tag object"
                        }
                    }
                }
                
                $updated
            }
            
            # Apply RenumberTracks if specified
            if ($PSBoundParameters.ContainsKey('RenumberTracks')) {
                $newTags.Track = $trackCounter
                $trackCounter++
            }
            
            # Build list of changes
            $changes = @()
            $readOnlyProps = @('Path', 'FileName', 'Format', 'Duration', 'DurationSeconds', 'Bitrate', 'SampleRate', 
                              'IsClassical', 'ContributingArtists', 'Conductor', 'SuggestedAlbumArtist')
            
            foreach ($prop in $newTags.PSObject.Properties) {
                $propName = $prop.Name
                $newValue = $prop.Value
                $oldValue = $currentTags.$propName
                
                # Skip read-only properties
                if ($propName -in $readOnlyProps) {
                    continue
                }
                
                # Detect changes
                if ($newValue -ne $oldValue) {
                    # Handle array comparison
                    if ($newValue -is [array] -and $oldValue -is [array]) {
                        if (($newValue -join ',') -ne ($oldValue -join ',')) {
                            $changes += @{
                                Property = $propName
                                OldValue = $oldValue
                                NewValue = $newValue
                            }
                        }
                    } else {
                        $changes += @{
                            Property = $propName
                            OldValue = $oldValue
                            NewValue = $newValue
                        }
                    }
                }
            }
            
            if ($changes.Count -eq 0) {
                Write-Verbose "No changes needed for: $(Split-Path $filePath -Leaf)"
                $processedCount++
                
                if ($PassThru) {
                    $results += $currentTags
                }
                return
            }
            
            # Confirm changes
            $changeDescription = "Update $($changes.Count) tag(s) in '$(Split-Path $filePath -Leaf)'"
            if ($Force -or $PSCmdlet.ShouldProcess($filePath, $changeDescription)) {
                # Write tags using TagLib-Sharp
                Write-Verbose "Writing tags to: $(Split-Path $filePath -Leaf)"
                
                $fileObj = [TagLib.File]::Create($filePath)
                try {
                    $tag = $fileObj.Tag
                    
                    # Apply changes
                    foreach ($change in $changes) {
                        $propName = $change.Property
                        $newValue = $change.NewValue
                        
                        Write-Verbose "  $($propName) : '$($change.OldValue)' -> '$newValue'"
                        
                        # Map common property names to TagLib properties
                        switch ($propName) {
                            'Title' { $tag.Title = $newValue }
                            'Artists' { 
                                 if ($newValue) {
                                    $tag.Performers = $newValue
                                } else {
                                    $tag.Performers = @()
                                }
                            }
                            'AlbumArtists' { 
                                if ($newValue) {
                                    $tag.AlbumArtists = $newValue
                                } else {
                                    $tag.AlbumArtists = @()
                                }
                            }
                            'Album' { $tag.Album = $newValue }
                            'Year' { 
                                if ($newValue) {
                                    $tag.Year = [uint32]$newValue
                                } else {
                                    $tag.Year = 0000
                                }
                            }
                            'Track' { 
                                if ($newValue) {
                                    $tag.Track = [uint32]$newValue
                                } else {
                                    $tag.Track = 0
                                }
                            }
                            'TrackCount' { 
                                if ($newValue) {
                                    $tag.TrackCount = [uint32]$newValue
                                } else {
                                    $tag.TrackCount = 0
                                }
                            }
                            'Disc' { 
                                if ($newValue) {
                                    $tag.Disc = [uint32]$newValue
                                } else {
                                    $tag.Disc = 0
                                }
                            }
                            'DiscCount' { 
                                if ($newValue) {
                                    $tag.DiscCount = [uint32]$newValue
                                } else {
                                    $tag.DiscCount = 0
                                }
                            }
                            'Genres' { 
                                if ($newValue) {
                                    $tag.Genres = $newValue
                                } else {
                                    $tag.Genres = @()
                                }
                            }
                            'Composers' { 
                                if ($newValue) {
                                    $tag.Composers = $newValue
                                } else {
                                    $tag.Composers = @()
                                }
                            }
                            'Comment' { 
                                if ($newValue) {
                                    $tag.Comment = $newValue
                                } else {
                                    $tag.Comment = $null
                                }
                            }
                            'Lyrics' { 
                                if ($newValue) {
                                    $tag.Lyrics = $newValue
                                } else {
                                    $tag.Lyrics = $null
                                }
                            }
                            default {
                                Write-Verbose "  Skipping unknown or read-only property: $propName"
                            }
                        }
                    }
                    
                    # Save changes
                    if (-not $WhatIfPreference) {
                        $fileObj.Save()
                        Write-Verbose "Successfully updated: $(Split-Path $filePath -Leaf)"
                    } else {
                        Write-Host "What if: Performing the operation `"Update tags`" on target `"$(Split-Path $filePath -Leaf)`"." -ForegroundColor Yellow
                    }
                    
                    $processedCount++
                    
                    # Handle file renaming if RenamePattern is specified
                    if ($RenamePattern -and -not $WhatIfPreference) {
                        $currentDir = Split-Path $filePath -Parent
                        $currentFileName = Split-Path $filePath -Leaf
                        $fileExtension = [System.IO.Path]::GetExtension($currentFileName)
                        
                        # Use the updated tags for renaming
                        $updatedTags = Get-OMTags -Path $filePath
                        $newFileName = Expand-RenamePattern -Pattern $RenamePattern -TagObject $updatedTags -FileExtension $fileExtension
                        
                        if ($newFileName -and $newFileName -ne $currentFileName) {
                            $newFilePath = Join-Path $currentDir $newFileName
                            
                            # Check if target file already exists
                            if (Test-Path -LiteralPath $newFilePath) {
                                Write-Warning "Cannot rename '$currentFileName' to '$newFileName': target file already exists"
                            } else {
                                try {
                                    Move-Item -LiteralPath $filePath -Destination $newFilePath -ErrorAction Stop
                                    Write-Verbose "Renamed '$currentFileName' to '$newFileName'"
                                    
                                    # Update filePath for PassThru if needed
                                    $filePath = $newFilePath
                                } catch {
                                    Write-Warning "Failed to rename '$currentFileName' to '$newFileName': $($_.Exception.Message)"
                                }
                            }
                        }
                    }
                    
                    # Return updated tags if requested
                    if ($PassThru) {
                        if (-not $WhatIfPreference) {
                            $updatedTags = Get-OMTags -Path $filePath
                            $results += $updatedTags
                        } else {
                            # In WhatIf mode, return the proposed tags
                            $results += $newTags
                        }
                    }
                    
                } finally {
                    $fileObj.Dispose()
                }
            } else {
                Write-Verbose "Skipped (user declined): $(Split-Path $filePath -Leaf)"
                # Still return results in WhatIf mode if PassThru requested
                if ($PassThru -and $WhatIfPreference) {
                    $results += $newTags
                }
            }
            
        } catch {
            $errorCount++
            Write-Error "Failed to update tags for '$(Split-Path $filePath -Leaf)': $($_.Exception.Message)"
        }
    }
    
    end {
        # Summary
        if ($processedCount -gt 0 -or $errorCount -gt 0) {
            $verb = if ($WhatIfPreference) { "would be updated" } else { "updated" }
            Write-Verbose "Tag update complete: $processedCount files $verb, $errorCount errors"
            
            if (-not $WhatIfPreference -and $processedCount -gt 0) {
                Write-Host "✓ Successfully updated $processedCount file(s)" -ForegroundColor Green
            }
        }
        
        # Return results if PassThru
        if ($PassThru) {
            return $results
        }
    }
}
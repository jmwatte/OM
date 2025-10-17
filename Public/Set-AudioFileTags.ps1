function Set-AudioFileTags {
<#
.SYNOPSIS
    Updates audio file tags with flexible input methods and PowerShell-style pipeline support.

.DESCRIPTION
    Set-AudioFileTags provides a modern, PowerShell-native interface for modifying audio file metadata.
    It supports three distinct workflow patterns to accommodate different use cases:
    
    1. SIMPLE MODE: Apply the same tag updates to one or more files using a hashtable
    2. PIPELINE MODE: Process Get-AudioFileTags output with optional tag overrides
    3. TRANSFORM MODE: Use a scriptblock for complex per-file conditional logic
    
    The function leverages TagLib-Sharp for reliable tag writing across multiple audio formats
    (FLAC, MP3, M4A, OGG, etc.) and provides built-in support for -WhatIf, -Confirm, and -PassThru
    for safe, testable tag modifications.
    
    WRITABLE PROPERTIES:
    - Title, Album, Year, Track, TrackCount, Disc, DiscCount
    - Artists (array), AlbumArtists (array), Genres (array), Composers (array)
    
    READ-ONLY PROPERTIES (convenience, modify plural versions instead):
    - Artist, AlbumArtist, Genre, Composer (first item from respective arrays)
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
    PSCustomObject tag object from Get-AudioFileTags pipeline.
    Automatically extracts the Path property and uses all other properties as tag values.
    
    Used in Pipeline mode.

.PARAMETER Transform
    Scriptblock that receives the current tag object as $_ and returns the modified version.
    The scriptblock MUST return the modified object (typically end with: ; $_)
    
    The $_ variable contains a deep copy of the current tags with all writable properties.
    You can modify array properties (Genres, Artists, etc.) directly and safely.
    
    Example: { $_.Genres = @("Classical","Requiem"); $_.Year = 2012; $_ }

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
    Set-AudioFileTags -Path "song.flac" -Tags @{Year=2012; Album="Symphony No. 3"}
    
    SIMPLE MODE: Update Year and Album tags on a single file.

.EXAMPLE
    Set-AudioFileTags -Path "song.flac" -Tags @{Genres=@("Classical","Requiem")} -WhatIf
    
    Preview tag changes without writing. Shows what would be updated.

.EXAMPLE
    Get-AudioFileTags -Path "C:\Music\Album" | Set-AudioFileTags -Tags @{AlbumArtist="Stefania Woytowicz"}
    
    PIPELINE MODE: Apply same AlbumArtist to all files in a directory.

.EXAMPLE
    Get-AudioFileTags -Path "C:\Music\Album" | Set-AudioFileTags -Tags @{Year=2023} -PassThru | 
        Format-Table FileName, Year, Album
    
    Update Year and display results in a table with -PassThru.

.EXAMPLE
    Get-AudioFileTags -Path "C:\Music" | Where-Object { -not $_.Year } | 
        Set-AudioFileTags -Tags @{Year=2023} -Verbose
    
    Find files missing Year tag and set to 2023 with verbose output.

.EXAMPLE
    Get-AudioFileTags -Path "album" | Set-AudioFileTags -Transform { 
        $_.Genres = @("Classical","Requiem")
        $_
    } -WhatIf -PassThru
    
    TRANSFORM MODE: Set genres using scriptblock. Preview with -WhatIf, return results with -PassThru.

.EXAMPLE
    Get-AudioFileTags -Path "album" | Set-AudioFileTags -Transform {
        if ($_.Title -match "^\d+\s+") {
            $_.Title = $_.Title -replace "^\d+\s+", ""
        }
        $_
    } -PassThru
    
    CONDITIONAL TRANSFORM: Remove leading track numbers from titles only where they exist.

.EXAMPLE
    Get-AudioFileTags -Path "album" | Set-AudioFileTags -Transform {
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
    Get-AudioFileTags -Path "album" | Set-AudioFileTags -Transform {
        # Classical music: use composer as album artist
        if ($_.Genres -contains "Classical" -and $_.Composers.Count -gt 0) {
            $_.AlbumArtists = @($_.Composers[0])
        }
        $_
    } -WhatIf -PassThru | Format-List FileName, AlbumArtists, Composers
    
    Classical album artist optimization with preview and formatted output.

.EXAMPLE
    $results = Get-AudioFileTags -Path "album" | Set-AudioFileTags -Transform {
        # Standardize genre capitalization
        $_.Genres = $_.Genres | ForEach-Object { 
            (Get-Culture).TextInfo.ToTitleCase($_.ToLower()) 
        }
        $_
    } -PassThru
    
    Transform genres to Title Case and capture results in a variable.

.EXAMPLE
    Get-AudioFileTags -Path "album" | Set-AudioFileTags -Transform {
        # Ensure track numbers are sequential
        $_.Track = $script:trackNumber++
        $_
    } -Confirm
    
    Renumber tracks with confirmation prompts (note: requires $trackNumber initialized outside).

.EXAMPLE
    # Fix incomplete multi-disc tags
    $disc1 = Get-AudioFileTags -Path "album\Disc 1"
    $disc2 = Get-AudioFileTags -Path "album\Disc 2"
    
    $disc1 | Set-AudioFileTags -Tags @{Disc=1; DiscCount=2}
    $disc2 | Set-AudioFileTags -Tags @{Disc=2; DiscCount=2}
    
    Set disc numbers across multiple directories.

.NOTES
    Requirements:
    - TagLib-Sharp assembly must be loaded (automatically loaded by Get-AudioFileTags)
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
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium', DefaultParameterSetName = 'Simple')]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'Simple')]
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'Transform')]
        [Alias('FilePath', 'LiteralPath')]
        [string]$Path,
        
        [Parameter(Mandatory = $true, ParameterSetName = 'Simple')]
        [Parameter(ParameterSetName = 'Pipeline')]
        [hashtable]$Tags,
        
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'Pipeline')]
        [PSCustomObject]$InputObject,
        
        [Parameter(Mandatory = $true, ParameterSetName = 'Transform')]
        [scriptblock]$Transform,
        
        [Parameter()]
        [switch]$PassThru,
        
        [Parameter()]
        [switch]$Force
    )
    
    begin {
        # Check for TagLib-Sharp
        $tagLibLoaded = [System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.FullName -like '*TagLib*' }
        
        if (-not $tagLibLoaded) {
            Write-Error "TagLib-Sharp is required but not loaded. Please run Get-AudioFileTags first to load it, or install: Install-Package TagLibSharp"
            return
        }
        
        $processedCount = 0
        $errorCount = 0
        $results = @()
        
        Write-Verbose "Starting tag update process"
    }
    
    process {
        # Determine the file path based on parameter set
        $filePath = switch ($PSCmdlet.ParameterSetName) {
            'Pipeline' { $InputObject.Path }
            'Simple' { $Path }
            'Transform' { $Path }
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
            # Read current tags
            Write-Verbose "Reading current tags from: $(Split-Path $filePath -Leaf)"
            $currentTags = Get-AudioFileTags -Path $filePath
            
            if (-not $currentTags) {
                Write-Warning "Could not read tags from: $(Split-Path $filePath -Leaf)"
                $errorCount++
                return
            }
            
            # Determine new tag values based on parameter set
            $newTags = switch ($PSCmdlet.ParameterSetName) {
                'Simple' {
                    # Apply hashtable updates to current tags - create proper deep copy
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
                    foreach ($key in $Tags.Keys) {
                        if ($updated.PSObject.Properties.Name -contains $key) {
                            $updated.$key = $Tags[$key]
                        } else {
                            Write-Warning "Property '$key' does not exist on tag object"
                        }
                    }
                    $updated
                }
                'Pipeline' {
                    # Use tags from pipeline - create proper deep copy if needed
                    if ($Tags) {
                        # Make a proper deep copy to avoid modifying the pipeline object
                        $updated = [PSCustomObject]@{
                            Path            = $InputObject.Path
                            FileName        = $InputObject.FileName
                            Title           = $InputObject.Title
                            Artists         = if ($InputObject.Artists) { @($InputObject.Artists) } else { @() }
                            AlbumArtists    = if ($InputObject.AlbumArtists) { @($InputObject.AlbumArtists) } else { @() }
                            Album           = $InputObject.Album
                            Track           = $InputObject.Track
                            TrackCount      = $InputObject.TrackCount
                            Disc            = $InputObject.Disc
                            DiscCount       = $InputObject.DiscCount
                            Year            = $InputObject.Year
                            Genres          = if ($InputObject.Genres) { @($InputObject.Genres) } else { @() }
                            Composers       = if ($InputObject.Composers) { @($InputObject.Composers) } else { @() }
                            Comment         = if ($InputObject.Comment) { $InputObject.Comment } else { $null }
                            Lyrics          = if ($InputObject.Lyrics) { $InputObject.Lyrics } else { $null }
                            Duration        = $InputObject.Duration
                            DurationSeconds = $InputObject.DurationSeconds
                            Bitrate         = $InputObject.Bitrate
                            SampleRate      = $InputObject.SampleRate
                            Format          = $InputObject.Format
                        }
                        foreach ($key in $Tags.Keys) {
                            if ($updated.PSObject.Properties.Name -contains $key) {
                                $updated.$key = $Tags[$key]
                            }
                        }
                        $updated
                    } else {
                        # Return pipeline object as-is (assume user already modified it)
                        $InputObject
                    }
                }
                'Transform' {
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
                }
            }
            
            # Build list of changes
            $changes = @()
            $readOnlyProps = @('Path', 'FileName', 'Format', 'Duration', 'DurationSeconds', 'Bitrate', 'SampleRate', 
                              'IsClassical', 'ContributingArtists', 'Conductor', 'SuggestedAlbumArtist',
                              'Artist', 'AlbumArtist', 'Genre', 'Composer')  # Singular convenience properties are read-only
            
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
                            'Artist' { 
                                if ($newValue) {
                                    $tag.Performers = @($newValue)
                                }
                            }
                            'Artists' { 
                                 if ($newValue) {
                                    $tag.Performers = $newValue
                                } else {
                                    $tag.Performers = @()
                                }
                            }
                            'AlbumArtist' { 
                                if ($newValue) {
                                    $tag.AlbumArtists = @($newValue)
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
                            'Genre' { 
                                if ($newValue) {
                                    $tag.Genres = @($newValue)
                                } else {
                                    $tag.Genres = @()
                                }
                            }
                            'Genres' { 
                                if ($newValue) {
                                    $tag.Genres = $newValue
                                } else {
                                    $tag.Genres = @()
                                }
                            }
                            'Composer' { 
                                if ($newValue) {
                                    $tag.Composers = @($newValue)
                                } else {
                                    $tag.Composers = @()
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
                    
                    # Return updated tags if requested
                    if ($PassThru) {
                        if (-not $WhatIfPreference) {
                            $updatedTags = Get-AudioFileTags -Path $filePath
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
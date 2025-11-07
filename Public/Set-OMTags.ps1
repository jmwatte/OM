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

function Parse-FilenamePattern {
    <#
    .SYNOPSIS
        Parses a filename using a pattern template to extract tag values.
    
    .PARAMETER Pattern
        The template string containing placeholders like {Title}, {Artist}, etc.
    
    .PARAMETER FileName
        The filename (without extension) to parse.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Pattern,
        
        [Parameter(Mandatory)]
        [string]$FileName
    )
    
    # Build regex pattern by processing each placeholder individually
    $regexPattern = $Pattern
    
    # Find all placeholders and replace them with capture groups
    $placeholders = [regex]::Matches($regexPattern, '\{([^}]+)\}')
    
    foreach ($match in $placeholders) {
        $placeholder = $match.Groups[1].Value
        $fullMatch = $match.Value
        
        # Split property name and format specifier (ignore format for parsing)
        $propertyName = $placeholder -split ':', 2 | Select-Object -First 1
        
        # Replace with named capture group
        $captureGroup = "(?<$propertyName>.+?)"
        $regexPattern = $regexPattern -replace [regex]::Escape($fullMatch), $captureGroup
    }
    
    # Now escape only the literal text parts, but preserve the capture groups
    # Split by capture groups, escape the literals, then reassemble
    $parts = $regexPattern -split '(\(\?<[^>]+>.+?\))'
    $escapedParts = foreach ($part in $parts) {
        if ($part -match '^\(\?<[^>]+>.+?\)$') {
            # This is a capture group, don't escape it
            $part
        } else {
            # This is literal text, escape it
            [regex]::Escape($part)
        }
    }
    $regexPattern = $escapedParts -join ''
    
    # Make the pattern match the entire string
    $regexPattern = "^$regexPattern$"
    
    Write-Verbose "Generated regex pattern: $regexPattern"
    
    # Try to match
    $match = [regex]::Match($FileName, $regexPattern)
    
    if ($match.Success) {
        $result = @{}
        
        # Extract captured groups
        foreach ($groupName in $match.Groups.Keys) {
            if ($groupName -ne '0') {  # Skip the full match
                $value = $match.Groups[$groupName].Value.Trim()
                if ($value) {
                    # Try to convert numeric values
                    if ($groupName -match '^(Track|Disc|Year)$' -and $value -match '^\d+$') {
                        $result[$groupName] = [int]$value
                    } else {
                        $result[$groupName] = $value
                    }
                }
            }
        }
        
        return $result
    } else {
        Write-Verbose "Filename '$FileName' does not match pattern '$Pattern'"
        return $null
    }
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

.PARAMETER ParseFilename
    Template string for parsing filenames to extract tag values.
    Use placeholders like {Title}, {Artist}, {Album}, {Track}, {Year}, etc.
    The filename (without extension) is matched against this pattern to extract values.
    
    Supports the same placeholders as RenamePattern. Numeric values (Track, Disc, Year)
    are automatically converted to integers when possible.
    
    You can use dummy placeholders (any name not corresponding to a tag property) to skip
    parts of the filename you don't want to extract. For example:
    - "{Skip} - {Composers} - {Skip}" matches "02 - Albinoni - Adagio" and extracts only Composers
    - "{Track} - {SkipArtist} - {Title}" matches "01 - Artist - Song" and extracts only Track and Title
    
    Examples:
    - "{Track} - {Composers} - {Title}" matches "01 - Albinoni - Adagio in G Minor"
    - "{Track:D2} - {Artists} - {Title}" matches "01 - Artist Name - Song Title"
    
    Parsed values override existing tag values before other processing.
    Useful for bulk importing metadata from well-formatted filenames.

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

.PARAMETER Summary
    When used with -PassThru, returns a single summary object instead of individual tag objects.
    The summary aggregates unique values across all processed files in a compact format.
    
    Useful for getting an overview of tag changes without detailed per-file output.

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
    Get-OMTags -Path "C:\Music\Album" | Set-OMTags -Tags @{Year=2023} -PassThru -Summary
    
    Update Year and return a summary object showing aggregated tag values.

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

.EXAMPLE
    Set-OMTags -Path "02 - Albinoni - Adagio in G Minor.mp3" -ParseFilename "{Skip} - {Composers} - {Skip}"
    
    Parse filename to extract only Composers, skipping track number and title.

.EXAMPLE
    Get-OMTags -Path "classical_album" | Set-OMTags -ParseFilename "{Track:D2} - {Composers} - {Title}" -Tags @{Genres=@("Classical")}
    
    Parse filenames for classical music and add genre tags.

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
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ParameterSetName = 'Pipeline')]
        [Alias('FilePath', 'LiteralPath')]
        $Path,
        
        [Parameter(ParameterSetName = 'Simple')]
        [Parameter(ParameterSetName = 'Pipeline')]
        [hashtable]$Tags,
        
        [Parameter(Mandatory = $true, ParameterSetName = 'Transform')]
        [scriptblock]$Transform,
        
        [Parameter()]
        [string]$RenamePattern,
        
        [Parameter()]
        [string]$ParseFilename,
        
        [Parameter()]
        [int]$RenumberTracks,
        
        [Parameter()]
        [switch]$PassThru,
        
        [Parameter()]
        [switch]$Summary,
        
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
                    Artists         = if ($currentTags.Artists) { $currentTags.Artists } else { @() }
                    AlbumArtists    = if ($currentTags.AlbumArtists) { $currentTags.AlbumArtists } else { @() }
                    Album           = $currentTags.Album
                    Track           = $currentTags.Track
                    TrackCount      = $currentTags.TrackCount
                    Disc            = $currentTags.Disc
                    DiscCount       = $currentTags.DiscCount
                    Year            = $currentTags.Year
                    Genres          = if ($currentTags.Genres) { $currentTags.Genres } else { @() }
                    Composers       = if ($currentTags.Composers) { $currentTags.Composers } else { @() }
                    Comment         = if ($currentTags.Comment) { $currentTags.Comment } else { $null }
                    Lyrics          = if ($currentTags.Lyrics) { $currentTags.Lyrics } else { $null }
                    Duration        = $currentTags.Duration
                    DurationSeconds = $currentTags.DurationSeconds
                    Bitrate         = $currentTags.Bitrate
                    SampleRate      = $currentTags.SampleRate
                    Format          = $currentTags.Format
                }
                
                # Parse filename if ParseFilename pattern is specified
                if ($ParseFilename) {
                    $fileNameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($filePath)
                    Write-Verbose "Parsing filename: $fileNameWithoutExtension"
                    
                    $parsedValues = Parse-FilenamePattern -Pattern $ParseFilename -FileName $fileNameWithoutExtension
                    
                    if ($parsedValues) {
                        Write-Verbose "Parsed values from filename:"
                        foreach ($key in $parsedValues.Keys) {
                            Write-Verbose "  $key = '$($parsedValues[$key])'"
                            # Apply parsed values to updated if they exist as properties
                            if ($updated.PSObject.Properties.Name -contains $key) {
                                $updated.$key = $parsedValues[$key]
                            }
                        }
                    } else {
                        Write-Verbose "No values parsed from filename"
                    }
                }
                
                # Invoke the transform with $updated as $_ in the scriptblock's scope
                # Capture all outputs, then select the LAST PSCustomObject (the modified tag object)
                # This handles scriptblocks that emit incidental values like booleans from -match
                $allOutputs = @($updated | ForEach-Object $Transform)
                
                # Find the last PSCustomObject in the outputs (that's the modified tag object)
                $result = $null
                for ($i = $allOutputs.Count - 1; $i -ge 0; $i--) {
                    $item = $allOutputs[$i]
                    if ($item -is [PSCustomObject] -or 
                        ($item -and $item.PSObject -and ($item.PSObject.Properties.Name -contains 'Path'))) {
                        $result = $item
                        break
                    }
                }
                
                # If no PSCustomObject found, log warning and use the original
                if (-not $result) {
                    Write-Verbose "    Warning: Transform did not return a valid tag object. Using original."
                    $result = $updated
                }
                
                # Return the result
                $result
            } else {
                # Simple or Pipeline mode - apply hashtable updates to current tags
                $updated = [PSCustomObject]@{
                    Path            = $currentTags.Path
                    FileName        = $currentTags.FileName
                    Title           = $currentTags.Title
                    Artists         = if ($currentTags.Artists) { $currentTags.Artists } else { @() }
                    AlbumArtists    = if ($currentTags.AlbumArtists) { $currentTags.AlbumArtists } else { @() }
                    Album           = $currentTags.Album
                    Track           = $currentTags.Track
                    TrackCount      = $currentTags.TrackCount
                    Disc            = $currentTags.Disc
                    DiscCount       = $currentTags.DiscCount
                    Year            = $currentTags.Year
                    Genres          = if ($currentTags.Genres) { $currentTags.Genres } else { @() }
                    Composers       = if ($currentTags.Composers) { $currentTags.Composers } else { @() }
                    Comment         = if ($currentTags.Comment) { $currentTags.Comment } else { $null }
                    Lyrics          = if ($currentTags.Lyrics) { $currentTags.Lyrics } else { $null }
                    Duration        = $currentTags.Duration
                    DurationSeconds = $currentTags.DurationSeconds
                    Bitrate         = $currentTags.Bitrate
                    SampleRate      = $currentTags.SampleRate
                    Format          = $currentTags.Format
                }
                
                # Parse filename if ParseFilename pattern is specified
                if ($ParseFilename) {
                    $fileNameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($filePath)
                    Write-Verbose "Parsing filename: $fileNameWithoutExtension"
                    
                    $parsedValues = Parse-FilenamePattern -Pattern $ParseFilename -FileName $fileNameWithoutExtension
                    
                    if ($parsedValues) {
                        Write-Verbose "Parsed values from filename:"
                        foreach ($key in $parsedValues.Keys) {
                            Write-Verbose "  $key = '$($parsedValues[$key])'"
                            # Apply parsed values to updated if they exist as properties
                            if ($updated.PSObject.Properties.Name -contains $key) {
                                $updated.$key = $parsedValues[$key]
                            }
                        }
                    } else {
                        Write-Verbose "No values parsed from filename"
                    }
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
                
                # Detect changes - handle arrays specially
                $hasChange = $false
                if ($newValue -is [array] -and $oldValue -is [array]) {
                    # Array comparison - use case-sensitive join comparison to detect case changes
                    if (($newValue -join ',') -cne ($oldValue -join ',')) {
                        $hasChange = $true
                    }
                } elseif ($newValue -is [array] -or $oldValue -is [array]) {
                    # One is array, one isn't - they're different
                    $hasChange = $true
                } else {
                    # Scalar comparison - use case-sensitive for string values
                    if ($newValue -is [string] -and $oldValue -is [string]) {
                        if ($newValue -cne $oldValue) {
                            $hasChange = $true
                        }
                    } elseif ($newValue -ne $oldValue) {
                        $hasChange = $true
                    }
                }
                
                if ($hasChange) {
                    $changes += @{
                        Property = $propName
                        OldValue = $oldValue
                        NewValue = $newValue
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

                        # Diagnostic verbose: show value types to help debug persistence issues
                        try {
                            $oldType = if ($null -eq $change.OldValue) { 'null' } elseif ($change.OldValue -is [array]) { 'Array[' + (($change.OldValue | ForEach-Object { $_.GetType().Name }) -join ',') + ']' } else { $change.OldValue.GetType().FullName }
                        } catch {
                            $oldType = 'unknown'
                        }
                        try {
                            $newType = if ($null -eq $newValue) { 'null' } elseif ($newValue -is [array]) { 'Array[' + (($newValue | ForEach-Object { $_.GetType().Name }) -join ',') + ']' } else { $newValue.GetType().FullName }
                        } catch {
                            $newType = 'unknown'
                        }
                        Write-Verbose "    OldValue Type: $oldType"
                        Write-Verbose "    NewValue Type: $newType"

                        # Extra Year diagnostic: show what a uint32 cast would produce (no behavior change)
                        if ($propName -eq 'Year') {
                            try {
                                if ($newValue) { $castYear = [uint32]$newValue } else { $castYear = $null }
                                $castType = if ($null -ne $castYear) { $castYear.GetType().Name } else { 'null' }
                                Write-Verbose "    Year cast to uint32 would be: $castYear (type: $castType)"
                            } catch {
                                Write-Verbose "    Year cast to uint32 failed: $($_.Exception.Message)"
                            }
                        }
                        
                        # Map common property names to TagLib properties
                        switch ($propName) {
                            'Title' { $tag.Title = $newValue }
                            'Artists' { 
                                # Clear first to prevent duplicates
                                $tag.Performers = @()
                                if ($newValue) {
                                    $tag.Performers = $newValue
                                }
                            }
                            'AlbumArtists' { 
                                # Clear first to prevent duplicates
                                $tag.AlbumArtists = @()
                                if ($newValue) {
                                    $tag.AlbumArtists = $newValue
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
                                # Clear first to prevent duplicates
                                $tag.Genres = @()
                                if ($newValue) {
                                    $tag.Genres = $newValue
                                }
                            }
                            'Composers' { 
                                # Clear first to prevent duplicates
                                $tag.Composers = @()
                                if ($newValue) {
                                    $tag.Composers = $newValue
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
            if ($Summary) {
                # Create summary object with unique values
                $summaryObj = [PSCustomObject]@{}
                if ($results.Count -gt 0) {
                    # Define default properties and their order (matching Get-OMTags)
                    $defaultProperties = @(
                        'Path',
                        'FileName',
                        'Lyrics',
                        'Comment',
                        'Composers',
                        'Title',
                        'Track',
                        'TrackCount',
                        'Disc',
                        'DiscCount',
                        'Genres',
                        'Artists',
                        'Year',
                        'AlbumArtists',
                        'Album'
                    )
                    
                    # Properties that should maintain file order (not be sorted)
                    $orderedProperties = @('FileName', 'Title')
                    
                    foreach ($prop in $defaultProperties) {
                        if ($prop -in $orderedProperties) {
                            # For ordered properties, collect in file processing order
                            $orderedValues = @()
                            $hasEmpty = $false
                            foreach ($result in $results) {
                                $value = $result.$prop
                                if ($null -ne $value -and $value -ne '') {
                                    $orderedValues += $value
                                } else {
                                    $hasEmpty = $true
                                }
                            }
                            $summaryValue = $orderedValues -join ', '
                            if ($hasEmpty) { 
                                $summaryValue = if ($summaryValue) { $summaryValue + ', *Empty*' } else { '*Empty*' }
                            }
                            $summaryObj | Add-Member -MemberType NoteProperty -Name $prop -Value $summaryValue
                        } else {
                            # For other properties, collect all values and get unique sorted
                            # Special-case 'Path' to show unique album folders
                            if ($prop -eq 'Path') {
                                $parents = @()
                                foreach ($result in $results) {
                                    if ($result.Path) { $parents += (Split-Path $result.Path -Parent) }
                                }
                                $uniqueParents = $parents | Where-Object { $_ -and $_ -ne '' } | Select-Object -Unique
                                $summaryObj | Add-Member -MemberType NoteProperty -Name $prop -Value ($uniqueParents -join ', ')
                            } else {
                                $allValues = @()
                                $hasEmpty = $false
                                foreach ($result in $results) {
                                    $value = $result.$prop
                                    if ($value -is [array]) {
                                        if ($value.Count -eq 0) {
                                            $hasEmpty = $true
                                        } else {
                                            $allValues += $value
                                        }
                                    } else {
                                        if ($null -ne $value -and $value -ne '') {
                                            $allValues += $value
                                        } else {
                                            $hasEmpty = $true
                                        }
                                    }
                                }
                                $uniqueValues = $allValues | Where-Object { $_ -ne $null -and $_ -ne '' } | Sort-Object -Unique
                                if ($prop -eq 'Track') {
                                    # Pad track numbers based on TrackCount
                                    $maxTrackCount = ($results | Where-Object { $_.TrackCount } | Select-Object -ExpandProperty TrackCount | Measure-Object -Maximum).Maximum
                                    $padLength = if ($maxTrackCount) { $maxTrackCount.ToString().Length } else { 2 }
                                    $paddedValues = $uniqueValues | ForEach-Object { if ($_ -is [int]) { $_.ToString("D$padLength") } else { $_ } }
                                    $summaryValue = $paddedValues -join ', '
                                } else {
                                    $summaryValue = $uniqueValues -join ', '
                                }
                                if ($hasEmpty) { 
                                    $summaryValue = if ($summaryValue) { $summaryValue + ', *Empty*' } else { '*Empty*' }
                                }
                                $summaryObj | Add-Member -MemberType NoteProperty -Name $prop -Value $summaryValue
                            }
                        }
                    }
                }
                return $summaryObj
            } else {
                return $results
            }
        }
    }
}
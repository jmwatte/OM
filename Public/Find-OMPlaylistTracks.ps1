function Find-OMPlaylistTracks {
<#
.SYNOPSIS
    Finds audio files matching artist/title pairs from a text file.

.DESCRIPTION
    Reads a text file with one "Artist - Title" per line, searches a pre-loaded
    library index for matches using fuzzy matching, and outputs paths for 
    playlist generation.
    
    Supports multiple output formats (M3U, PLS, paths) and handles fuzzy matching
    for typos, different punctuation, and minor variations.

.PARAMETER InputFile
    Path to text file with one track per line (Artist - Title format).

.PARAMETER Library
    Pre-loaded library index from Import-OMLibraryIndex.
    If not provided, will prompt for LibraryFile.

.PARAMETER LibraryFile
    Path to foobar2000 export file. Alternative to pre-loading with Import-OMLibraryIndex.

.PARAMETER Delimiter
    Delimiter between artist and title in input file. Default: " - "

.PARAMETER Format
    Line format in input file: 'ArtistTitle' (default) or 'TitleArtist'

.PARAMETER Threshold
    Minimum combined similarity score (0.0-1.0). Default: 0.6

.PARAMETER OutputFormat
    Output format: 'M3U', 'PLS', 'Paths', or 'Objects'. Default: 'M3U'

.PARAMETER PickStrategy
    How to handle multiple matches: 'Best', 'All', 'Interactive'. Default: 'Best'

.PARAMETER DuplicateHandling
    When exact matches find multiple versions (same song, different albums):
    - 'First': Include only the first match (default, smaller playlist)
    - 'All': Include all versions found
    - 'Shortest': Pick the shortest duration (likely single/radio edit)
    - 'Longest': Pick the longest duration (likely album version)

.PARAMETER Genre
    Optional genre to include in M3U extended info comments.

.PARAMETER OutputFile
    Optional path to write playlist directly. If not specified, outputs to pipeline.

.PARAMETER NotFoundLog
    Path to write a log of songs that weren't found in the library.
    Useful for knowing what to add to your collection.

.EXAMPLE
    $lib = Import-OMLibraryIndex -Path "C:\library.txt"
    Find-OMPlaylistTracks -InputFile "wishlist.txt" -Library $lib -OutputFile "playlist.m3u8"

.EXAMPLE
    # Blues playlist with genre tag
    Find-OMPlaylistTracks -InputFile "blues-songs.txt" -LibraryFile "C:\library.txt" -Genre "Blues" -OutputFile "blues.m3u8"

.EXAMPLE
    # Interactive mode for duplicates
    Find-OMPlaylistTracks -InputFile "songs.txt" -Library $lib -PickStrategy Interactive

.EXAMPLE
    # Get objects for further processing
    $matches = Find-OMPlaylistTracks -InputFile "songs.txt" -Library $lib -OutputFormat Objects
    $matches | Where-Object { $_.Score -lt 0.8 } | ForEach-Object { "Low confidence: $($_.SearchText)" }

.EXAMPLE
    # Include all versions of matched songs and log missing ones
    Find-OMPlaylistTracks -InputFile "songs.txt" -Library $lib -DuplicateHandling All -NotFoundLog "C:\missing-songs.txt" -OutputFile "playlist.m3u8"
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$InputFile,
        
        [Parameter(Mandatory, ParameterSetName = 'PreLoaded')]
        [object[]]$Library,
        
        [Parameter(Mandatory, ParameterSetName = 'FromFile')]
        [string]$LibraryFile,
        
        [string]$Delimiter = " - ",
        
        [ValidateSet('ArtistTitle', 'TitleArtist')]
        [string]$Format = 'ArtistTitle',
        
        [ValidateRange(0.0, 1.0)]
        [double]$Threshold = 0.6,
        
        [ValidateSet('M3U', 'PLS', 'Paths', 'Objects')]
        [string]$OutputFormat = 'M3U',
        
        [ValidateSet('Best', 'All', 'Interactive')]
        [string]$PickStrategy = 'Best',
        
        [ValidateSet('First', 'All', 'Shortest', 'Longest')]
        [string]$DuplicateHandling = 'First',
        
        [string]$Genre,
        
        [string]$OutputFile,
        
        [string]$NotFoundLog
    )
    
    begin {
        # Load library if needed
        if ($PSCmdlet.ParameterSetName -eq 'FromFile') {
            $Library = Import-OMLibraryIndex -Path $LibraryFile
        }
        
        if (-not $Library -or $Library.Count -eq 0) {
            throw "Library is empty or not loaded"
        }
        
        Write-Host "Library loaded: $($Library.Count) tracks" -ForegroundColor Cyan
        
        # Build normalized index for fast exact matching
        Write-Host "Building search index..." -ForegroundColor Cyan
        $normalizedIndex = @{}
        
        # Also build trigram index for fast fuzzy candidate filtering
        # This dramatically reduces the search space for fuzzy matching
        $trigramIndex = @{}
        
        # Helper to extract trigrams from a string
        $getTrigrams = {
            param([string]$s)
            $s = $s.ToLower() -replace '[^\p{L}\p{N}]', ''
            if ($s.Length -lt 3) { return @($s) }
            $trigrams = @()
            for ($i = 0; $i -le $s.Length - 3; $i++) {
                $trigrams += $s.Substring($i, 3)
            }
            return $trigrams
        }
        
        $trackIdx = 0
        foreach ($track in $Library) {
            $artistKey = ($track.Artist).ToLower() -replace '[^\p{L}\p{N}]', ''
            $titleKey = ($track.Title).ToLower() -replace '[^\p{L}\p{N}]', ''
            $key = "$artistKey|$titleKey"
            
            if (-not $normalizedIndex.ContainsKey($key)) {
                $normalizedIndex[$key] = [System.Collections.Generic.List[object]]::new()
            }
            $normalizedIndex[$key].Add($track)
            
            # Add to trigram index (for both artist and title)
            $combinedText = "$artistKey $titleKey"
            $trigrams = & $getTrigrams $combinedText
            foreach ($tri in $trigrams) {
                if (-not $trigramIndex.ContainsKey($tri)) {
                    $trigramIndex[$tri] = [System.Collections.Generic.HashSet[int]]::new()
                }
                $trigramIndex[$tri].Add($trackIdx) | Out-Null
            }
            $trackIdx++
        }
        Write-Host "Index built: $($normalizedIndex.Count) unique combinations, $($trigramIndex.Count) trigrams" -ForegroundColor Green
        
        $results = [System.Collections.Generic.List[PSCustomObject]]::new()
        $notFound = [System.Collections.Generic.List[PSCustomObject]]::new()
    }
    
    process {
        if (-not (Test-Path -LiteralPath $InputFile)) {
            throw "Input file not found: $InputFile"
        }
        
        $lines = @(Get-Content -Path $InputFile | Where-Object { $_.Trim() -ne '' -and -not $_.StartsWith('#') })
        Write-Host "Processing $($lines.Count) search lines..." -ForegroundColor Cyan
        
        $lineNum = 0
        foreach ($line in $lines) {
            $lineNum++
            
            if ($lines.Count -gt 20 -and $lineNum % 10 -eq 0) {
                Write-Progress -Activity "Matching tracks" -Status "$lineNum / $($lines.Count)" -PercentComplete (($lineNum / $lines.Count) * 100)
            }
            
            # Parse line
            $parts = $line -split [regex]::Escape($Delimiter), 2
            if ($parts.Count -ne 2) {
                Write-Warning "Line $lineNum`: Cannot parse '$line' - no delimiter '$Delimiter' found"
                $notFound.Add([PSCustomObject]@{ Line = $lineNum; Text = $line; Reason = 'Parse error' })
                continue
            }
            
            if ($Format -eq 'ArtistTitle') {
                $searchArtist = $parts[0].Trim()
                $searchTitle = $parts[1].Trim()
            } else {
                $searchTitle = $parts[0].Trim()
                $searchArtist = $parts[1].Trim()
            }
            
            # Try exact normalized match first (fast path)
            $artistNorm = $searchArtist.ToLower() -replace '[^\p{L}\p{N}]', ''
            $titleNorm = $searchTitle.ToLower() -replace '[^\p{L}\p{N}]', ''
            $exactKey = "$artistNorm|$titleNorm"
            
            if ($normalizedIndex.ContainsKey($exactKey)) {
                $exactMatches = @($normalizedIndex[$exactKey])
                
                # Apply DuplicateHandling for multiple exact matches
                $selectedExactMatches = switch ($DuplicateHandling) {
                    'First' { @($exactMatches[0]) }
                    'All' { $exactMatches }
                    'Shortest' {
                        # Pick shortest duration (likely single/radio edit)
                        @($exactMatches | Sort-Object -Property Duration | Select-Object -First 1)
                    }
                    'Longest' {
                        # Pick longest duration (likely album version)
                        @($exactMatches | Sort-Object -Property Duration -Descending | Select-Object -First 1)
                    }
                }
                
                foreach ($match in $selectedExactMatches) {
                    $results.Add([PSCustomObject]@{
                        SearchArtist = $searchArtist
                        SearchTitle  = $searchTitle
                        SearchText   = $line
                        Matches      = @($exactMatches)  # Keep all for reference
                        BestMatch    = $match
                        Score        = 1.0
                        MatchType    = 'Exact'
                        VersionCount = $exactMatches.Count
                    })
                }
                continue
            }
            
            # Fuzzy match - use trigram index to pre-filter candidates
            $bestMatches = [System.Collections.Generic.List[PSCustomObject]]::new()
            
            # Get trigrams from search query to find candidate tracks
            $searchText = "$artistNorm $titleNorm"
            $searchTrigrams = & $getTrigrams $searchText
            
            # Find candidate track indices using trigram overlap
            $candidateScores = @{}
            foreach ($tri in $searchTrigrams) {
                if ($trigramIndex.ContainsKey($tri)) {
                    foreach ($idx in $trigramIndex[$tri]) {
                        if (-not $candidateScores.ContainsKey($idx)) {
                            $candidateScores[$idx] = 0
                        }
                        $candidateScores[$idx]++
                    }
                }
            }
            
            # Only consider candidates with at least 20% trigram overlap
            $minTrigramMatches = [Math]::Max(1, [Math]::Floor($searchTrigrams.Count * 0.2))
            $candidateIndices = @($candidateScores.GetEnumerator() | 
                Where-Object { $_.Value -ge $minTrigramMatches } | 
                Sort-Object -Property Value -Descending | 
                Select-Object -First 500 |  # Limit to top 500 candidates
                ForEach-Object { $_.Key })
            
            Write-Verbose "Fuzzy search '$searchArtist - $searchTitle': $($candidateIndices.Count) candidates from $($Library.Count) tracks"
            
            foreach ($idx in $candidateIndices) {
                $track = $Library[$idx]
                # Calculate similarity scores using both algorithms
                $artistJaccard = Get-StringSimilarity-Jaccard -String1 $searchArtist -String2 $track.Artist
                $artistLeven = Get-StringSimilarity -String1 $searchArtist -String2 $track.Artist
                $artistScore = [Math]::Max($artistJaccard, $artistLeven)
                
                $titleJaccard = Get-StringSimilarity-Jaccard -String1 $searchTitle -String2 $track.Title
                $titleLeven = Get-StringSimilarity -String1 $searchTitle -String2 $track.Title
                $titleScore = [Math]::Max($titleJaccard, $titleLeven)
                
                # Combined score: weight title higher (60/40) since title is more unique
                $combinedScore = ($artistScore * 0.4) + ($titleScore * 0.6)
                
                if ($combinedScore -ge $Threshold) {
                    $bestMatches.Add([PSCustomObject]@{
                        Track       = $track
                        Score       = $combinedScore
                        ArtistScore = $artistScore
                        TitleScore  = $titleScore
                    })
                }
            }
            
            if ($bestMatches.Count -eq 0) {
                Write-Verbose "No match for: $searchArtist - $searchTitle"
                $notFound.Add([PSCustomObject]@{ Line = $lineNum; Text = $line; Reason = "No match >= $Threshold" })
                continue
            }
            
            # Sort by score descending
            $sortedMatches = $bestMatches | Sort-Object -Property Score -Descending
            
            # Apply pick strategy
            $selectedMatch = switch ($PickStrategy) {
                'Best' { 
                    $sortedMatches[0] 
                }
                'All' { 
                    $sortedMatches 
                }
                'Interactive' {
                    if ($sortedMatches.Count -eq 1) {
                        $sortedMatches[0]
                    } else {
                        Write-Host "`nMultiple matches for: " -NoNewline
                        Write-Host "$searchArtist - $searchTitle" -ForegroundColor Yellow
                        $showCount = [Math]::Min($sortedMatches.Count, 5)
                        for ($i = 0; $i -lt $showCount; $i++) {
                            $m = $sortedMatches[$i]
                            $scoreDisplay = [Math]::Round($m.Score * 100)
                            Write-Host "  [$($i+1)] " -NoNewline -ForegroundColor Cyan
                            Write-Host "$($m.Track.Artist) - $($m.Track.Title)" -NoNewline
                            Write-Host " ($scoreDisplay%)" -ForegroundColor DarkGray
                            if ($m.Track.Album) {
                                Write-Host "       Album: $($m.Track.Album)" -ForegroundColor DarkGray
                            }
                        }
                        Write-Host "  [0] Skip" -ForegroundColor DarkGray
                        Write-Host "  [Enter] Accept best match" -ForegroundColor DarkGray
                        
                        $choice = Read-Host "Select"
                        if ($choice -eq '0') { 
                            $null 
                        } elseif ($choice -eq '' -or $choice -eq '1') {
                            $sortedMatches[0]
                        } elseif ($choice -match '^\d+$' -and [int]$choice -le $showCount) {
                            $sortedMatches[[int]$choice - 1]
                        } else {
                            Write-Warning "Invalid choice, using best match"
                            $sortedMatches[0]
                        }
                    }
                }
            }
            
            if ($null -ne $selectedMatch) {
                if ($PickStrategy -eq 'All') {
                    foreach ($m in $selectedMatch) {
                        $results.Add([PSCustomObject]@{
                            SearchArtist = $searchArtist
                            SearchTitle  = $searchTitle
                            SearchText   = $line
                            Matches      = @($m.Track)
                            BestMatch    = $m.Track
                            Score        = $m.Score
                            MatchType    = 'Fuzzy'
                            VersionCount = 1
                        })
                    }
                } else {
                    $results.Add([PSCustomObject]@{
                        SearchArtist = $searchArtist
                        SearchTitle  = $searchTitle
                        SearchText   = $line
                        Matches      = @($selectedMatch.Track)
                        BestMatch    = $selectedMatch.Track
                        Score        = $selectedMatch.Score
                        MatchType    = 'Fuzzy'
                        VersionCount = 1
                    })
                }
            } else {
                $notFound.Add([PSCustomObject]@{ Line = $lineNum; Text = $line; Reason = 'Skipped by user' })
            }
        }
        
        if ($lines.Count -gt 20) {
            Write-Progress -Activity "Matching tracks" -Completed
        }
    }
    
    end {
        # Report summary
        Write-Host "`n" -NoNewline
        Write-Host "═══ Results ═══" -ForegroundColor Green
        $foundColor = if ($results.Count -gt 0) { 'Green' } else { 'Red' }
        Write-Host "Found: $($results.Count) tracks from $($lines.Count) searches" -ForegroundColor $foundColor
        
        # Show match quality breakdown
        $exactCount = ($results | Where-Object { $_.MatchType -eq 'Exact' }).Count
        $fuzzyCount = ($results | Where-Object { $_.MatchType -eq 'Fuzzy' }).Count
        if ($exactCount -gt 0 -or $fuzzyCount -gt 0) {
            Write-Host "  Exact: $exactCount, Fuzzy: $fuzzyCount" -ForegroundColor DarkGray
        }
        
        # Show multi-version info
        $multiVersion = @($results | Where-Object { $_.VersionCount -gt 1 })
        if ($multiVersion.Count -gt 0) {
            $totalDupes = ($multiVersion | Measure-Object -Property VersionCount -Sum).Sum
            Write-Host "  Multi-version songs: $($multiVersion.Count) (DuplicateHandling: $DuplicateHandling)" -ForegroundColor DarkCyan
        }
        
        # Show low-confidence fuzzy matches
        $lowConfidence = @($results | Where-Object { $_.MatchType -eq 'Fuzzy' -and $_.Score -lt 0.8 })
        if ($lowConfidence.Count -gt 0) {
            Write-Host "`nLow confidence matches ($($lowConfidence.Count)):" -ForegroundColor Yellow
            $lowConfidence | Select-Object -First 10 | ForEach-Object {
                $pct = [Math]::Round($_.Score * 100)
                Write-Host "  $($_.SearchArtist) - $($_.SearchTitle)" -ForegroundColor DarkGray
                Write-Host "    → $($_.BestMatch.Artist) - $($_.BestMatch.Title) ($pct%)" -ForegroundColor DarkYellow
            }
            if ($lowConfidence.Count -gt 10) {
                Write-Host "  ... and $($lowConfidence.Count - 10) more" -ForegroundColor DarkGray
            }
        }
        
        # Show not found
        if ($notFound.Count -gt 0) {
            Write-Host "`nNot found ($($notFound.Count)):" -ForegroundColor Red
            $notFound | Select-Object -First 10 | ForEach-Object { 
                Write-Host "  Line $($_.Line): $($_.Text)" -ForegroundColor DarkGray
                Write-Host "    Reason: $($_.Reason)" -ForegroundColor DarkRed
            }
            if ($notFound.Count -gt 10) {
                Write-Host "  ... and $($notFound.Count - 10) more" -ForegroundColor DarkGray
            }
        }
        
        # Write NotFoundLog if specified
        if ($NotFoundLog -and $notFound.Count -gt 0) {
            $logContent = @(
                "# Songs Not Found - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
                "# Source: $InputFile"
                "# Library: $($Library.Count) tracks"
                "# Threshold: $Threshold"
                ""
                "# Format: Artist - Title (Reason)"
                ""
            )
            foreach ($nf in $notFound) {
                $logContent += "$($nf.Text)  # $($nf.Reason)"
            }
            $logContent -join "`n" | Out-File -FilePath $NotFoundLog -Encoding utf8
            Write-Host "`nNot-found log written to: $NotFoundLog" -ForegroundColor Yellow
        }
        
        # Build output
        $output = switch ($OutputFormat) {
            'Objects' {
                $results.ToArray()
            }
            'Paths' {
                $results | ForEach-Object { $_.BestMatch.Path }
            }
            'M3U' {
                $lines = [System.Collections.Generic.List[string]]::new()
                $lines.Add('#EXTM3U')
                if ($Genre) {
                    $lines.Add("#EXTGENRE:$Genre")
                }
                foreach ($r in $results) {
                    $track = $r.BestMatch
                    $duration = $track.Duration
                    $displayArtist = $track.Artist
                    $displayTitle = $track.Title
                    $lines.Add("#EXTINF:$duration,$displayArtist - $displayTitle")
                    $lines.Add($track.Path)
                }
                $lines -join "`n"
            }
            'PLS' {
                $lines = [System.Collections.Generic.List[string]]::new()
                $lines.Add('[playlist]')
                $i = 0
                foreach ($r in $results) {
                    $i++
                    $track = $r.BestMatch
                    $lines.Add("File$i=$($track.Path)")
                    $lines.Add("Title$i=$($track.Artist) - $($track.Title)")
                    $lines.Add("Length$i=$($track.Duration)")
                }
                $lines.Add("NumberOfEntries=$i")
                $lines.Add("Version=2")
                $lines -join "`n"
            }
        }
        
        # Output to file or pipeline
        if ($OutputFile -and $OutputFormat -ne 'Objects') {
            $output | Out-File -FilePath $OutputFile -Encoding utf8
            Write-Host "`nPlaylist written to: $OutputFile" -ForegroundColor Green
        } else {
            return $output
        }
    }
}

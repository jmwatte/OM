function Set-Tracks {
    param (
        [string]$SortMethod,
        [array]$AudioFiles,
        [array]$SpotifyTracks,
        [switch]$Reverse  # If set, iterate over audio files and match to Spotify tracks
    )

    #Write-Host "DEBUG Set-Tracks: Entered with SortMethod=$SortMethod, Reverse=$Reverse, AudioFiles count=$($AudioFiles.Count), SpotifyTracks count=$($SpotifyTracks.Count)"

    $pairedTracks = @()
    #Write-Host "DEBUG: Starting Set-Tracks with Reverse=$Reverse"
    switch ($SortMethod) {
        # byFilesystem: Preserve original filesystem order (as files appear on disk)
        # This is useful when files are already in correct order but lack proper tags/numbering
        "byFilesystem" {
            # Sort audio files by leading track number in filename (natural sort)
            # Handles "1. Aria", "2. Variation 1", "10. Variation 9", etc.
            $sortedAudio = $AudioFiles | Sort-Object {
                $filename = [System.IO.Path]::GetFileName($_.FilePath)
                # Extract leading number from filename (e.g., "1. Aria" -> 1, "10. Variation" -> 10)
                if ($filename -match '^(\d+)') {
                    [int]$matches[1]
                } else {
                    # No leading number, use a high value to sort at end
                    999999
                }
            }
            $sortedSpotify = $SpotifyTracks | Sort-Object disc_number, track_number
            
            if ($Reverse) {
                foreach ($audio in $sortedAudio) {
                    $index = [Array]::IndexOf($sortedAudio, $audio)
                    $spotifyTrack = if ($index -lt $sortedSpotify.Count) { $sortedSpotify[$index] } else { $null }
                    
                    # Calculate confidence if both tracks exist
                    $confidence = if ($spotifyTrack -and $audio) {
                        Get-MatchConfidence -ProviderTrack $spotifyTrack -AudioFile $audio
                    } else { $null }
                    
                    $pairedTracks += [PSCustomObject]@{
                        SpotifyTrack = $spotifyTrack
                        AudioFile    = $audio
                        Confidence   = if ($confidence) { $confidence.Score } else { 0 }
                        ConfidenceLevel = if ($confidence) { $confidence.Level } else { "Low" }
                    }
                }
            }
            else {
                foreach ($spotify in $sortedSpotify) {
                    $index = [Array]::IndexOf($sortedSpotify, $spotify)
                    $audioFile = if ($index -lt $sortedAudio.Count) { $sortedAudio[$index] } else { $null }
                    
                    # Calculate confidence if both tracks exist
                    $confidence = if ($spotify -and $audioFile) {
                        Get-MatchConfidence -ProviderTrack $spotify -AudioFile $audioFile
                    } else { $null }
                    
                    $pairedTracks += [PSCustomObject]@{
                        SpotifyTrack = $spotify
                        AudioFile    = $audioFile
                        Confidence   = if ($confidence) { $confidence.Score } else { 0 }
                        ConfidenceLevel = if ($confidence) { $confidence.Level } else { "Low" }
                    }
                }
            }
        }
        # byOrder: each one in the order by which they came in
        # Also applies natural sorting by leading track number
        "byOrder" {
            # Sort audio files by leading track number in filename (natural sort)
            $sortedAudio = $AudioFiles | Sort-Object {
                $filename = [System.IO.Path]::GetFileName($_.FilePath)
                if ($filename -match '^(\d+)') {
                    [int]$matches[1]
                } else {
                    999999
                }
            }
            $sortedSpotify = $SpotifyTracks | Sort-Object disc_number, track_number
            
            if ($Reverse) {
                # Iterate over audio files, match to Spotify by order
                foreach ($audio in $sortedAudio) {
                    $index = [Array]::IndexOf($sortedAudio, $audio)
                    $spotifyTrack = if ($index -lt $sortedSpotify.Count) { $sortedSpotify[$index] } else { $null }
                    
                    # Calculate confidence if both tracks exist
                    $confidence = if ($spotifyTrack -and $audio) {
                        Get-MatchConfidence -ProviderTrack $spotifyTrack -AudioFile $audio
                    } else { $null }
                    
                    $pairedTracks += [PSCustomObject]@{
                        SpotifyTrack = $spotifyTrack
                        AudioFile    = $audio
                        Confidence   = if ($confidence) { $confidence.Score } else { 0 }
                        ConfidenceLevel = if ($confidence) { $confidence.Level } else { "Low" }
                    }
                }
            }
            else {
                # Original: Iterate over Spotify tracks
                foreach ($spotify in $sortedSpotify) {
                    $index = [Array]::IndexOf($sortedSpotify, $spotify)
                    $audioFile = if ($index -lt $sortedAudio.Count) { $sortedAudio[$index] } else { $null }
                    
                    # Calculate confidence if both tracks exist
                    $confidence = if ($spotify -and $audioFile) {
                        Get-MatchConfidence -ProviderTrack $spotify -AudioFile $audioFile
                    } else { $null }
                    
                    $pairedTracks += [PSCustomObject]@{
                        SpotifyTrack = $spotify
                        AudioFile    = $audioFile
                        Confidence   = if ($confidence) { $confidence.Score } else { 0 }
                        ConfidenceLevel = if ($confidence) { $confidence.Level } else { "Low" }
                    }
                }
            }
        }
        "byName" {
            # Build all possible matches with scores (filename similarity + duration)
            # This approach works for both normal and reverse modes
            $matchesR = @()
            
            foreach ($spotify in $SpotifyTracks) {
                foreach ($audio in $AudioFiles) {
                    $filename = [System.IO.Path]::GetFileNameWithoutExtension($audio.FilePath)
                    
                    # Primary: Filename similarity
                    $nameSimilarity = Get-StringSimilarity-Jaccard -String1 $spotify.name -String2 $filename
                    
                    # Only consider if similarity is reasonable (>= 0.5)
                    if ($nameSimilarity -ge 0.5) {
                        # Secondary: Duration closeness as tiebreaker
                        $diff = [Math]::Abs($spotify.duration_ms - $audio.Duration)
                        $tolerance = [Math]::Max($spotify.duration_ms, 1) * 0.1
                        $durationScore = if ($diff -le $tolerance) { 1 - ($diff / $tolerance) } else { 0 }
                        
                        # Combined score: name (80%) + duration (20%)
                        $score = ($nameSimilarity * 80) + ($durationScore * 20)
                        
                        $matchesR += [PSCustomObject]@{
                            Spotify = $spotify
                            Audio   = $audio
                            Score   = $score
                        }
                    }
                }
            }
            
            # Greedy assignment with deduplication
            $matchesR = $matchesR | Sort-Object Score -Descending
            $usedSpotify = @{}
            $usedAudio = @{}
            
            foreach ($match in $matchesR) {
                $spotifyId = if ($match.Spotify.id) { $match.Spotify.id } else { $match.Spotify.name }
                $audioPath = $match.Audio.FilePath
                
                # Only use if score is good enough and not already used
                if ($match.Score -ge 40 -and
                    -not $usedSpotify.ContainsKey($spotifyId) -and 
                    -not $usedAudio.ContainsKey($audioPath)) {
                    
                    # Calculate confidence for the match
                    $confidence = Get-MatchConfidence -ProviderTrack $match.Spotify -AudioFile $match.Audio
                    
                    $pairedTracks += [PSCustomObject]@{
                        SpotifyTrack = $match.Spotify
                        AudioFile    = $match.Audio
                        Confidence   = $confidence.Score
                        ConfidenceLevel = $confidence.Level
                    }
                    $usedSpotify[$spotifyId] = $true
                    $usedAudio[$audioPath] = $true
                }
            }
            
            # Add unpaired Spotify tracks
            if ($SpotifyTracks -and $SpotifyTracks.Count -gt 0) {
                $unpairedSpotify = $SpotifyTracks | Where-Object { 
                    $sid = if ($_.id) { $_.id } else { $_.name }
                    -not $usedSpotify.ContainsKey($sid)
                }
                foreach ($spotify in $unpairedSpotify) {
                    $pairedTracks += [PSCustomObject]@{
                        SpotifyTrack = $spotify
                        AudioFile    = $null
                    }
                }
            }
            
            # Add unpaired audio files
            $unpairedAudio = $AudioFiles | Where-Object { 
                -not $usedAudio.ContainsKey($_.FilePath)
            }
            foreach ($audio in $unpairedAudio) {
                $pairedTracks += [PSCustomObject]@{
                    SpotifyTrack = $null
                    AudioFile    = $audio
                }
            }
        }
        "byTitle" {
            # Build all possible matches with scores (title similarity + duration)
            $matchesR = @()
            
            foreach ($spotify in $SpotifyTracks) {
                foreach ($audio in $AudioFiles) {
                    # Primary: Title similarity
                    $titleSimilarity = Get-StringSimilarity-Jaccard -String1 $spotify.name -String2 $audio.Title
                    
                    # Boost score if key identifiers match (e.g., BWV numbers, movement names)
                    $identifierBoost = 0
                    $spotifyBWV = if ($spotify.name -match 'BWV\s*(\d+)') { $matches[1] } else { $null }
                    $audioBWV = if ($audio.Title -match 'BWV\s*(\d+)') { $matches[1] } else { $null }
                    
                    if ($spotifyBWV -and $audioBWV -and $spotifyBWV -eq $audioBWV) {
                        $identifierBoost = 0.3  # Same BWV number
                    }
                    
                    $titleSimilarity = [Math]::Min(1.0, $titleSimilarity + $identifierBoost)
                    
                    # Only consider if similarity is reasonable (>= 0.4, lowered from 0.5 for complex titles)
                    if ($titleSimilarity -ge 0.4) {
                        # Secondary: Duration closeness as tiebreaker
                        $diff = [Math]::Abs($spotify.duration_ms - $audio.Duration)
                        $tolerance = [Math]::Max($spotify.duration_ms, 1) * 0.1
                        $durationScore = if ($diff -le $tolerance) { 1 - ($diff / $tolerance) } else { 0 }
                        
                        # Combined score: title (80%) + duration (20%)
                        $score = ($titleSimilarity * 80) + ($durationScore * 20)
                        
                        $matchesR += [PSCustomObject]@{
                            Spotify = $spotify
                            Audio   = $audio
                            Score   = $score
                        }
                    }
                }
            }
            
            # Greedy assignment with deduplication
            $matchesR = $matchesR | Sort-Object Score -Descending
            $usedSpotify = @{}
            $usedAudio = @{}
            
            foreach ($match in $matchesR) {
                $spotifyId = if ($match.Spotify.id) { $match.Spotify.id } else { $match.Spotify.name }
                $audioPath = $match.Audio.FilePath
                
                # Only use if score is good enough and not already used
                if ($match.Score -ge 40 -and
                    -not $usedSpotify.ContainsKey($spotifyId) -and 
                    -not $usedAudio.ContainsKey($audioPath)) {
                    
                    # Calculate confidence using the new helper function
                    Write-Verbose "Calculating confidence for match: $($match.Spotify.name) <-> $($match.Audio.Title)"
                    $confidence = Get-MatchConfidence -ProviderTrack $match.Spotify -AudioFile $match.Audio
                    Write-Verbose "Confidence: $($confidence.Score)% ($($confidence.Level))"
                    
                    $pairedTracks += [PSCustomObject]@{
                        SpotifyTrack = $match.Spotify
                        AudioFile    = $match.Audio
                        Confidence   = $confidence.Score
                        ConfidenceLevel = $confidence.Level
                    }
                    $usedSpotify[$spotifyId] = $true
                    $usedAudio[$audioPath] = $true
                }
            }
            
            # Add unpaired Spotify tracks
            if ($SpotifyTracks -and $SpotifyTracks.Count -gt 0) {
                $unpairedSpotify = $SpotifyTracks | Where-Object { 
                    $sid = if ($_.id) { $_.id } else { $_.name }
                    -not $usedSpotify.ContainsKey($sid)
                }
                foreach ($spotify in $unpairedSpotify) {
                    $pairedTracks += [PSCustomObject]@{
                        SpotifyTrack = $spotify
                        AudioFile    = $null
                        Confidence   = 0
                        ConfidenceLevel = "Low"
                    }
                }
            }
            
            # Add unpaired audio files
            $unpairedAudio = $AudioFiles | Where-Object { 
                -not $usedAudio.ContainsKey($_.FilePath)
            }
            foreach ($audio in $unpairedAudio) {
                $pairedTracks += [PSCustomObject]@{
                    SpotifyTrack = $null
                    AudioFile    = $audio
                    Confidence   = 0
                    ConfidenceLevel = "Low"
                }
            }
        }
        "byTrackNumber" {
            # Check if audio files have valid track numbers (not all 0 or missing)
            $validTrackFiles = @($AudioFiles | Where-Object { 
                $_.TrackNumber -and $_.TrackNumber -gt 0 
            })
            $hasValidTrackNumbers = $validTrackFiles.Count
            
            $useOrderFallback = ($hasValidTrackNumbers -eq 0)
            
            if ($useOrderFallback) {
                Write-Verbose "Audio files lack valid track numbers, pairing by sorted order"
                # Sort both lists and pair sequentially
                $sortedSpotify = $SpotifyTracks | Sort-Object disc_number, track_number
                
                # Try to extract numeric prefix from filenames for smarter sorting
                $sortedAudio = $AudioFiles | Sort-Object {
                    $filename = [System.IO.Path]::GetFileName($_.FilePath)
                    # Try to extract leading number (e.g., "01 - Title.flac" -> 1)
                    if ($filename -match '^(\d+)') {
                        [int]$matches[1]
                    } else {
                        # No number found, sort alphabetically
                        $_.FilePath
                    }
                }
                
                if ($Reverse) {
                    # Iterate over audio files
                    foreach ($audio in $sortedAudio) {
                        $index = [Array]::IndexOf($sortedAudio, $audio)
                        $spotifyTrack = if ($index -lt $sortedSpotify.Count) { $sortedSpotify[$index] } else { $null }
                        
                        # Calculate confidence if both tracks exist
                        $confidence = if ($spotifyTrack -and $audio) {
                            Get-MatchConfidence -ProviderTrack $spotifyTrack -AudioFile $audio
                        } else { $null }
                        
                        $pairedTracks += [PSCustomObject]@{
                            SpotifyTrack = $spotifyTrack
                            AudioFile    = $audio
                            Confidence   = if ($confidence) { $confidence.Score } else { 0 }
                            ConfidenceLevel = if ($confidence) { $confidence.Level } else { "Low" }
                        }
                    }
                }
                else {
                    # Iterate over Spotify tracks
                    foreach ($spotify in $sortedSpotify) {
                        $index = [Array]::IndexOf($sortedSpotify, $spotify)
                        $audioFile = if ($index -lt $sortedAudio.Count) { $sortedAudio[$index] } else { $null }
                        
                        # Calculate confidence if both tracks exist
                        $confidence = if ($spotify -and $audioFile) {
                            Get-MatchConfidence -ProviderTrack $spotify -AudioFile $audioFile
                        } else { $null }
                        
                        $pairedTracks += [PSCustomObject]@{
                            SpotifyTrack = $spotify
                            AudioFile    = $audioFile
                            Confidence   = if ($confidence) { $confidence.Score } else { 0 }
                            ConfidenceLevel = if ($confidence) { $confidence.Level } else { "Low" }
                        }
                    }
                }
            }
            else {
                Write-Verbose "Matching audio files by existing disc/track numbers"
                
                # Check if any audio files have disc numbers (treat disc 0 as "no disc" since many files use it as default)
                $hasDiscNumbers = $AudioFiles | Where-Object { $_.DiscNumber -and $_.DiscNumber -gt 0 } | Select-Object -First 1
                
                # Check if provider has multiple discs
                $providerDiscs = ($SpotifyTracks | Select-Object -ExpandProperty disc_number -Unique | Measure-Object).Count
                $providerHasMultipleDiscs = $providerDiscs -gt 1
                
                if ($hasDiscNumbers -and $providerHasMultipleDiscs) {
                    # Audio files have disc numbers AND provider has multiple discs - use exact disc+track matching
                    Write-Verbose "Audio files have disc numbers, matching by disc+track"
                    if ($Reverse) {
                        foreach ($audio in $AudioFiles) {
                            $spotifyTrack = $SpotifyTracks | Where-Object { 
                                $_.disc_number -eq $audio.DiscNumber -and $_.track_number -eq $audio.TrackNumber 
                            } | Select-Object -First 1
                            
                            # Calculate confidence if both tracks exist
                            $confidence = if ($spotifyTrack -and $audio) {
                                Get-MatchConfidence -ProviderTrack $spotifyTrack -AudioFile $audio
                            } else { $null }
                            
                            $pairedTracks += [PSCustomObject]@{
                                SpotifyTrack = $spotifyTrack
                                AudioFile    = $audio
                                Confidence   = if ($confidence) { $confidence.Score } else { 0 }
                                ConfidenceLevel = if ($confidence) { $confidence.Level } else { "Low" }
                            }
                        }
                    }
                    else {
                        $SpotifyTracks = $SpotifyTracks | Sort-Object disc_number, track_number
                        foreach ($spotify in $SpotifyTracks) {
                            $audioFile = $AudioFiles | Where-Object { 
                                $_.DiscNumber -eq $spotify.disc_number -and $_.TrackNumber -eq $spotify.track_number 
                            } | Select-Object -First 1
                            
                            # Calculate confidence if both tracks exist
                            $confidence = if ($spotify -and $audioFile) {
                                Get-MatchConfidence -ProviderTrack $spotify -AudioFile $audioFile
                            } else { $null }
                            
                            $pairedTracks += [PSCustomObject]@{
                                SpotifyTrack = $spotify
                                AudioFile    = $audioFile
                                Confidence   = if ($confidence) { $confidence.Score } else { 0 }
                                ConfidenceLevel = if ($confidence) { $confidence.Level } else { "Low" }
                            }
                        }
                    }
                }
                else {
                    # Single disc scenario OR audio files lack disc numbers - match by track number only
                    Write-Verbose "Single disc or no disc numbers, matching by track number only"
                    $sortedSpotify = $SpotifyTracks | Sort-Object disc_number, track_number
                    $sortedAudio = $AudioFiles | Sort-Object TrackNumber
                    
                    if ($Reverse) {
                        foreach ($audio in $sortedAudio) {
                            # Match by track number only, ignoring disc
                            $spotifyTrack = $sortedSpotify | Where-Object { 
                                $_.track_number -eq $audio.TrackNumber 
                            } | Select-Object -First 1
                            
                            # Calculate confidence if both tracks exist
                            $confidence = if ($spotifyTrack -and $audio) {
                                Get-MatchConfidence -ProviderTrack $spotifyTrack -AudioFile $audio
                            } else { $null }
                            
                            $pairedTracks += [PSCustomObject]@{
                                SpotifyTrack = $spotifyTrack
                                AudioFile    = $audio
                                Confidence   = if ($confidence) { $confidence.Score } else { 0 }
                                ConfidenceLevel = if ($confidence) { $confidence.Level } else { "Low" }
                            }
                        }
                    }
                    else {
                        foreach ($spotify in $sortedSpotify) {
                            # Match by track number only
                            $audioFile = $sortedAudio | Where-Object { 
                                $_.TrackNumber -eq $spotify.track_number 
                            } | Select-Object -First 1
                            
                            # Calculate confidence if both tracks exist
                            $confidence = if ($spotify -and $audioFile) {
                                Get-MatchConfidence -ProviderTrack $spotify -AudioFile $audioFile
                            } else { $null }
                            
                            $pairedTracks += [PSCustomObject]@{
                                SpotifyTrack = $spotify
                                AudioFile    = $audioFile
                                Confidence   = if ($confidence) { $confidence.Score } else { 0 }
                                ConfidenceLevel = if ($confidence) { $confidence.Level } else { "Low" }
                            }
                        }
                    }
                }
            }
        }
        "byDuration" {
            # Build all possible matches with scores (duration + title similarity)
            $matchesR = @()
            
            foreach ($spotify in $SpotifyTracks) {
                foreach ($audio in $AudioFiles) {
                    $diff = [Math]::Abs($spotify.duration_ms - $audio.Duration)
                    $tolerance = $spotify.duration_ms * 0.1  # 10% tolerance
                    
                    if ($diff -le $tolerance) {
                        # Primary: Duration score (closer = higher score)
                        $durationScore = 1 - ($diff / $tolerance)
                        
                        # Secondary: Title similarity as tiebreaker
                        $titleSimilarity = Get-StringSimilarity-Jaccard -String1 $spotify.name -String2 $audio.Title
                        
                        # Combined score: duration (70%) + title (30%)
                        $score = ($durationScore * 70) + ($titleSimilarity * 30)
                        
                        $matchesR += [PSCustomObject]@{
                            Spotify = $spotify
                            Audio   = $audio
                            Score   = $score
                        }
                    }
                }
            }
            
            # Greedy assignment with deduplication
            $matchesR = $matchesR | Sort-Object Score -Descending
            $usedSpotify = @{}
            $usedAudio = @{}
            
            foreach ($match in $matchesR) {
                $spotifyId = if ($match.Spotify.id) { $match.Spotify.id } else { $match.Spotify.name }
                $audioPath = $match.Audio.FilePath
                
                if (-not $usedSpotify.ContainsKey($spotifyId) -and 
                    -not $usedAudio.ContainsKey($audioPath)) {
                    
                    # Calculate confidence for the match
                    $confidence = Get-MatchConfidence -ProviderTrack $match.Spotify -AudioFile $match.Audio
                    
                    $pairedTracks += [PSCustomObject]@{
                        SpotifyTrack = $match.Spotify
                        AudioFile    = $match.Audio
                        Confidence   = $confidence.Score
                        ConfidenceLevel = $confidence.Level
                    }
                    $usedSpotify[$spotifyId] = $true
                    $usedAudio[$audioPath] = $true
                }
            }
            
            # Add unpaired Spotify tracks
            if ($SpotifyTracks -and $SpotifyTracks.Count -gt 0) {
                $unpairedSpotify = $SpotifyTracks | Where-Object { 
                    $sid = if ($_.id) { $_.id } else { $_.name }
                    -not $usedSpotify.ContainsKey($sid)
                }
                foreach ($spotify in $unpairedSpotify) {
                    $pairedTracks += [PSCustomObject]@{
                        SpotifyTrack = $spotify
                        AudioFile    = $null
                        Confidence   = 0
                        ConfidenceLevel = "Low"
                    }
                }
            }
            
            # Add unpaired audio files
            $unpairedAudio = $AudioFiles | Where-Object { 
                -not $usedAudio.ContainsKey($_.FilePath)
            }
            foreach ($audio in $unpairedAudio) {
                $pairedTracks += [PSCustomObject]@{
                    SpotifyTrack = $null
                    AudioFile    = $audio
                    Confidence   = 0
                    ConfidenceLevel = "Low"
                }
            }
        }
        "hybrid" {
            # Check if provider has multiple discs - if not, ignore disc number in matching
            $providerDiscs = ($SpotifyTracks | Select-Object -ExpandProperty disc_number -Unique | Measure-Object).Count
            $providerHasMultipleDiscs = $providerDiscs -gt 1
            
            if ($Reverse) {
                # Hybrid: Iterate over audio files, score against Spotify tracks
                $discTrackWeight = 50
                $titleWeight = 30
                $durationWeight = 20
                
                $matchesR = @()
                foreach ($audio in $AudioFiles) {
                    foreach ($spotify in $SpotifyTracks) {
                        $score = 0
                        
                        # Disc/Track match - ignore disc if provider is single-disc
                        $discMatch = if ($providerHasMultipleDiscs) {
                            $spotify.disc_number -eq $audio.DiscNumber
                        } else {
                            $true  # Single disc, always match disc
                        }
                        
                        if ($discMatch -and $spotify.track_number -eq $audio.TrackNumber) {
                            $score += $discTrackWeight
                        }
                        
                        # Title similarity
                        $similarity = Get-StringSimilarity-Jaccard -String1 $audio.Title -String2 $spotify.name
                        $score += $similarity * $titleWeight
                        
                        # Duration closeness
                        $diff = [Math]::Abs($audio.Duration - $spotify.duration_ms)
                        $tolerance = $audio.Duration * 0.1
                        $durationScore = if ($diff -le $tolerance) { 1 - ($diff / $tolerance) } else { 0 }
                        $score += $durationScore * $durationWeight
                        
                        $matchesR += [PSCustomObject]@{
                            Spotify = $spotify
                            Audio   = $audio
                            Score   = $score
                        }
                    }
                }
                
                # Greedy assignment
                $matchesR = $matchesR | Sort-Object Score -Descending
                $usedSpotify = @{}
                foreach ($match in $matchesR) {
                    if (-not $usedSpotify.ContainsKey($match.Spotify.id) -and $match.Score -ge 20) {
                        $pairedTracks += [PSCustomObject]@{
                            SpotifyTrack = $match.Spotify
                            AudioFile    = $match.Audio
                        }
                        $usedSpotify[$match.Spotify.id] = $true
                    }
                }
                
                # Add unpaired audio files
                $pairedAudio = $pairedTracks | ForEach-Object { $_.AudioFile }
                $unpairedAudio = $AudioFiles | Where-Object { $_ -notin $pairedAudio }
                foreach ($audio in $unpairedAudio) {
                    $pairedTracks += [PSCustomObject]@{
                        SpotifyTrack = $null
                        AudioFile    = $audio
                    }
                }
            }
            else {
                # Original hybrid logic
                $discTrackWeight = 50
                $titleWeight = 30
                $durationWeight = 20
                
                $matchesR = @()
                foreach ($spotify in $SpotifyTracks) {
                    foreach ($audio in $AudioFiles) {
                        $score = 0
                        
                        # Disc/Track match - ignore disc if provider is single-disc
                        $discMatch = if ($providerHasMultipleDiscs) {
                            $audio.DiscNumber -eq $spotify.disc_number
                        } else {
                            $true  # Single disc, always match disc
                        }
                        
                        if ($discMatch -and $audio.TrackNumber -eq $spotify.track_number) {
                            $score += $discTrackWeight
                        }
                        
                        $similarity = Get-StringSimilarity-Jaccard -String1 $spotify.name -String2 $audio.Title
                        $score += $similarity * $titleWeight
                        
                        $diff = [Math]::Abs($spotify.duration_ms - $audio.Duration)
                        $tolerance = $spotify.duration_ms * 0.1
                        $durationScore = if ($diff -le $tolerance) { 1 - ($diff / $tolerance) } else { 0 }
                        $score += $durationScore * $durationWeight
                        
                        $matchesR += [PSCustomObject]@{
                            Spotify = $spotify
                            Audio   = $audio
                            Score   = $score
                        }
                    }
                }
                
                $matchesR = $matchesR | Sort-Object Score -Descending
                $usedAudio = @{}
                foreach ($match in $matchesR) {
                    if (-not $usedAudio.ContainsKey($match.Audio.FilePath) -and $match.Score -ge 20) {
                        $pairedTracks += [PSCustomObject]@{
                            SpotifyTrack = $match.Spotify
                            AudioFile    = $match.Audio
                        }
                        $usedAudio[$match.Audio.FilePath] = $true
                    }
                }
                
                $pairedSpotify = $pairedTracks | ForEach-Object { $_.SpotifyTrack }
                $unpairedSpotify = $SpotifyTracks | Where-Object { $_ -notin $pairedSpotify }
                foreach ($spotify in $unpairedSpotify) {
                    $pairedTracks += [PSCustomObject]@{
                        SpotifyTrack = $spotify
                        AudioFile    = $null
                    }
                }
            }
        }
        "manual" {
            # Manual mode inherits the current pairing from whatever sort method was used before
            # This allows users to refine good matches (e.g., from byTitle) with 1-2 manual corrections
            # instead of starting from scratch
            if ($Reverse) {
                # Reverse mode: iterate over audio files, let user pick from Spotify tracks
                $pairedTracks = Select-matches -AudioFiles $AudioFiles -SpotifyTracks $SpotifyTracks -PairedTracks $pairedTracks -Reverse
            }
            else {
                # Normal mode: iterate over Spotify tracks, let user pick from audio files
                $pairedTracks = Select-matches -AudioFiles $AudioFiles -SpotifyTracks $SpotifyTracks -PairedTracks $pairedTracks
            }
        }
    }

    return $pairedTracks
}
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
        # byOrder: each one in the order by which they came in
        "byOrder" {
            if ($Reverse) {
                # Iterate over audio files, match to Spotify by order
                foreach ($audio in $AudioFiles) {
                    $index = [Array]::IndexOf($AudioFiles, $audio)
                    $spotifyTrack = if ($index -lt $SpotifyTracks.Count) { $SpotifyTracks[$index] } else { $null }
                    
                    $pairedTracks += [PSCustomObject]@{
                        SpotifyTrack = $spotifyTrack
                        AudioFile    = $audio
                    }
                }
            }
            else {
                # Original: Iterate over Spotify tracks
                foreach ($spotify in $SpotifyTracks) {
                    $index = [Array]::IndexOf($SpotifyTracks, $spotify)
                    $audioFile = if ($index -lt $AudioFiles.Count) { $AudioFiles[$index] } else { $null }
                    
                    $pairedTracks += [PSCustomObject]@{
                        SpotifyTrack = $spotify
                        AudioFile    = $audioFile
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
                    
                    $pairedTracks += [PSCustomObject]@{
                        SpotifyTrack = $match.Spotify
                        AudioFile    = $match.Audio
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
                    
                    # Only consider if similarity is reasonable (>= 0.5)
                    if ($titleSimilarity -ge 0.5) {
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
                    
                    $pairedTracks += [PSCustomObject]@{
                        SpotifyTrack = $match.Spotify
                        AudioFile    = $match.Audio
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
        "byTrackNumber" {
            if ($Reverse) {
                Write-Host "DEBUG: Using Reverse mode for byTrackNumber"
                # Iterate over audio files, match to Spotify by disc/track
                foreach ($audio in $AudioFiles) {
                    $spotifyTrack = $SpotifyTracks | Where-Object { 
                        $_.disc_number -eq $audio.DiscNumber -and $_.track_number -eq $audio.TrackNumber 
                    } | Select-Object -First 1
                    
                    $pairedTracks += [PSCustomObject]@{
                        SpotifyTrack = $spotifyTrack
                        AudioFile    = $audio
                    }
                }
            }
            else {
                Write-Debug "Using Normal mode for byTrackNumber"
                # Original: Iterate over Spotify tracks
                $SpotifyTracks = $SpotifyTracks | Sort-Object disc_number, track_number
                foreach ($spotify in $SpotifyTracks) {
                    $audioFile = $AudioFiles | Where-Object { 
                        $_.DiscNumber -eq $spotify.disc_number -and $_.TrackNumber -eq $spotify.track_number 
                    } | Select-Object -First 1
                    
                    $pairedTracks += [PSCustomObject]@{
                        SpotifyTrack = $spotify
                        AudioFile    = $audioFile
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
                    
                    $pairedTracks += [PSCustomObject]@{
                        SpotifyTrack = $match.Spotify
                        AudioFile    = $match.Audio
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
        "hybrid" {
            if ($Reverse) {
                # Hybrid: Iterate over audio files, score against Spotify tracks
                $discTrackWeight = 50
                $titleWeight = 30
                $durationWeight = 20
                
                $matchesR = @()
                foreach ($audio in $AudioFiles) {
                    foreach ($spotify in $SpotifyTracks) {
                        $score = 0
                        
                        # Disc/Track match
                        if ($spotify.disc_number -eq $audio.DiscNumber -and $spotify.track_number -eq $audio.TrackNumber) {
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
                        
                        if ($audio.DiscNumber -eq $spotify.disc_number -and $audio.TrackNumber -eq $spotify.track_number) {
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
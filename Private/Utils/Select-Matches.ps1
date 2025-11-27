function Select-matches {
    #given the $audioFiles and $SpotifyTracks it should output the $audioFiles sorted in a manual way to match the spotifyTracks
    # If PairedTracks is provided, uses that order as the starting point for manual refinement
    param(
        [array]$AudioFiles,
        [array]$SpotifyTracks,
        [array]$PairedTracks,  # Pre-sorted pairing from previous sort method
        [switch]$Reverse
    )

    # Use provided pairing order if available, otherwise start fresh
    $pairedTracks = @()
    
    # If we have a pre-sorted pairing, use its order to pre-sort the lists
    if ($PairedTracks -and $PairedTracks.Count -gt 0) {
        if ($Reverse) {
            # In reverse mode, sort AudioFiles by the order they appear in PairedTracks
            $orderedAudioFiles = @()
            foreach ($pair in $PairedTracks) {
                if ($pair.AudioFile) {
                    $orderedAudioFiles += $pair.AudioFile
                }
            }
            # Add any audio files not in the pairing (shouldn't happen, but be safe)
            foreach ($audio in $AudioFiles) {
                if ($audio -notin $orderedAudioFiles) {
                    $orderedAudioFiles += $audio
                }
            }
            $AudioFiles = $orderedAudioFiles
        }
        else {
            # In normal mode, sort SpotifyTracks by the order they appear in PairedTracks
            $orderedSpotifyTracks = @()
            foreach ($pair in $PairedTracks) {
                if ($pair.SpotifyTrack) {
                    $orderedSpotifyTracks += $pair.SpotifyTrack
                }
            }
            # Add any Spotify tracks not in the pairing
            foreach ($spotify in $SpotifyTracks) {
                if ($spotify -notin $orderedSpotifyTracks) {
                    $orderedSpotifyTracks += $spotify
                }
            }
            $SpotifyTracks = $orderedSpotifyTracks
        }
    }

    if ($Reverse) {
        # Reverse mode: iterate over each audio file, let user pick from Spotify tracks
        foreach ($audioFile in $AudioFiles) {
            $audioName = if ($audioFile.Name) { $audioFile.Name } else { Split-Path -Leaf $audioFile.FilePath }
            
            $selected = $SpotifyTracks | Select-Object -Property @{N='Track';E={$_.track_number}}, @{N='Disc';E={$_.disc_number}}, Name, @{N='Duration';E={[TimeSpan]::FromMilliseconds($_.duration_ms).ToString('mm\:ss')}}, id | Out-GridView -Title "Select provider track for audio file: $audioName" -PassThru
            
           if ($selected) {
                $spotifyTrack = $SpotifyTracks | Where-Object { $_.id -eq $selected.id }
                $pairedTracks += [PSCustomObject]@{
                    SpotifyTrack = $spotifyTrack
                    AudioFile    = $audioFile
                }
                # Remove selected track to avoid duplicates
                $SpotifyTracks = $SpotifyTracks | Where-Object { $_ -ne $spotifyTrack }
            }
            else {
                # User skipped - add unpaired audio file
                $pairedTracks += [PSCustomObject]@{
                    SpotifyTrack = $null
                    AudioFile    = $audioFile
                }
            }
        }
        
        # Add any remaining unpaired Spotify tracks
        foreach ($spotify in $SpotifyTracks) {
            $pairedTracks += [PSCustomObject]@{
                SpotifyTrack = $spotify
                AudioFile    = $null
            }
        }
    }
    else {
        # Normal mode: iterate over Spotify tracks, let user pick from audio files
        foreach ($spotifyTrack in $SpotifyTracks) {
            $audioFile = $AudioFiles | Out-GridView -Title "Select matching audio file for '$($spotifyTrack.Name)'" -PassThru

            if ($audioFile) {
                $pairedTracks += [PSCustomObject]@{
                    SpotifyTrack = $spotifyTrack
                    AudioFile    = $audioFile
                }
                # Remove selected audio file to avoid duplicates
                $AudioFiles = $AudioFiles | Where-Object { $_ -ne $audioFile }
            }
            else {
                # User skipped - add unpaired Spotify track
                $pairedTracks += [PSCustomObject]@{
                    SpotifyTrack = $spotifyTrack
                    AudioFile    = $null
                }
            }
        }
        
        # Add any remaining unpaired audio files
        foreach ($audio in $AudioFiles) {
            $pairedTracks += [PSCustomObject]@{
                SpotifyTrack = $null
                AudioFile    = $audio
            }
        }
    }

    return $pairedTracks
}
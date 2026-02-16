function Select-matches {
    #given the $audioFiles and $ProviderTracks it should output the $audioFiles sorted in a manual way to match the providerTracks
    # If PairedTracks is provided, uses that order as the starting point for manual refinement
    param(
        [array]$AudioFiles,
        [array]$ProviderTracks,
        [array]$PairedTracks,  # Pre-sorted pairing from previous sort method
        [switch]$Reverse
    )

    # Use provided pairing order if available, otherwise start fresh
    $pairedTracks = [System.Collections.Generic.List[PSCustomObject]]::new()
    
    # If we have a pre-sorted pairing, use its order to pre-sort the lists
    if ($PairedTracks -and $PairedTracks.Count -gt 0) {
        if ($Reverse) {
            # In reverse mode, sort AudioFiles by the order they appear in PairedTracks
            $orderedAudioFiles = [System.Collections.Generic.List[object]]::new()
            foreach ($pair in $PairedTracks) {
                if ($pair.AudioFile) {
                    $orderedAudioFiles.Add($pair.AudioFile)
                }
            }
            # Add any audio files not in the pairing (shouldn't happen, but be safe)
            foreach ($audio in $AudioFiles) {
                if ($audio -notin $orderedAudioFiles) {
                    $orderedAudioFiles.Add($audio)
                }
            }
            $AudioFiles = $orderedAudioFiles
        }
        else {
            # In normal mode, sort providerTracks by the order they appear in PairedTracks
            $orderedproviderTracks = [System.Collections.Generic.List[object]]::new()
            foreach ($pair in $PairedTracks) {
                if ($pair.ProviderTrack) {
                    $orderedproviderTracks.Add($pair.ProviderTrack)
                }
            }
            # Add any provider tracks not in the pairing
            foreach ($provider in $ProviderTracks) {
                if ($provider -notin $orderedproviderTracks) {
                    $orderedproviderTracks.Add($provider)
                }
            }
            $ProviderTracks = $orderedproviderTracks
        }
    }

    if ($Reverse) {
        # Reverse mode: iterate over each audio file, let user pick from provider tracks
        foreach ($audioFile in $AudioFiles) {
            $audioName = if ($audioFile.Name) { $audioFile.Name } else { Split-Path -Leaf $audioFile.FilePath }
            
            $selected = $ProviderTracks | Select-Object -Property @{N='Track';E={$_.track_number}}, @{N='Disc';E={$_.disc_number}}, Name, @{N='Duration';E={[TimeSpan]::FromMilliseconds($_.duration_ms).ToString('mm\:ss')}}, id | Out-GridView -Title "Select provider track for audio file: $audioName" -PassThru
            
           if ($selected) {
                $providerTrack = $ProviderTracks | Where-Object { $_.id -eq $selected.id }
                $pairedTracks.Add([PSCustomObject]@{
                    ProviderTrack = $providerTrack
                    AudioFile    = $audioFile
                })
                # Remove selected track to avoid duplicates
                $ProviderTracks = $ProviderTracks | Where-Object { $_ -ne $providerTrack }
            }
            else {
                # User skipped - add unpaired audio file
                $pairedTracks.Add([PSCustomObject]@{
                    ProviderTrack = $null
                    AudioFile    = $audioFile
                })
            }
        }
        
        # Add any remaining unpaired provider tracks
        foreach ($provider in $ProviderTracks) {
            $pairedTracks.Add([PSCustomObject]@{
                ProviderTrack = $provider
                AudioFile    = $null
            })
        }
    }
    else {
        # Normal mode: iterate over provider tracks, let user pick from audio files
        foreach ($providerTrack in $ProviderTracks) {
            $audioFile = $AudioFiles | Out-GridView -Title "Select matching audio file for '$($providerTrack.Name)'" -PassThru

            if ($audioFile) {
                $pairedTracks.Add([PSCustomObject]@{
                    ProviderTrack = $providerTrack
                    AudioFile    = $audioFile
                })
                # Remove selected audio file to avoid duplicates
                $AudioFiles = $AudioFiles | Where-Object { $_ -ne $audioFile }
            }
            else {
                # User skipped - add unpaired provider track
                $pairedTracks.Add([PSCustomObject]@{
                    ProviderTrack = $providerTrack
                    AudioFile    = $null
                })
            }
        }
        
        # Add any remaining unpaired audio files
        foreach ($audio in $AudioFiles) {
            $pairedTracks.Add([PSCustomObject]@{
                ProviderTrack = $null
                AudioFile    = $audio
            })
        }
    }

    return $pairedTracks
}
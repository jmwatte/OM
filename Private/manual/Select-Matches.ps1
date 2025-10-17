function Select-matches {
    #given the $audioFiles and $SpotifyTracks it should output the $audioFiles sorted in a manual way to match the spotifyTracks
    param(
        [array]$AudioFiles,
        [array]$SpotifyTracks,
        [switch]$Reverse
    )

    $pairedTracks = @()

    if ($Reverse) {
        # Reverse mode: iterate over each audio file, let user pick from Spotify tracks
        foreach ($audioFile in $AudioFiles) {
            $audioName = if ($audioFile.Name) { $audioFile.Name } else { Split-Path -Leaf $audioFile.FilePath }
            
            $spotifyTrack = $SpotifyTracks | Out-GridView -Title "Select provider track for audio file: $audioName" -PassThru
            
            if ($spotifyTrack) {
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
function Show-Tracks {
    param (
        [array]$PairedTracks,
        [string]$AlbumName,
        [PSCustomObject]$SpotifyArtist,
        [switch]$Reverse,
        [string]$OptionsText,
        [string[]]$ValidCommands,
        [string]$PromptColor = 'Gray',
        [scriptblock]$InputReader,
        [string]$ProviderName = 'Spotify'
    )

    $supportsCommands = $ValidCommands -and $ValidCommands.Count -gt 0
    $commandLookup = @{}
    if ($supportsCommands) {
        foreach ($cmd in $ValidCommands) {
            if ($null -ne $cmd) {
                $commandLookup[$cmd.ToString().ToLowerInvariant()] = $cmd
            }
        }
    }

    $reader = if ($InputReader) { $InputReader } else { { param($prompt) Read-Host -Prompt $prompt } }

    $pageSize = 10
    $page = 0
    $totalPages = if ($PairedTracks.Count -gt 0) { [math]::Ceiling($PairedTracks.Count / $pageSize) } else { 1 }

    while ($true) {
        Clear-Host  # Temporarily commented to preserve verbose output for debugging
        Write-Host "Tracks for album $($AlbumName): (Page $($page + 1) of $totalPages)`n"

        if ($PairedTracks.Count -eq 0) {
            Write-Host "No tracks available for display." -ForegroundColor Yellow
            Write-Host "`nPage 1 of 1 (Tracks 0 of 0)"
        }
        else {
            $start = $page * $pageSize
            $end = [math]::Min($start + $pageSize - 1, $PairedTracks.Count - 1)

            for ($i = $start; $i -le $end; $i++) {
                $pair = $PairedTracks[$i]
                $num = $i + 1

                $spotify = $pair.SpotifyTrack
                $audio = $pair.AudioFile

                $filenameDisplay = if ($audio) { "filename: $(Split-Path -Leaf $audio.FilePath)" } else { "" }
                Write-Host "[$num] $filenameDisplay" -ForegroundColor DarkGray

                $artistDisplay = 'Unknown'
                if ($spotify) {
                    $disc = if ($value = Get-IfExists $spotify 'disc_number') { $value } else { 1 }
                    $track = if ($value = Get-IfExists $spotify 'track_number') { $value } else { 0 }
                    
                    # Format duration from milliseconds
                    $durationMs = if ($value = Get-IfExists $spotify 'duration_ms') { $value } elseif ($value = Get-IfExists $spotify 'duration') { $value } else { 0 }
                    $durationSpan = [TimeSpan]::FromMilliseconds($durationMs)
                    $durationStr = "{0:mm\:ss}" -f $durationSpan
                    
                    Write-Host ("↓`t{0:D2}.{1:D2}: {2} ({3})" -f $disc, $track, $spotify.name, $durationStr)

                    $a = $spotify.artists
                    if ($a -is [System.Collections.IEnumerable] -and -not ($a -is [string])) {
                        $artistDisplay = ($a | ForEach-Object { if ($_.PSObject.Properties.Match('name')) { $_.name } else { $_ } }) -join ', '
                    }
                    elseif ($a -and $a.PSObject.Properties.Match('name')) {
                        $artistDisplay = $a.name
                    }
                    else {
                        $artistDisplay = $a
                    }
                    Write-Host ("`t`tartist: {0}" -f $artistDisplay)

                    # Prefer track-level genres over artist-level (better for classical, MusicBrainz)
                    if ($value = Get-IfExists $spotify 'genres') {
                        $providerGenres = $value -join ', '
                        Write-Host ("`t`tgenres: {0}" -f $providerGenres)
                    }
                    elseif ($value = Get-IfExists $SpotifyArtist 'genres') {
                        $providerGenres = $value -join ', '
                        Write-Host ("`t`tgenres: {0}" -f $providerGenres)
                    }

                    if ($value = Get-IfExists $spotify 'composer') {
                        if ($value -is [System.Collections.IEnumerable] -and -not ($value -is [string])) {
                            $providerComposer = $value -join ', '
                        }
                        else {
                            $providerComposer = $value
                        }
                        Write-Host ("`t`tcomposer: {0}" -f $providerComposer)
                    }
                }
                else {
                    Write-Host "↓ No $ProviderName track data available"
                }

                if ($audio) {
                    $arrow = if ($Reverse) { '↑' } else { '_' }
                    $color = if ($spotify -and $audio.Title -eq $spotify.name) { 'Green' } else { 'Yellow' }
                    
                    # Format audio file duration (stored as milliseconds in Start-OM)
                    $audioDurationStr = if ($audio.Duration) {
                        if ($audio.Duration -is [TimeSpan]) {
                            "{0:mm\:ss}" -f $audio.Duration
                        }
                        else {
                            # Duration is in milliseconds
                            $durationSpan = [TimeSpan]::FromMilliseconds($audio.Duration)
                            "{0:mm\:ss}" -f $durationSpan
                        }
                    }
                    else {
                        "00:00"
                    }
                    
                    Write-Host ("$arrow`t{0:D2}.{1:D2}: {2} ({3})" -f $audio.DiscNumber, $audio.TrackNumber, $audio.Title, $audioDurationStr) -ForegroundColor $color

                    $audioArtist = if ($value = Get-IfExists $audio 'Artist') { $value } else { 'Unknown' }
                    $artistColor = if ($spotify -and $audioArtist -eq $artistDisplay) { 'Green' } else { 'Yellow' }
                    Write-Host ("`t`tartist: {0}" -f $audioArtist) -ForegroundColor $artistColor

                    # Read genres from TagLib.Tag (uppercase T)
                    $audioGenresValue = if ($audio.TagFile -and $audio.TagFile.Tag -and $audio.TagFile.Tag.Genres) { $audio.TagFile.Tag.Genres } else { $null }
                    $audioGenres = if ($audioGenresValue) { $audioGenresValue -join ', ' } else { 'Unknown' }
                    $spotifyGenresValue = Get-IfExists $SpotifyArtist 'genres'
                    $genresColor = if ($spotifyGenresValue -and ($audioGenres -eq ($spotifyGenresValue -join ', '))) { 'Green' } else { 'Yellow' }
                    Write-Host ("`t`tgenres: {0}" -f $audioGenres) -ForegroundColor $genresColor

                    $audioComposerValue = Get-IfExists $audio 'Composer'
                    $audioComposer = if ($audioComposerValue) { if ($audioComposerValue -is [array]) { $audioComposerValue -join ', ' } else { $audioComposerValue } } else { 'Unknown' }
                    $spotifyComposerValue = Get-IfExists $spotify 'Composer'
                    $composerColor = if ($spotifyComposerValue -and ($audioComposer -eq ($spotifyComposerValue -join ', '))) { 'Green' } else { 'Yellow' }
                    Write-Host ("`t`tcomposer: {0}" -f $audioComposer) -ForegroundColor $composerColor

                    # Display additional classical music / detailed credits (if from Qobuz)
                    if ($spotifyConductor = Get-IfExists $spotify 'Conductor') {
                        Write-Host ("`t`tconductor: {0}" -f $spotifyConductor) -ForegroundColor Cyan
                    }
                    if ($spotifyEnsemble = Get-IfExists $spotify 'Ensemble') {
                        Write-Host ("`t`tensemble: {0}" -f $spotifyEnsemble) -ForegroundColor Cyan
                    }
                    if ($spotifyFeatured = Get-IfExists $spotify 'FeaturedArtist') {
                        Write-Host ("`t`tfeatured: {0}" -f $spotifyFeatured) -ForegroundColor Cyan
                    }
                    
                    # Display detailed role breakdown if available (Qobuz rich metadata)
                    if ($detailedRoles = Get-IfExists $spotify 'DetailedRoles') {
                        if ($detailedRoles -and $detailedRoles.Count -gt 0) {
                            Write-Host "`t`t--- Production Credits ---" -ForegroundColor DarkCyan
                            foreach ($person in ($detailedRoles.Keys | Sort-Object)) {
                                $roles = $detailedRoles[$person]
                                Write-Host ("`t`t{0}: {1}" -f $person, $roles) -ForegroundColor DarkCyan
                            }
                        }
                    }

                    # Filename is now displayed in the header line above
                }
                else {
                    Write-Host "_ No matching audio file" -ForegroundColor Red
                }

                Write-Host ""
            }

            $lastIndex = [math]::Min($end + 1, $PairedTracks.Count)
            Write-Host "`nPage $($page + 1) of $totalPages (Tracks $($start + 1) to $lastIndex of $($PairedTracks.Count))"
        }

        if ($supportsCommands -and $OptionsText) {
            Write-Host $OptionsText -ForegroundColor $PromptColor
        }

        $promptMessage = if ($supportsCommands) { "Enter command (Enter=next, p=previous, q=classic options)" } else { "Press Enter for next page, 'p' for previous, 'q' to quit viewing" }
        $inputRaw = & $reader $promptMessage
        $inputText = if ($null -ne $inputRaw) { $inputRaw.Trim() } else { '' }
        $inputLower = $inputText.ToLowerInvariant()

        if ($inputLower -eq '' -or $inputLower -eq 'n') {
            if ($PairedTracks.Count -eq 0) { return $null }
            $page++
            if ($page -ge $totalPages) { $page = [math]::Max($totalPages - 1, 0) }
            continue
        }

        if ($inputLower -eq 'p') {
            if ($PairedTracks.Count -eq 0) { return $null }
            if ($page -gt 0) { $page-- }
            continue
        }

        if ($inputLower -eq 'q') {
            if ($supportsCommands) { return 'q' }
            return
        }

        if ($supportsCommands -and $commandLookup.ContainsKey($inputLower)) {
            return $inputLower
        }

        if ($supportsCommands) {
            foreach ($cmdKey in $commandLookup.Keys) {
                if ($inputLower.StartsWith("$cmdKey ")) {
                    return $inputLower
                }
            }
        }

        Write-Host "Unrecognized input: '$inputText'." -ForegroundColor Yellow
        Start-Sleep -Seconds 1
    }
}



# function Show-Tracks {
#     param (
#         [array]$PairedTracks,
#         [string]$AlbumName,
#         [object]$SpotifyArtist
#     )

#     #Clear-Host
#     Write-Host "Tracks for album $($AlbumName):`n"

#     for ($i = 0; $i -lt $PairedTracks.Count; $i++) {
#         $num = $i + 1
#         $pair = $PairedTracks[$i]
#         $spotify = $pair.SpotifyTrack
#         $audio = $pair.AudioFile

#         Write-Host "[$num]"

#         # Display Spotify track info
#         if ($null -ne $spotify) {
#             Write-Host ("↓`t{0:D2}.{1:D2}: {2}" -f $spotify.disc_number, $spotify.track_number, $spotify.name)
            
#             # Artist: support multiple shapes (string, array of strings, array of objects with .name)
#             $artistDisplay = ''
#             if ($spotify.PSObject.Properties['artists']) {
#                 $a = $spotify.artists
#                 if ($a -is [System.Collections.IEnumerable] -and -not ($a -is [string])) { 
#                     $artistDisplay = ($a | ForEach-Object { if ($_.PSObject.Properties.Match('name')) { $_.name } else { $_ } }) -join ', ' 
#                 } else { 
#                     $artistDisplay = $a 
#                 }
#             }
#             Write-Host ("`t`tartist: {0}" -f $artistDisplay)

#             # Write genres if present on SpotifyArtist object (defensive)
#             $providerGenres = ''
#             if ($null -ne $SpotifyArtist -and $SpotifyArtist.PSObject.Properties['genres'] -and $SpotifyArtist.genres -and $SpotifyArtist.genres.Count -gt 0) {
#                 $providerGenres = $SpotifyArtist.genres -join ', '
#                 Write-Host ("`t`tgenres: {0}" -f $providerGenres)
#             }
#             elseif ($spotify.PSObject.Properties['genres'] -and $spotify.genres) {
#                 $providerGenres = $spotify.genres -join ', '
#                 Write-Host ("`t`tgenres: {0}" -f $providerGenres)
#             }

#             # Write composer if present (handle single string or array)
#             $providerComposer = ''        
#             if ($spotify.PSObject.Properties['composer'] -and $spotify.Composer) {
#                 $c = $spotify.Composer
#                 if ($c -is [System.Collections.IEnumerable] -and -not ($c -is [string])) { 
#                     $providerComposer = ($c -join ', ') 
#                 } else { 
#                     $providerComposer = $c 
#                 }
#                 Write-Host ("`t`tcomposer: {0}" -f $providerComposer)
#             }
#         } else {
#             Write-Host "↓ No Spotify track data available"
#         }

#         # Display AudioFile info
#         if ($null -ne $audio) {
#             $match = $false
#             if ($null -ne $spotify) {
#                 $match = (
#                     $spotify.disc_number -eq $audio.DiscNumber -and
#                     $spotify.track_number -eq $audio.TrackNumber -and
#                     $spotify.name -eq $audio.Name
#                 )
#             }

#             $color = if ($match) { 'Green' } else { 'Yellow' }

#             # Prepare audio strings for comparison
#             $audioArtist = $audio.TagFile.Tag.Performers -join ', '
#             $audioGenres = if ($audio.TagFile.Tag.Genres) { $audio.TagFile.Tag.Genres -join ', ' } else { '' }
#             $audioComposer = $audio.TagFile.Tag.Composers -join ', '

#             # Determine colors for each field based on match (only if Spotify data exists)
#             if ($null -ne $spotify) {
#                 $artistColor = if ($artistDisplay -eq $audioArtist) { 'Green' } else { 'Yellow' }
#                 $genresColor = if ($providerGenres -eq $audioGenres) { 'Green' } else { 'Yellow' }
#                 $composerColor = if ($providerComposer -eq $audioComposer) { 'Green' } else { 'Yellow' }
#             } else {
#                 $artistColor = 'Gray'
#                 $genresColor = 'Gray'
#                 $composerColor = 'Gray'
#             }

#             Write-Host ("_`t{0:D2}.{1:D2}: {2}" -f $audio.DiscNumber, $audio.TrackNumber, $audio.Title) -ForegroundColor $color
#             Write-Host ("`t`tartist: {0}" -f ($audioArtist)) -ForegroundColor $artistColor
#             # Write the genres if present
#             if ($audioGenres) {
#                 Write-Host ("`t`tgenres: {0}" -f ($audioGenres)) -ForegroundColor $genresColor
#             }
#             Write-Host ("`t`tcomposer: {0}" -f ($audioComposer)) -ForegroundColor $composerColor
#             Write-Host "filename: $($audio.Name)"
#         } else {
#             Write-Host "_ No matching audio file" -ForegroundColor Red
#         }

#         Write-Host ""  # Add spacing between tracks
#     }
# }








<# function Show-Tracks {
    param (
        [array]$AudioFiles,
        [array]$SpotifyTracks,
        [string]$AlbumName,
        [object]$SpotifyArtist
    )

    #Clear-Host
    Write-Host "Tracks for album $($AlbumName):`n"

    for ($i = 0; $i -lt $SpotifyTracks.Count; $i++) {
        $num = $i + 1
        $spotify = $SpotifyTracks[$i]
        $audio = $AudioFiles[$i]

        Write-Host "[$num]"
        Write-Host ("↓`t{0:D2}.{1:D2}: {2}" -f $spotify.disc_number, $spotify.track_number, $spotify.name)
        # Artist: support multiple shapes (string, array of strings, array of objects with .name)
        $artistDisplay = ''
        # if ($spotify -and $spotify.PSObject.Properties.Match('Artist')) {
        #     $a = $spotify.Artist
        #     if ($a -is [System.Collections.IEnumerable] -and -not ($a -is [string])) { $artistDisplay = ($a -join ', ') } else { $artistDisplay = $a }
        # }
        if ($null -ne $spotify -and $spotify.PSObject.Properties['artists']) {
            $a = $spotify.artists
            if ($a -is [System.Collections.IEnumerable] -and -not ($a -is [string])) { $artistDisplay = ($a | ForEach-Object { if ($_.PSObject.Properties.Match('name')) { $_.name } else { $_ } }) -join ', ' } else { $artistDisplay = $a }
        }
        Write-Host ("`t`tartist: {0}" -f $artistDisplay)

        # Prefer track-level genres over artist-level (better for classical, MusicBrainz)
        $providerGenres = ''
        if ($null -ne $spotify -and $spotify.PSObject.Properties['genres'] -and $spotify.genres) {
            $providerGenres = $spotify.genres -join ', '
            Write-Host ("`t`tgenres: {0}" -f $providerGenres)
        }
        elseif ($null -ne $SpotifyArtist -and $SpotifyArtist.PSObject.Properties['genres'] -and $SpotifyArtist.genres -and $SpotifyArtist.genres.Count -gt 0) {
            $providerGenres = $SpotifyArtist.genres -join ', '
            Write-Host ("`t`tgenres: {0}" -f $providerGenres)
        }
        # if ($null -ne $spotify -and $spotify.artists -and $spotify.artists.Count -gt 0) {
        #     Write-Host ("`t`tartist: {0}" -f ($spotify.artists -join ', '))
        # }
        # write composer if present (handle single string or array)

        $providerComposer = ''        
        if ($null -ne $spotify -and $spotify.PSObject.Properties['composer'] -and $spotify.Composer) {
            $c = $spotify.Composer
            if ($c -is [System.Collections.IEnumerable] -and -not ($c -is [string])) { $providerComposer = ($c -join ', ') } else { $providerComposer = $c }
            Write-Host ("`t`tcomposer: {0}" -f $providerComposer)
        }
        
        $match = (
            $spotify.disc_number -eq $audio.DiscNumber -and
            $spotify.track_number -eq $audio.TrackNumber -and
            $spotify.name -eq $audio.Name
        )

        $color = if ($match) { 'Green' } else { 'Yellow' }

        # Prepare audio strings for comparison
        $audioArtist = $audio.TagFile.Tag.Performers -join ', '
        $audioGenres = if ($audio.TagFile.Tag.Genres) { $audio.TagFile.Tag.Genres -join ', ' } else { '' }
        $audioComposer = $audio.TagFile.Tag.Composers -join ', '

        # Determine colors for each field based on match
        $artistColor = if ($artistDisplay -eq $audioArtist) { 'Green' } else { 'Yellow' }
        $genresColor = if ($providerGenres -eq $audioGenres) { 'Green' } else { 'Yellow' }
        $composerColor = if ($providerComposer -eq $audioComposer) { 'Green' } else { 'Yellow' }


        Write-Host ("_`t{0:D2}.{1:D2}: {2}" -f $audio.DiscNumber, $audio.TrackNumber, $audio.Title) -ForegroundColor $color
        Write-Host ("`t`tartist: {0}" -f ($audioArtist)) -ForegroundColor $artistColor
        #write the genres if present
        if ($audioGenres) {
            Write-Host ("`t`tgenres: {0}" -f ($audioGenres)) -ForegroundColor $genresColor
        }
        Write-Host ("\t\tcomposer: {0}" -f ($audioComposer)) -ForegroundColor $composerColor
        Write-Host "filename: $(Split-Path -Leaf $audio.FilePath)"
    }
} #>
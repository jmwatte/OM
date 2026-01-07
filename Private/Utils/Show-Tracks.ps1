function Show-Tracks {
    param (
        [array]$PairedTracks,
        [string]$AlbumName,
        [PSCustomObject]$SpotifyArtist,
        [PSCustomObject]$ProviderAlbum,
        [switch]$Reverse,
        [string]$OptionsText,
        [string[]]$ValidCommands,
        [string]$PromptColor = 'Gray',
        [scriptblock]$InputReader,
        [object]$Context,
        [string]$ProviderName = 'Spotify',
        [string]$SortMethod = '',
        [switch]$Verbose
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

    # Ensure Show-Message helper is available when this file is dot-sourced in tests
    if (-not (Get-Command -Name Show-Message -ErrorAction SilentlyContinue)) {
        $candidates = @()
        if ($PSScriptRoot) { $candidates += Join-Path $PSScriptRoot 'Show-Message.ps1' }
        if ($MyInvocation.MyCommand.Path) { $candidates += Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'Show-Message.ps1' }
        $candidates += Join-Path (Get-Location) 'Private\Utils\Show-Message.ps1'
        foreach ($p in $candidates) {
            if (Test-Path $p) { . $p; break }
        }
    }

    # Ensure Invoke-SafeScriptBlock helper is available when this file is dot-sourced in tests
    if (-not (Get-Command -Name Invoke-SafeScriptBlock -ErrorAction SilentlyContinue)) {
        $candidates = @()
        if ($PSScriptRoot) { $candidates += Join-Path $PSScriptRoot 'Invoke-SafeScriptBlock.ps1' }
        if ($MyInvocation.MyCommand.Path) { $candidates += Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'Invoke-SafeScriptBlock.ps1' }
        $candidates += Join-Path (Get-Location) 'Private\Utils\Invoke-SafeScriptBlock.ps1'
        foreach ($p in $candidates) {
            if (Test-Path $p) { . $p; break }
        }
    }

    $pageSize = 10
    $page = 0
    $totalPages = if ($PairedTracks.Count -gt 0) { [math]::Ceiling($PairedTracks.Count / $pageSize) } else { 1 }

    while ($true) {
        if ($VerbosePreference -ne 'Continue') { Clear-Host }
        Show-Message -Message "Tracks for album $($AlbumName): (Page $($page + 1) of $totalPages)`n" -Context $Context
        
        # Show confidence summary if available
        if ($PairedTracks.Count -gt 0 -and $PairedTracks[0].PSObject.Properties['Confidence']) {
            $highCount = @($PairedTracks | Where-Object { $_.PSObject.Properties['ConfidenceLevel'] -and $_.ConfidenceLevel -eq 'High' }).Count
            $mediumCount = @($PairedTracks | Where-Object { $_.PSObject.Properties['ConfidenceLevel'] -and $_.ConfidenceLevel -eq 'Medium' }).Count
            $lowCount = @($PairedTracks | Where-Object { $_.PSObject.Properties['ConfidenceLevel'] -and $_.ConfidenceLevel -eq 'Low' }).Count
            $markedCount = @($PairedTracks | Where-Object { $_.PSObject.Properties['Marked'] -and $_.Marked }).Count
            
            $summary = ""
            if ($SortMethod) { $summary = "Sort: $SortMethod | " }
            $summary += "Match Confidence: "
            if ($highCount -gt 0) { $summary += "✅ $highCount High  " }
            if ($mediumCount -gt 0) { $summary += "⚠️ $mediumCount Medium  " }
            if ($lowCount -gt 0) { $summary += "❌ $lowCount Low  " }
            if ($markedCount -gt 0) { $summary += "🔖 $markedCount Marked  " }
            
            Show-Message -Message $summary -Context $Context
            Show-Message -Message "" -Context $Context
        }

        if ($PairedTracks.Count -eq 0) {
            Show-Message -Message "No tracks available for display." -Context $Context
            Show-Message -Message "`nPage 1 of 1 (Tracks 0 of 0)" -Context $Context
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
                
                # Add warning indicator for low confidence matches and marked indicator
                $warningIndicator = ""
                if ($pair.PSObject.Properties['ConfidenceLevel'] -and $pair.ConfidenceLevel -eq 'Low') {
                    $warningIndicator = " ⚠️"
                }
                
                $markedIndicator = if ($pair.PSObject.Properties['Marked'] -and $pair.Marked) { " 🔖" } else { "" }
                $trackNumColor = if ($pair.PSObject.Properties['Marked'] -and $pair.Marked) { 'Cyan' } else { 'DarkGray' }
                
                Show-Message -Message ("[$num]$markedIndicator $filenameDisplay$warningIndicator") -Context $Context

                $artistDisplay = 'Unknown'
                if ($spotify) {
                    $disc = if ($value = Get-IfExists $spotify 'disc_number') { $value } else { 1 }
                    $track = if ($value = Get-IfExists $spotify 'track_number') { $value } else { 0 }
                    
                    # Format duration from milliseconds
                    $durationMs = if ($value = Get-IfExists $spotify 'duration_ms') { $value } elseif ($value = Get-IfExists $spotify 'duration') { $value } else { 0 }
                    $durationSpan = [TimeSpan]::FromMilliseconds($durationMs)
                    $durationStr = "{0:mm\:ss}" -f $durationSpan
                    
                    Show-Message -Message ("↓`t{0:D2}.{1:D2}: {2} ({3})" -f $disc, $track, $spotify.name, $durationStr) -Context $Context

                    if ($Verbose) {
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
                        Show-Message -Message ("`t`tartist: {0}" -f $artistDisplay) -Context $Context

                        # Genre priority: track-level > album-level > artist-level
                        # Album-level is important for Discogs, Qobuz, MusicBrainz
                        if ($value = Get-IfExists $spotify 'genres') {
                            $providerGenres = $value -join ', '
                            Show-Message -Message ("`t`tgenres: {0}" -f $providerGenres) -Context $Context
                        }
                        elseif ($ProviderAlbum -and ($value = Get-IfExists $ProviderAlbum 'genres')) {
                            $providerGenres = $value -join ', '
                            Show-Message -Message ("`t`tgenres: {0}" -f $providerGenres) -Context $Context
                        }
                        elseif ($value = Get-IfExists $SpotifyArtist 'genres') {
                            $providerGenres = $value -join ', '
                            Show-Message -Message ("`t`tgenres: {0}" -f $providerGenres) -Context $Context
                        }

                        if ($value = Get-IfExists $spotify 'composer') {
                            if ($value -is [System.Collections.IEnumerable] -and -not ($value -is [string])) {
                                $providerComposer = $value -join ', '
                            }
                            else {
                                $providerComposer = $value
                            }
                            Show-Message -Message ("`t`tcomposer: {0}" -f $providerComposer) -Context $Context
                        }
                    }
                }
                else {
                    Show-Message -Message ("↓ No $ProviderName track data available") -Context $Context
                }

                if ($audio) {
                    $arrow = if ($Reverse) { '↑' } else { '_' }
                    
                    # Set color based on confidence level
                    $audioColor = if ($pair.PSObject.Properties['ConfidenceLevel']) {
                        switch ($pair.ConfidenceLevel) {
                            'High' { 'Green' }
                            'Medium' { 'Yellow' }
                            'Low' { 'Red' }
                            default { 'Yellow' }
                        }
                    } else {
                        # Fallback to old behavior if no confidence data
                        if ($spotify -and $audio.Title -eq $spotify.name) { 'Green' } else { 'Yellow' }
                    }
                    
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
                    
                    # Display audio track info with color based on match confidence
                    Show-Message -Message ("$arrow`t{0:D2}.{1:D2}: {2} ({3})" -f $audio.DiscNumber, $audio.TrackNumber, $audio.Title, $audioDurationStr) -ForegroundColor $audioColor -Context $Context

                    if ($Verbose) {
                        $audioArtist = if ($value = Get-IfExists $audio 'Artist') { $value } else { 'Unknown' }
                        $artistDisplay = 'Unknown'
                        if ($spotify) {
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
                        }
                        $artistColor = if ($spotify -and $audioArtist -eq $artistDisplay) { 'Green' } else { 'Yellow' }
                        Show-Message -Message (("`t`tartist: {0}" -f $audioArtist)) -ForegroundColor $artistColor -Context $Context

                        # Read genres from TagLib.Tag (uppercase T)
                        $audioGenresValue = if ($audio.TagFile -and $audio.TagFile.Tag -and $audio.TagFile.Tag.Genres) { $audio.TagFile.Tag.Genres } else { $null }
                        $audioGenres = if ($audioGenresValue) { $audioGenresValue -join ', ' } else { 'Unknown' }
                        $spotifyGenresValue = Get-IfExists $SpotifyArtist 'genres'
                        $genresColor = if ($spotifyGenresValue -and ($audioGenres -eq ($spotifyGenresValue -join ', '))) { 'Green' } else { 'Yellow' }
                        Show-Message -Message (("`t`tgenres: {0}" -f $audioGenres)) -ForegroundColor $genresColor -Context $Context

                        $audioComposerValue = Get-IfExists $audio 'Composer'
                        $audioComposer = if ($audioComposerValue) { if ($audioComposerValue -is [array]) { $audioComposerValue -join ', ' } else { $audioComposerValue } } else { 'Unknown' }
                        $spotifyComposerValue = Get-IfExists $spotify 'Composer'
                        $composerColor = if ($spotifyComposerValue -and ($audioComposer -eq ($spotifyComposerValue -join ', '))) { 'Green' } else { 'Yellow' }
                        Show-Message -Message (("`t`tcomposer: {0}" -f $audioComposer)) -ForegroundColor $composerColor -Context $Context

                        # Display additional classical music / detailed credits (if from Qobuz)
                        if ($spotifyConductor = Get-IfExists $spotify 'Conductor') {
                            Show-Message -Message (("`t`tconductor: {0}" -f $spotifyConductor)) -ForegroundColor Cyan -Context $Context
                        }
                        if ($spotifyEnsemble = Get-IfExists $spotify 'Ensemble') {
                            Show-Message -Message (("`t`tensemble: {0}" -f $spotifyEnsemble)) -ForegroundColor Cyan -Context $Context
                        }
                        if ($spotifyFeatured = Get-IfExists $spotify 'FeaturedArtist') {
                            Show-Message -Message (("`t`tfeatured: {0}" -f $spotifyFeatured)) -ForegroundColor Cyan -Context $Context
                        }
                        
                        # Display detailed role breakdown if available (Qobuz rich metadata)
                        if ($detailedRoles = Get-IfExists $spotify 'DetailedRoles') {
                            if ($detailedRoles -and $detailedRoles.Count -gt 0) {
                                Show-Message -Message "`t`t--- Production Credits ---" -ForegroundColor DarkCyan -Context $Context
                                foreach ($person in ($detailedRoles.Keys | Sort-Object)) {
                                    $roles = $detailedRoles[$person]
                                    Show-Message -Message (("`t`t{0}: {1}" -f $person, $roles)) -ForegroundColor DarkCyan -Context $Context
                                }
                            }
                        }
                    }

                    # Filename is now displayed in the header line above
                }
                else {
                    Show-Message -Message "_ No matching audio file" -ForegroundColor Red -Context $Context
                }

                Show-Message -Message "" -Context $Context
            }

            $lastIndex = [math]::Min($end + 1, $PairedTracks.Count)
            Show-Message -Message "`nPage $($page + 1) of $totalPages (Tracks $($start + 1) to $lastIndex of $($PairedTracks.Count))" -Context $Context
        }

        if ($supportsCommands -and $OptionsText) {
            Show-Message -Message $OptionsText -ForegroundColor $PromptColor -Context $Context
        }

        $promptMessage = if ($supportsCommands) { "Enter command (Enter=next, p=previous, q=tag tracks, m=mark tracks)" } else { "Press Enter for next page, 'p' for previous, 'q' to quit viewing" }

        # Invoke the input reader defensively: collect diagnostics for ParameterBindingException and try fallbacks
        # Invoke the input reader defensively using Invoke-SafeScriptBlock for robust fallbacks and diagnostics
        $inputRaw = Invoke-SafeScriptBlock -Block $reader -Args @($promptMessage) -ContextMsg 'Show-Tracks reader'

        $inputText = if ($null -ne $inputRaw) { $inputRaw.Trim() } else { '' }
        $inputLower = $inputText.ToLowerInvariant()

        if ($inputLower -eq '') {
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
        
        # Handle marking tracks for review
        if ($inputLower -eq 'm') {
            if ($PairedTracks.Count -eq 0) {
                Show-Message -Message "No tracks to mark." -ForegroundColor Yellow -Context $Context
                Start-Sleep -Seconds 1
                continue
            }

            $markPrompt = "Enter track numbers to mark (e.g., 12,19 or 21-26): "
            $markInput = Invoke-SafeScriptBlock -Block $reader -Args @($markPrompt) -ContextMsg 'Show-Tracks markPrompt'

            if ($markInput) {
                try {
                    $markedCount = Set-PairedTracks -PairedTracks $PairedTracks -RangeText $markInput -MaxIndex $PairedTracks.Count
                    Show-Message -Message "Marked $markedCount track(s)." -ForegroundColor Green -Context $Context
                    Start-Sleep -Seconds 1
                }
                catch {
                    Show-Message -Message "Error marking tracks: $($_.Exception.Message)" -ForegroundColor Red -Context $Context
                    Start-Sleep -Seconds 2
                }
            }
            continue
        }
        
        # Handle review marked tracks command - pass through to Start-OM
        if ($inputLower -eq 'rm') {
            if ($supportsCommands) { return 'rm' }
            Show-Message -Message "Review marked tracks command not available in this mode." -ForegroundColor Yellow -Context $Context
            Start-Sleep -Seconds 1
            continue
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

        Show-Message -Message ("Unrecognized input: '$inputText'.") -ForegroundColor Yellow -Context $Context
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

function Show-Tracks {
    param (
        [array]$PairedTracks,
        [string]$AlbumName,
        [PSCustomObject]$ProviderArtist,
        [PSCustomObject]$ProviderAlbum,
        [switch]$Reverse,
        [string]$OptionsText,
        [string[]]$ValidCommands,
        [string]$PromptColor = 'Gray',
        [scriptblock]$InputReader,
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

    $pageSize = 10
    $page = 0
    $totalPages = if ($PairedTracks.Count -gt 0) { [math]::Ceiling($PairedTracks.Count / $pageSize) } else { 1 }

    while ($true) {
        if ($VerbosePreference -ne 'Continue') { Clear-Host }
        Write-Host "Tracks for album $($AlbumName): (Page $($page + 1) of $totalPages)`n"
        
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
            
            Write-Host $summary -ForegroundColor $(if ($lowCount -gt 0) { 'Yellow' } elseif ($mediumCount -gt 0) { 'Cyan' } else { 'Green' })
            Write-Host ""
        }

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

                $spotify = $pair.ProviderTrack
                $audio = $pair.AudioFile

                $filenameDisplay = if ($audio) { "filename: $(Split-Path -Leaf $audio.FilePath)" } else { "" }
                
                # Add warning indicator for low confidence matches and marked indicator
                $warningIndicator = ""
                if ($pair.PSObject.Properties['ConfidenceLevel'] -and $pair.ConfidenceLevel -eq 'Low') {
                    $warningIndicator = " ⚠️"
                }
                
                $markedIndicator = if ($pair.PSObject.Properties['Marked'] -and $pair.Marked) { " 🔖" } else { "" }
                $trackNumColor = if ($pair.PSObject.Properties['Marked'] -and $pair.Marked) { 'Cyan' } else { 'DarkGray' }
                
                Write-Host "[$num]$markedIndicator $filenameDisplay$warningIndicator" -ForegroundColor $trackNumColor

                $artistDisplay = 'Unknown'
                if ($spotify) {
                    $disc = if ($value = Get-IfExists $spotify 'disc_number') { $value } else { 1 }
                    $track = if ($value = Get-IfExists $spotify 'track_number') { $value } else { 0 }
                    
                    # Format duration from milliseconds
                    $durationMs = if ($value = Get-IfExists $spotify 'duration_ms') { $value } elseif ($value = Get-IfExists $spotify 'duration') { $value } else { 0 }
                    $durationSpan = [TimeSpan]::FromMilliseconds($durationMs)
                    $durationStr = "{0:mm\:ss}" -f $durationSpan
                    
                    Write-Host ("↓`t{0:D2}.{1:D2}: {2} ({3})" -f $disc, $track, $spotify.name, $durationStr)

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
                        Write-Host ("`t`tartist: {0}" -f $artistDisplay)

                        # Genre priority: track-level > album-level > artist-level
                        # Album-level is important for Discogs, Qobuz, MusicBrainz
                        if ($value = Get-IfExists $spotify 'genres') {
                            $providerGenres = $value -join ', '
                            Write-Host ("`t`tgenres: {0}" -f $providerGenres)
                        }
                        elseif ($ProviderAlbum -and ($value = Get-IfExists $ProviderAlbum 'genres')) {
                            $providerGenres = $value -join ', '
                            Write-Host ("`t`tgenres: {0}" -f $providerGenres)
                        }
                        elseif ($value = Get-IfExists $ProviderArtist 'genres') {
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
                }
                else {
                    Write-Host "↓ No $ProviderName track data available"
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
                    
                    Write-Host ("$arrow`t{0:D2}.{1:D2}: {2} ({3})" -f $audio.DiscNumber, $audio.TrackNumber, $audio.Title, $audioDurationStr) -ForegroundColor $audioColor

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
                        Write-Host ("`t`tartist: {0}" -f $audioArtist) -ForegroundColor $artistColor

                        # Read genres from TagLib.Tag (uppercase T)
                        $audioGenresValue = if ($audio.TagFile -and $audio.TagFile.Tag -and $audio.TagFile.Tag.Genres) { $audio.TagFile.Tag.Genres } else { $null }
                        $audioGenres = if ($audioGenresValue) { $audioGenresValue -join ', ' } else { 'Unknown' }
                        $spotifyGenresValue = Get-IfExists $ProviderArtist 'genres'
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

        $promptMessage = if ($supportsCommands) { "Enter command (Enter=next, p=previous, q=tag tracks, m=mark tracks)" } else { "Press Enter for next page, 'p' for previous, 'q' to quit viewing" }
        $inputRaw = & $reader $promptMessage
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
                Write-Host "No tracks to mark." -ForegroundColor Yellow
                Start-Sleep -Seconds 1
                continue
            }
            
            $markPrompt = "Enter track numbers to mark (e.g., 12,19 or 21-26): "
            $markInput = & $reader $markPrompt
            
            if ($markInput) {
                try {
                    $trackNumbers = Expand-SelectionRange -RangeText $markInput -MaxIndex $PairedTracks.Count
                    foreach ($trackNum in $trackNumbers) {
                        $idx = $trackNum - 1
                        $PairedTracks[$idx] | Add-Member -NotePropertyName 'Marked' -NotePropertyValue $true -Force
                    }
                    Write-Host "Marked $($trackNumbers.Count) track(s)." -ForegroundColor Green
                    Start-Sleep -Seconds 1
                }
                catch {
                    Write-Host "Error marking tracks: $($_.Exception.Message)" -ForegroundColor Red
                    Start-Sleep -Seconds 2
                }
            }
            continue
        }
        
        # Handle review marked tracks command - pass through to Start-OM
        if ($inputLower -eq 'rm') {
            if ($supportsCommands) { return 'rm' }
            Write-Host "Review marked tracks command not available in this mode." -ForegroundColor Yellow
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

        Write-Host "Unrecognized input: '$inputText'." -ForegroundColor Yellow
        Start-Sleep -Seconds 1
    }
}


function Invoke-StageB-ReviewMarkedTracks {
    <#
    .SYNOPSIS
        Interactively review and rematch marked (or all) tracks.
    
    .DESCRIPTION
        Allows the user to review tracks marked for review and select different
        provider track matches. If no tracks are marked, all tracks are reviewed.
        
        Supports additional commands during review:
        - 's' to skip a track
        - 'x' to exit review mode
        - 'b' to go back to album selection
        - 'p <provider>' to switch provider
    
    .PARAMETER PairedTracks
        Array of paired track objects to review.
    
    .PARAMETER TracksForAlbum
        Array of provider tracks available for matching.
    
    .PARAMETER InputReader
        Optional scriptblock for reading user input. Defaults to Read-Host.
    
    .PARAMETER DisplayWriter
        Optional scriptblock for displaying messages. Defaults to Show-Message.
    
    .PARAMETER Context
        Optional context for Show-Message calls.
    
    .OUTPUTS
        PSCustomObject with properties:
        - Updated: Number of tracks that were rematched
        - Skipped: Number of tracks skipped by user
        - Reviewed: Total number of tracks reviewed
        - NoProviderTracks: True if no provider tracks were available
        - ExitRequested: True if user entered 'x' to exit
        - BackRequested: True if user entered 'b' to go back
        - ProviderSwitch: New provider name if user entered 'p <provider>', else null
    #>
    [CmdletBinding()]
    param(
        [array]$PairedTracks,
        [array]$TracksForAlbum,
        [Parameter(Mandatory=$false)][scriptblock]$InputReader,
        [Parameter(Mandatory=$false)][scriptblock]$DisplayWriter,
        $Context
    )

    $reader = if ($InputReader) { $InputReader } else { { param($prompt) Read-Host -Prompt $prompt } }

    # Ensure safe-invoke helper is available
    if (-not (Get-Command -Name Invoke-SafeScriptBlock -ErrorAction SilentlyContinue)) {
        $candidates = @()
        if ($PSScriptRoot) { $candidates += Join-Path $PSScriptRoot 'Invoke-SafeScriptBlock.ps1' }
        if ($MyInvocation.MyCommand.Path) { $candidates += Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'Invoke-SafeScriptBlock.ps1' }
        $candidates += Join-Path (Get-Location) 'Private\Utils\Invoke-SafeScriptBlock.ps1'
        foreach ($p in $candidates) { if (Test-Path $p) { . $p; break } }
    }

    # Determine writer: prefer explicit DisplayWriter, then Show-Message if available, else use Write-Verbose
    $display = if ($DisplayWriter) {
        $DisplayWriter
    } elseif (Get-Command -Name Show-Message -ErrorAction SilentlyContinue) {
        { param($msg,$color) Show-Message -Message $msg -ForegroundColor $color -Context $Context }
    } else {
        { param($msg,$color) if ($color) { Write-Verbose ("[{0}] {1}" -f $color, $msg) } else { Write-Verbose $msg } }
    }

    $result = [PSCustomObject]@{
        Updated          = 0
        Skipped          = 0
        Reviewed         = 0
        NoProviderTracks = $false
        ExitRequested    = $false
        BackRequested    = $false
        ProviderSwitch   = $null
    }

    $markedTracks = @($PairedTracks | Where-Object { $_.PSObject.Properties['Marked'] -and $_.Marked })

    $reviewAll = $false
    if ($markedTracks.Count -eq 0) {
        $reviewAll = $true
        $markedTracks = @($PairedTracks | Where-Object { $_.AudioFile })
        if ($markedTracks.Count -eq 0) {
            Invoke-SafeScriptBlock -Block $display -Args @("`nNo audio files to review.", "Yellow") -ContextMsg "ReviewMarkedTracks display no audio"
            Start-Sleep -Seconds 2
            $result.NoProviderTracks = $true
            return $result
        }
        Invoke-SafeScriptBlock -Block $display -Args @("`n📋 No marks set - reviewing ALL $($markedTracks.Count) track(s)...", "Cyan") -ContextMsg "ReviewMarkedTracks display no marks"
    }
    else {
        Invoke-SafeScriptBlock -Block $display -Args @("`n🔖 Reviewing $($markedTracks.Count) marked track(s)...", "Cyan") -ContextMsg "ReviewMarkedTracks display marks"
    }
    Start-Sleep -Seconds 1

    if ($reviewAll) {
        $providerTrackPool = @($TracksForAlbum)
    }
    else {
        $providerTrackPool = @($markedTracks | Where-Object { $_.SpotifyTrack } | ForEach-Object { $_.SpotifyTrack })
    }

    if ($providerTrackPool.Count -eq 0) {
        Invoke-SafeScriptBlock -Block $display -Args @("No provider tracks available to choose from.", "Yellow") -ContextMsg "ReviewMarkedTracks no provider tracks"
        Start-Sleep -Seconds 2
        $result.NoProviderTracks = $true
        return $result
    }

    foreach ($markedTrack in $markedTracks) {
        if (-not $markedTrack.AudioFile) { continue }
        if ($providerTrackPool.Count -eq 0) {
            Invoke-SafeScriptBlock -Block $display -Args @("No more provider tracks in pool.", "Yellow") -ContextMsg "ReviewMarkedTracks no more pool"
            break
        }

        if ($VerbosePreference -ne 'Continue') { Clear-Host }
        Invoke-SafeScriptBlock -Block $display -Args @("🔖 Select correct match for:", "Cyan") -ContextMsg "ReviewMarkedTracks select prompt"

        $audioDurationStr = if ($markedTrack.AudioFile.Duration) {
            $audioDurationSpan = [TimeSpan]::FromMilliseconds($markedTrack.AudioFile.Duration)
            "{0:mm\:ss}" -f $audioDurationSpan
        } else {
            "00:00"
        }

        Invoke-SafeScriptBlock -Block $display -Args @("   $(Split-Path -Leaf $markedTrack.AudioFile.FilePath) ($audioDurationStr)", "Yellow") -ContextMsg "ReviewMarkedTracks file line"
        Invoke-SafeScriptBlock -Block $display -Args @("", "") -ContextMsg "ReviewMarkedTracks spacer"

        # Score and sort pool
        $scoredPool = @()
        foreach ($track in $providerTrackPool) {
            $confidence = Get-MatchConfidence -ProviderTrack $track -AudioFile $markedTrack.AudioFile
            $scoredPool += [PSCustomObject]@{ Track = $track; Score = $confidence.Score; Level = $confidence.Level }
        }
        $scoredPool = $scoredPool | Sort-Object Score -Descending

        for ($i = 0; $i -lt $scoredPool.Count; $i++) {
            $scored = $scoredPool[$i]
            $track = $scored.Track
            $num = $i + 1
            $disc = if ($value = Get-IfExists $track 'disc_number') { $value } else { 1 }
            $trackNum = if ($value = Get-IfExists $track 'track_number') { $value } else { 0 }
            $durationMs = if ($value = Get-IfExists $track 'duration_ms') { $value } elseif ($value = Get-IfExists $track 'duration') { $value } else { 0 }
            $durationSpan = [TimeSpan]::FromMilliseconds($durationMs)
            $durationStr = "{0:mm\:ss}" -f $durationSpan
            $color = switch ($scored.Level) { 'High' { 'Green' } 'Medium' { 'Yellow' } 'Low' { 'Red' } default { 'Gray' } }
            $confidenceIndicator = " ($($scored.Score)%)"
            Invoke-SafeScriptBlock -Block $display -Args @(("[$num] {0:D2}.{1:D2}: {2} ({3}){4}" -f $disc, $trackNum, $track.name, $durationStr, $confidenceIndicator), $color) -ContextMsg "ReviewMarkedTracks pool line"
        }

        Invoke-SafeScriptBlock -Block $display -Args @("", "") -ContextMsg "ReviewMarkedTracks spacer after list"
        $selection = Invoke-SafeScriptBlock -Block $reader -Args @("Enter track number or press Enter for [1] (or 's' to skip)") -ContextMsg "ReviewMarkedTracks reader"
        if ([string]::IsNullOrWhiteSpace($selection)) { $selection = '1' }

        # Handle exit command
        if ($selection -eq 'x') {
            Invoke-SafeScriptBlock -Block $display -Args @("Exiting manual review...", "Yellow") -ContextMsg "ReviewMarkedTracks exit"
            $result.ExitRequested = $true
            break
        }

        # Handle back command
        if ($selection -eq 'b') {
            Invoke-SafeScriptBlock -Block $display -Args @("Going back to album selection...", "Yellow") -ContextMsg "ReviewMarkedTracks back"
            $result.BackRequested = $true
            break
        }

        # Handle provider switch command (supports both 'ps'/'pq'/'pd'/'pm' and 'p s'/'p q'/'p d'/'p m')
        if ($selection -match '^p\s*(.+)?$') {
            $providerArg = $matches[1]
            # Try contiguous form first (ps, pq, pd, pm) via Switch-OMProvider
            $newProvider = Switch-OMProvider -Input $selection -Context $Context -Silent
            if (-not $newProvider -and $providerArg) {
                # Fall back to space-separated form (p s, p q, etc.)
                $providerMap = @{ 's' = 'Spotify'; 'q' = 'Qobuz'; 'd' = 'Discogs'; 'm' = 'MusicBrainz' }
                if ($providerMap.ContainsKey($providerArg.ToLower())) {
                    $newProvider = $providerMap[$providerArg.ToLower()]
                }
                else {
                    $newProvider = $providerArg
                }
            }

            if ($newProvider) {
                $result.ProviderSwitch = $newProvider
                Invoke-SafeScriptBlock -Block $display -Args @("Switched to provider: $newProvider (will apply on next search)", "Green") -ContextMsg "ReviewMarkedTracks provider"
            }
            else {
                Invoke-SafeScriptBlock -Block $display -Args @("Usage: ps/pq/pd/pm or p <provider>", "Yellow") -ContextMsg "ReviewMarkedTracks provider usage"
            }
            Start-Sleep -Seconds 1
            continue
        }

        # Handle skip command
        if ($selection -eq 's') {
            Invoke-SafeScriptBlock -Block $display -Args @("Skipped", "Gray") -ContextMsg "ReviewMarkedTracks skipped"
            $result.Skipped++
            continue
        }

        # Handle numeric selection
        if ($selection -match '^[0-9]+$') {
            $selectedIndex = [int]$selection - 1
            if ($selectedIndex -ge 0 -and $selectedIndex -lt $scoredPool.Count) {
                $selectedTrack = $scoredPool[$selectedIndex].Track
                for ($i = 0; $i -lt $PairedTracks.Count; $i++) {
                    if ($PairedTracks[$i].AudioFile -and $PairedTracks[$i].AudioFile.FilePath -eq $markedTrack.AudioFile.FilePath) {
                        $PairedTracks[$i].SpotifyTrack = $selectedTrack
                        if ($PairedTracks[$i].PSObject.Properties['Marked']) { $PairedTracks[$i].Marked = $false }
                        Invoke-SafeScriptBlock -Block $display -Args @("✓ Updated", "Green") -ContextMsg "ReviewMarkedTracks updated"
                        $result.Updated++
                        break
                    }
                }

                # Remove selected track from pool
                $providerTrackPool = $providerTrackPool | Where-Object { $_ -ne $selectedTrack }
            }
        }
    }

    $result.Reviewed = $markedTracks.Count
    return $result
}

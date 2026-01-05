function Invoke-StageB-ReviewMarkedTracks {
    [CmdletBinding()]
    param(
        [array]$PairedTracks,
        [array]$TracksForAlbum,
        [Parameter(Mandatory=$false)][scriptblock]$InputReader
    )

    $reader = if ($InputReader) { $InputReader } else { { param($prompt) Read-Host -Prompt $prompt } }

    $result = [PSCustomObject]@{ Updated = 0; Skipped = 0; Reviewed = 0; NoProviderTracks = $false }

    $markedTracks = @($PairedTracks | Where-Object { $_.PSObject.Properties['Marked'] -and $_.Marked })

    $reviewAll = $false
    if ($markedTracks.Count -eq 0) {
        $reviewAll = $true
        $markedTracks = @($PairedTracks | Where-Object { $_.AudioFile })
        if ($markedTracks.Count -eq 0) {
            Write-Host "`nNo audio files to review." -ForegroundColor Yellow
            Start-Sleep -Seconds 2
            $result.NoProviderTracks = $true
            return $result
        }
        Write-Host "`n📋 No marks set - reviewing ALL $($markedTracks.Count) track(s)..." -ForegroundColor Cyan
    }
    else {
        Write-Host "`n🔖 Reviewing $($markedTracks.Count) marked track(s)..." -ForegroundColor Cyan
    }
    Start-Sleep -Seconds 1

    if ($reviewAll) {
        $providerTrackPool = @($TracksForAlbum)
    }
    else {
        $providerTrackPool = @($markedTracks | Where-Object { $_.SpotifyTrack } | ForEach-Object { $_.SpotifyTrack })
    }

    if ($providerTrackPool.Count -eq 0) {
        Write-Host "No provider tracks available to choose from." -ForegroundColor Yellow
        Start-Sleep -Seconds 2
        $result.NoProviderTracks = $true
        return $result
    }

    foreach ($markedTrack in $markedTracks) {
        if (-not $markedTrack.AudioFile) { continue }
        if ($providerTrackPool.Count -eq 0) {
            Write-Host "No more provider tracks in pool." -ForegroundColor Yellow
            break
        }

        if ($VerbosePreference -ne 'Continue') { Clear-Host }
        Write-Host "🔖 Select correct match for:" -ForegroundColor Cyan

        $audioDurationStr = if ($markedTrack.AudioFile.Duration) {
            $audioDurationSpan = [TimeSpan]::FromMilliseconds($markedTrack.AudioFile.Duration)
            "{0:mm\:ss}" -f $audioDurationSpan
        } else {
            "00:00"
        }

        Write-Host "   $(Split-Path -Leaf $markedTrack.AudioFile.FilePath) ($audioDurationStr)" -ForegroundColor Yellow
        Write-Host ""

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
            Write-Host ("[$num] {0:D2}.{1:D2}: {2} ({3}){4}" -f $disc, $trackNum, $track.name, $durationStr, $confidenceIndicator) -ForegroundColor $color
        }

        Write-Host ""
        $selection = & $reader "Enter track number or press Enter for [1] (or 's' to skip)"
        if ([string]::IsNullOrWhiteSpace($selection)) { $selection = '1' }

        if ($selection -eq 's') {
            Write-Host "Skipped" -ForegroundColor Gray
            $result.Skipped++
            continue
        }

        if ($selection -match '^[0-9]+$') {
            $selectedIndex = [int]$selection - 1
            if ($selectedIndex -ge 0 -and $selectedIndex -lt $scoredPool.Count) {
                $selectedTrack = $scoredPool[$selectedIndex].Track
                for ($i = 0; $i -lt $PairedTracks.Count; $i++) {
                    if ($PairedTracks[$i].AudioFile -and $PairedTracks[$i].AudioFile.FilePath -eq $markedTrack.AudioFile.FilePath) {
                        $PairedTracks[$i].SpotifyTrack = $selectedTrack
                        if ($PairedTracks[$i].PSObject.Properties['Marked']) { $PairedTracks[$i].Marked = $false }
                        Write-Host "✓ Updated" -ForegroundColor Green
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
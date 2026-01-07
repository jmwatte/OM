function Save-OMTrackSelection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$PairedTracks,

        [Parameter(Mandatory = $true)]
        [int[]]$SelectedIndices,

        [Parameter(Mandatory = $true)]
        $ProviderArtist,

        [Parameter(Mandatory = $true)]
        $ProviderAlbum,

        [Parameter(Mandatory = $true)]
        [bool]$UseWhatIf,

        [Parameter()]
        [scriptblock]$TagFactory,

        [Parameter()]
        [scriptblock]$TagSaver
    )

    if (-not $PairedTracks) {
        throw 'No track pairs are available for saving.'
    }

    if (-not $SelectedIndices -or $SelectedIndices.Count -eq 0) {
        throw 'No track numbers selected for saving.'
    }

    $maxIndex = $PairedTracks.Count
    foreach ($idx in $SelectedIndices) {
        if ($idx -lt 1 -or $idx -gt $maxIndex) {
            throw "Track number '$idx' is outside the valid range 1-$maxIndex."
        }
    }

    # Ensure safe-invoke helper is available
    if (-not (Get-Command -Name Invoke-SafeScriptBlock -ErrorAction SilentlyContinue)) {
        $candidates = @()
        if ($PSScriptRoot) { $candidates += Join-Path $PSScriptRoot 'Invoke-SafeScriptBlock.ps1' }
        if ($MyInvocation.MyCommand.Path) { $candidates += Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'Invoke-SafeScriptBlock.ps1' }
        $candidates += Join-Path (Get-Location) 'Private\Utils\Invoke-SafeScriptBlock.ps1'
        foreach ($p in $candidates) { if (Test-Path $p) { . $p; break } }
    }

    $TagFactory = if ($TagFactory) { $TagFactory } else { { param($artist, $album, $spotifyTrack) get-Tags -Artist $artist -Album $album -SpotifyTrack $spotifyTrack } }
    $TagSaver = if ($TagSaver) { $TagSaver } else { { param($filePath, $tags, $useWhatIf) Save-TagsForFile -FilePath $filePath -TagValues $tags -WhatIf:$useWhatIf } }

    $uniqueIndices = $SelectedIndices | Sort-Object -Unique

    $savedDetails = @()
    $skipped = @()
    $failed = @()

    foreach ($idx in $uniqueIndices) {
        $pair = $PairedTracks[$idx - 1]
        if (-not $pair) {
            $failed += [PSCustomObject]@{ Index = $idx; Reason = 'PairMissing' }
            continue
        }

        $audio = $pair.AudioFile
        $spotify = $pair.SpotifyTrack

        if (-not $audio) {
            $skipped += [PSCustomObject]@{ Index = $idx; Reason = 'NoAudio' }
            continue
        }

        try {
            $tags = Invoke-SafeScriptBlock -Block $TagFactory -Args @($ProviderArtist, $ProviderAlbum, $spotify) -ContextMsg "Save-OMTrackSelection TagFactory"
            $result = Invoke-SafeScriptBlock -Block $TagSaver -Args @($audio.FilePath, $tags, $UseWhatIf) -ContextMsg "Save-OMTrackSelection TagSaver"
            $success = $true
            $reason = $null
            if ($null -ne $result -and $result.PSObject.Properties.Match('Success')) {
                $success = [bool]$result.Success
                if ($result.PSObject.Properties.Match('Reason')) {
                    $reason = $result.Reason
                }
            }

            if ($success) {
                if (-not $UseWhatIf -and $audio.TagFile) {
                    try { $audio.TagFile.Dispose() } catch { Write-Verbose "Failed disposing TagFile for $($audio.FilePath): $_" }
                    $audio.TagFile = $null
                }

                $savedDetails += [PSCustomObject]@{
                    Index    = $idx
                    FilePath = $audio.FilePath
                    Tags     = $tags
                }
            }
            else {
                $failed += [PSCustomObject]@{
                    Index  = $idx
                    Reason = if ($reason) { $reason } else { 'SaveFailed' }
                }
            }
        }
        catch {
            $failed += [PSCustomObject]@{
                Index  = $idx
                Reason = $_.Exception.Message
            }
        }
    }

    $savedIndices = $savedDetails | ForEach-Object { $_.Index }

    $remainingPairs = @()
    for ($i = 0; $i -lt $PairedTracks.Count; $i++) {
        $pairIndex = $i + 1
        if ($savedIndices -contains $pairIndex) {
            continue
        }
        $remainingPairs += $PairedTracks[$i]
    }

    $remainingAudio = @()
    $remainingSpotify = @()
    foreach ($pair in $remainingPairs) {
        if ($pair.AudioFile) {
            $remainingAudio += $pair.AudioFile
        }
        if ($pair.SpotifyTrack) {
            $remainingSpotify += $pair.SpotifyTrack
        }
    }

    return [PSCustomObject]@{
        UpdatedPairs         = $remainingPairs
        UpdatedAudioFiles    = $remainingAudio
        UpdatedSpotifyTracks = $remainingSpotify
        SavedDetails         = $savedDetails
        Skipped              = $skipped
        Failed               = $failed
    }
}

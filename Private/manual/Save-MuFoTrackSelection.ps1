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
            $tags = & $TagFactory $ProviderArtist $ProviderAlbum $spotify
            $result = & $TagSaver $audio.FilePath $tags $UseWhatIf

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

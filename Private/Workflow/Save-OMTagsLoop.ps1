function Save-OMTagsLoop {
    <#
    .SYNOPSIS
        Iterates paired tracks, builds tags from provider metadata, and saves them to audio files.
    .DESCRIPTION
        Shared helper used by the 'st' (save tags) and 'sa' (save all) commands in Start-OM.
        Loops through each pair, builds tag parameters via Get-Tags, saves via Save-TagsForFile,
        and writes progress to the host.
    .PARAMETER PairedTracks
        Array of PSCustomObject pairs with AudioFile and ProviderTrack properties.
    .PARAMETER ProviderArtist
        The provider artist object.
    .PARAMETER ProviderAlbum
        The provider album object.
    .PARAMETER ManualAlbumArtist
        Optional manual album artist override. Coerced to string if array or other type.
    .PARAMETER GenreMode
        Genre handling mode ('Merge' enables genre merge in Save-TagsForFile).
    .PARAMETER UseWhatIf
        When set, passes -WhatIf to Save-TagsForFile for preview-only mode.
    .PARAMETER UpdateOnly
        Array of field categories to save. Defaults to 'All'.
        Passed to Get-FilteredTags to filter the tags hashtable before saving.
    .PARAMETER RequireBothPaired
        When set, skips pairs that lack either AudioFile or ProviderTrack (sa behavior).
        When not set, only AudioFile is required (st behavior).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$PairedTracks,

        [Parameter(Mandatory)]
        $ProviderArtist,

        [Parameter(Mandatory)]
        $ProviderAlbum,

        [Parameter()]
        $ManualAlbumArtist,

        [Parameter()]
        [string]$GenreMode,

        [Parameter()]
        [switch]$UseWhatIf,

        [Parameter()]
        [string[]]$UpdateOnly = @('All'),

        [Parameter()]
        [switch]$RequireBothPaired
    )

    # --- Pass 1: Build tags for all eligible tracks ---
    $trackEntries = @()

    foreach ($pair in $PairedTracks) {
        $hasAudio = $null -ne (Get-IfExists $pair 'AudioFile')
        $hasProvider = $null -ne (Get-IfExists $pair 'ProviderTrack')

        if ($RequireBothPaired) {
            if (-not $hasAudio -or -not $hasProvider) {
                if (-not $hasAudio -and $pair.ProviderTrack) {
                    Write-Verbose ("Skipping track '{0}' - no matching audio file" -f $pair.ProviderTrack.name)
                }
                if (-not $hasProvider -and $pair.AudioFile) {
                    Write-Verbose ("Skipping track '{0}' - no matching provider track" -f $pair.AudioFile.name)
                }
                continue
            }
        }
        else {
            if (-not $hasAudio) {
                if ($pair.ProviderTrack) {
                    Write-Verbose ("Skipping track '{0}' - no matching audio file" -f $pair.ProviderTrack.name)
                }
                continue
            }
        }

        $filePath = $pair.AudioFile.FilePath
        $tagsParams = @{
            Artist        = $ProviderArtist
            Album         = $ProviderAlbum
            ProviderTrack = $pair.ProviderTrack
        }

        if ($ManualAlbumArtist) {
            Write-Verbose "ManualAlbumArtist type: $($ManualAlbumArtist.GetType().FullName)"
            Write-Verbose "ManualAlbumArtist value: $($ManualAlbumArtist | Out-String)"

            $albumArtistString = if ($ManualAlbumArtist -is [string]) {
                $ManualAlbumArtist
            }
            elseif ($ManualAlbumArtist -is [array]) {
                $ManualAlbumArtist -join '; '
            }
            else {
                $ManualAlbumArtist.ToString()
            }
            $tagsParams['ManualAlbumArtist'] = $albumArtistString
        }

        $tags = Get-Tags @tagsParams

        # Filter tags based on UpdateOnly parameter
        $tags = Get-FilteredTags -Tags $tags -UpdateOnly $UpdateOnly

        if ($tags.Count -eq 0) {
            Write-Verbose "No tags to save for $filePath after filtering"
            continue
        }

        $trackEntries += [PSCustomObject]@{
            FilePath = $filePath
            Tags     = $tags
        }
    }

    # --- Normalize AlbumArtist across all tracks ---
    # AlbumArtist must be consistent for an album. If Get-Tags produced different
    # values per track (e.g. different soloists listed on different movements),
    # pick the most common value and apply it to every track.
    if ($trackEntries.Count -gt 1) {
        $albumArtistValues = @($trackEntries | Where-Object { $_.Tags.ContainsKey('AlbumArtist') } |
            ForEach-Object { $_.Tags['AlbumArtist'] })

        if ($albumArtistValues.Count -gt 0) {
            $uniqueValues = @($albumArtistValues | Select-Object -Unique)
            if ($uniqueValues.Count -gt 1) {
                # Pick the most frequent AlbumArtist value
                $consistentAA = ($albumArtistValues | Group-Object | Sort-Object Count -Descending | Select-Object -First 1).Name
                Write-Verbose "AlbumArtist inconsistency detected ($($uniqueValues.Count) distinct values). Normalizing all tracks to: $consistentAA"
                Write-Host "ℹ️  AlbumArtist normalized across $($trackEntries.Count) tracks: $consistentAA" -ForegroundColor Cyan
                foreach ($entry in $trackEntries) {
                    if ($entry.Tags.ContainsKey('AlbumArtist')) {
                        $entry.Tags['AlbumArtist'] = $consistentAA
                    }
                }
            }
        }
    }

    # --- Pass 2: Save tags ---
    foreach ($entry in $trackEntries) {
        $filePath = $entry.FilePath
        $tags = $entry.Tags

        Write-Verbose ("Saving tags to: {0}" -f $filePath)
        Write-Verbose ("Tag values:`n{0}" -f ($tags | Out-String))
        $genreMerge = ($GenreMode -eq 'Merge')
        $res = Save-TagsForFile -FilePath $filePath -TagValues $tags -WhatIf:$UseWhatIf -GenreMergeMode:$genreMerge
        if ($res.Success) {
            if ($UpdateOnly -contains 'All') {
                Write-Host ("Saved tags: {0} -> {1:D2}.{2:D2}: {3}" -f (Split-Path -Leaf $filePath), $tags.Disc, $tags.Track, $tags.Title) -ForegroundColor Green
            } else {
                $savedFields = $tags.Keys -join ', '
                Write-Host ("Saved [{0}]: {1}" -f $savedFields, (Split-Path -Leaf $filePath)) -ForegroundColor Green
            }
        }
        else {
            Write-Warning ("Skipped/Failed: {0} ({1})" -f $filePath, ($res.Reason -or 'unknown'))
        }
    }
}

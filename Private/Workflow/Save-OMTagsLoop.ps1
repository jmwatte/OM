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
        [switch]$RequireBothPaired
    )

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
        Write-Verbose ("Saving tags to: {0}" -f $filePath)
        Write-Verbose ("Tag values:`n{0}" -f ($tags | Out-String))
        $genreMerge = ($GenreMode -eq 'Merge')
        $res = Save-TagsForFile -FilePath $filePath -TagValues $tags -WhatIf:$UseWhatIf -GenreMergeMode:$genreMerge
        if ($res.Success) {
            Write-Host ("Saved tags: {0} -> {1:D2}.{2:D2}: {3}" -f (Split-Path -Leaf $filePath), $tags.Disc, $tags.Track, $tags.Title) -ForegroundColor Green
        }
        else {
            Write-Warning ("Skipped/Failed: {0} ({1})" -f $filePath, ($res.Reason -or 'unknown'))
        }
    }
}

function Save-CoverArtWithFallback {
    <#
    .SYNOPSIS
        Saves cover art with automatic provider fallback when the primary URL fails.

    .DESCRIPTION
        Attempts to download and save cover art from the primary provider's URL.
        If the download fails (e.g. 404) and AutoFallback is enabled, searches
        fallback providers for the same album and tries their cover art URLs.

    .PARAMETER CoverUrl
        Primary cover art URL to try first.

    .PARAMETER AlbumPath
        Path to the album folder where cover.jpg will be saved.

    .PARAMETER MaxSize
        Maximum dimension for the cover art image.

    .PARAMETER Provider
        The current/primary provider name.

    .PARAMETER AlbumName
        Album name for fallback searches.

    .PARAMETER ArtistName
        Artist name for fallback searches.

    .PARAMETER AutoFallback
        Whether to try fallback providers on failure.

    .PARAMETER WhatIf
        Preview mode - don't actually save.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter()]
        [string]$CoverUrl,

        [Parameter(Mandatory)]
        [string]$AlbumPath,

        [Parameter(Mandatory)]
        [int]$MaxSize,

        [Parameter(Mandatory)]
        [string]$Provider,

        [Parameter()]
        [string]$AlbumName,

        [Parameter()]
        [string]$ArtistName,

        [Parameter()]
        [switch]$AutoFallback,

        [Parameter()]
        [switch]$UseWhatIf
    )

    # Try the primary URL first (if we have one)
    if ($CoverUrl) {
        $coverResult = Save-CoverArt -CoverUrl $CoverUrl -AlbumPath $AlbumPath `
            -Action SaveToFolder -MaxSize $MaxSize -WhatIf:$UseWhatIf

        if ($coverResult.Success) {
            Write-Host "✓ Cover art saved" -ForegroundColor Green
            return $coverResult
        }
        Write-Host "⚠️  Cover art download failed from $Provider" -ForegroundColor Yellow
    }
    else {
        Write-Host "⚠️  No cover art URL from $Provider" -ForegroundColor Yellow
    }

    # Primary failed — try fallback providers if enabled
    if (-not $AutoFallback -or -not $AlbumName -or -not $ArtistName) {
        $errorMsg = if ($coverResult) { $coverResult.Error } else { "No cover art URL available" }
        Write-Warning "Failed to save cover art: $errorMsg"
        return [PSCustomObject]@{ Success = $false; Error = $errorMsg }
    }

    Write-Host "   Trying fallback providers..." -ForegroundColor Cyan

    $fallbackChain = switch ($Provider) {
        'Qobuz' { @('Spotify', 'Discogs', 'MusicBrainz') }
        'Spotify' { @('Qobuz', 'Discogs', 'MusicBrainz') }
        'Discogs' { @('Qobuz', 'Spotify', 'MusicBrainz') }
        'MusicBrainz' { @('Qobuz', 'Spotify', 'Discogs') }
    }

    foreach ($fbProvider in $fallbackChain) {
        Write-Host "   Trying $fbProvider cover art..." -ForegroundColor Cyan

        try {
            $fbResults = Invoke-ProviderSearch -Provider $fbProvider -Album $AlbumName -Artist $ArtistName -Type album
            $fbCandidates = @()
            if ($fbResults) {
                $fbAlbums = Get-IfExists $fbResults 'albums'
                if ($fbAlbums) {
                    $fbItems = Get-IfExists $fbAlbums 'items'
                    if ($fbItems) {
                        $fbCandidates = @($fbItems | Where-Object { $_ -ne $null })
                    }
                }
            }

            if ($fbCandidates.Count -eq 0) {
                Write-Verbose "No results from $fbProvider"
                continue
            }

            # Pick the best match
            $fbMatch = Get-BestAutoMatch -Candidates $fbCandidates `
                -LocalArtist $ArtistName -LocalAlbum $AlbumName `
                -LocalTrackCount 0 -Threshold 0.5

            $fbAlbum = if ($fbMatch) { $fbMatch.Album } else { $fbCandidates[0] }
            $fbCoverUrl = Get-IfExists $fbAlbum 'cover_url'

            if (-not $fbCoverUrl) {
                Write-Verbose "No cover URL from $fbProvider match"
                continue
            }

            $fbResult = Save-CoverArt -CoverUrl $fbCoverUrl -AlbumPath $AlbumPath `
                -Action SaveToFolder -MaxSize $MaxSize -WhatIf:$UseWhatIf

            if ($fbResult.Success) {
                Write-Host "   ✓ Cover art saved from $fbProvider" -ForegroundColor Green
                return $fbResult
            }
            else {
                Write-Verbose "Cover art from $fbProvider also failed: $($fbResult.Error)"
            }
        }
        catch {
            Write-Verbose "Fallback cover art search on $fbProvider failed: $_"
        }
    }

    Write-Warning "Failed to save cover art from all providers"
    return [PSCustomObject]@{ Success = $false; Error = "All providers failed" }
}

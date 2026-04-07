function Get-AllProviderGenres {
    <#
    .SYNOPSIS
        Collects genres from all providers for a given album, returning per-provider and merged results.

    .DESCRIPTION
        Searches every supported provider (Spotify, Qobuz, Discogs, MusicBrainz) for the
        specified album, extracts genres from each match, and returns both the per-provider
        breakdown and a deduplicated merged list.

        Unlike Get-GenresWithFallback which stops at the first provider that has genres,
        this function queries ALL providers and combines the results.

    .PARAMETER ArtistName
        The artist name to search for.

    .PARAMETER AlbumName
        The album name to search for.

    .PARAMETER TrackCount
        Expected track count for match confidence scoring.

    .PARAMETER Threshold
        Minimum confidence threshold for album matching (default 0.35).

    .OUTPUTS
        Hashtable with:
        - ByProvider: ordered hashtable mapping provider name to genre array
        - Merged: deduplicated array of all genres across providers
        Returns $null if no genres found on any provider.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ArtistName,

        [Parameter(Mandatory)]
        [string]$AlbumName,

        [Parameter()]
        [int]$TrackCount = 0,

        [Parameter()]
        [double]$Threshold = 0.35
    )

    $allProviders = @('Spotify', 'Qobuz', 'Discogs', 'MusicBrainz')
    $collectedGenres = [ordered]@{}

    foreach ($provider in $allProviders) {
        Write-Host "   🔍 Querying $provider for genres..." -ForegroundColor Cyan

        try {
            $results = Invoke-ProviderSearch -Provider $provider -Album $AlbumName -Artist $ArtistName -Type album -ErrorAction Stop
            $candidates = @()
            if ($results) {
                $albums = Get-IfExists $results 'albums'
                if ($albums) {
                    $items = Get-IfExists $albums 'items'
                    if ($items) {
                        $candidates = @($items | Where-Object { $_ -ne $null })
                    }
                }
            }
        }
        catch {
            Write-Verbose "Get-AllProviderGenres: $provider search failed: $_"
            continue
        }

        if (@($candidates).Count -eq 0) { continue }

        $bestMatch = Get-BestAutoMatch -Candidates $candidates `
            -LocalArtist $ArtistName -LocalAlbum $AlbumName `
            -LocalTrackCount $TrackCount -Threshold $Threshold

        if (-not $bestMatch) { continue }

        $fbAlbum = $bestMatch.Album

        # Extract genres from the matched album (genres → genre → styles)
        $genres = @()
        $albumGenres = Get-IfExists $fbAlbum 'genres'
        $albumGenre  = Get-IfExists $fbAlbum 'genre'
        $albumStyles = Get-IfExists $fbAlbum 'styles'

        if ($albumGenres -and @($albumGenres).Count -gt 0) {
            $genres = @($albumGenres | Where-Object { $_ -and $_ -ne '' })
        }
        elseif ($albumGenre -and @($albumGenre).Count -gt 0) {
            $genres = @($albumGenre | Where-Object { $_ -and $_ -ne '' })
        }
        elseif ($albumStyles -and @($albumStyles).Count -gt 0) {
            $genres = @($albumStyles | Where-Object { $_ -and $_ -ne '' })
        }

        # If album has no genres, try the artist (Spotify provides artist-level genres)
        if (@($genres).Count -eq 0 -and $provider -eq 'Spotify') {
            $fbArtists = Get-IfExists $fbAlbum 'artists'
            if ($fbArtists -and @($fbArtists).Count -gt 0) {
                $artistId = $fbArtists[0].id
                if ($artistId) {
                    try {
                        $fbArtist = Invoke-ProviderGetArtist -Provider $provider -ArtistId $artistId
                        if ($fbArtist) {
                            $artistGenres = Get-IfExists $fbArtist 'genres'
                            if ($artistGenres) {
                                $genres = @($artistGenres | Where-Object { $_ -and $_ -ne '' })
                            }
                        }
                    }
                    catch {
                        Write-Verbose "Get-AllProviderGenres: Failed to fetch Spotify artist genres: $_"
                    }
                }
            }
        }

        # Normalize: trim, decode HTML entities
        $genres = @($genres | ForEach-Object {
            [System.Net.WebUtility]::HtmlDecode($_.ToString().Trim())
        })

        if (@($genres).Count -gt 0) {
            Write-Host "   ✓ $provider`: $($genres -join ', ')" -ForegroundColor Green
            $collectedGenres[$provider] = $genres
        }
    }

    if ($collectedGenres.Count -eq 0) {
        Write-Verbose "Get-AllProviderGenres: no genres found on any provider"
        return $null
    }

    # Merge all genres, deduplicated (case-insensitive)
    $seen = @{}
    $merged = @()
    foreach ($providerGenres in $collectedGenres.Values) {
        foreach ($g in $providerGenres) {
            $key = $g.ToLowerInvariant()
            if (-not $seen.ContainsKey($key)) {
                $seen[$key] = $true
                $merged += $g
            }
        }
    }

    $providerList = ($collectedGenres.Keys -join ', ')
    Write-Host "   🎵 Merged genres from $providerList`: $($merged -join ', ')" -ForegroundColor Magenta

    return @{
        ByProvider = $collectedGenres
        Merged     = $merged
    }
}

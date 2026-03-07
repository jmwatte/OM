function Get-GenresWithFallback {
    <#
    .SYNOPSIS
        Attempts to get genres from fallback providers when the primary provider returns none.

    .DESCRIPTION
        Searches fallback providers for the same album/artist, fetches artist details where
        available, and extracts genres. Returns the first provider that has genres.

    .PARAMETER PrimaryProvider
        The provider that was already tried (will be skipped in the fallback chain).

    .PARAMETER ArtistName
        The artist name to search for.

    .PARAMETER AlbumName
        The album name to search for.

    .PARAMETER TrackCount
        Expected track count for match confidence scoring.

    .PARAMETER Threshold
        Minimum confidence threshold for album matching.

    .OUTPUTS
        Hashtable with Provider, Album, Artist, Genres keys — or $null if no genres found.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PrimaryProvider,

        [Parameter(Mandatory)]
        [string]$ArtistName,

        [Parameter(Mandatory)]
        [string]$AlbumName,

        [Parameter()]
        [int]$TrackCount = 0,

        [Parameter()]
        [double]$Threshold = 0.35
    )

    $fallbackChain = switch ($PrimaryProvider) {
        'Qobuz'       { @('Spotify', 'Discogs', 'MusicBrainz') }
        'Spotify'     { @('Qobuz', 'Discogs', 'MusicBrainz') }
        'Discogs'     { @('Qobuz', 'Spotify', 'MusicBrainz') }
        'MusicBrainz' { @('Qobuz', 'Spotify', 'Discogs') }
    }

    foreach ($fbProvider in $fallbackChain) {
        Write-Host "   🔍 Trying $fbProvider for genres..." -ForegroundColor Cyan

        try {
            $fbResults = Invoke-ProviderSearch -Provider $fbProvider -Album $AlbumName -Artist $ArtistName -Type album -ErrorAction Stop
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
        }
        catch {
            Write-Verbose "Genre fallback: $fbProvider search failed: $_"
            continue
        }

        if (@($fbCandidates).Count -eq 0) { continue }

        $bestMatch = Get-BestAutoMatch -Candidates $fbCandidates `
            -LocalArtist $ArtistName -LocalAlbum $AlbumName `
            -LocalTrackCount $TrackCount -Threshold $Threshold

        if (-not $bestMatch) { continue }

        $fbAlbum = $bestMatch.Album

        # Extract genres from album
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
        $genres = @($genres)  # Ensure array even if Where-Object returned $null

        # If album has no genres, try the artist
        $fbArtist = $null
        if (@($genres).Count -eq 0) {
            if ($fbProvider -eq 'Spotify') {
                $fbArtists = Get-IfExists $fbAlbum 'artists'
                if ($fbArtists -and @($fbArtists).Count -gt 0) {
                    $artistId = $fbArtists[0].id
                    if ($artistId) {
                        $fbArtist = Invoke-ProviderGetArtist -Provider $fbProvider -ArtistId $artistId
                    }
                }
            }
            if ($fbArtist) {
                $artistGenres = Get-IfExists $fbArtist 'genres'
                if ($artistGenres) { $genres = @($artistGenres | Where-Object { $_ -and $_ -ne '' }) }
                $genres = @($genres)
            }
        }

        if (@($genres).Count -gt 0) {
            Write-Host "   ✓ Found genres on $fbProvider`: $($genres -join ', ')" -ForegroundColor Green
            return @{
                Provider = $fbProvider
                Album    = $fbAlbum
                Artist   = $fbArtist
                Genres   = $genres
            }
        }
    }

    Write-Verbose "Genre fallback: no genres found on any provider"
    return $null
}

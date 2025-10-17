function Invoke-ProviderSearchAlbums {
    <#
    .SYNOPSIS
        Provider abstraction for searching albums by name.
    
    .DESCRIPTION
        Routes album search requests to the appropriate provider-specific function.
        Searches for albums matching both artist and album name instead of returning
        full artist discography.
    
    .PARAMETER Provider
        The metadata provider to use (Spotify, Qobuz, or Discogs).
    
    .PARAMETER ArtistId
        Provider-specific artist identifier.
    
    .PARAMETER ArtistName
        The artist name to search for.
    
    .PARAMETER AlbumName
        The album name to search for.
    
    .PARAMETER MastersOnly
        (Discogs only) If specified, only return master releases.
    
    .PARAMETER AllAlbumsCache
        (Optional) Pre-fetched albums to search through instead of fetching from provider.
        Used to optimize repeated searches without re-fetching.
    
    .EXAMPLE
        Invoke-ProviderSearchAlbums -Provider Spotify -ArtistName "Pink Floyd" -AlbumName "Dark Side"
        Searches Spotify for albums matching "Pink Floyd" and "Dark Side".
    
    .EXAMPLE
        Invoke-ProviderSearchAlbums -Provider Discogs -ArtistName "Fats Waller" -AlbumName "Handful of Keys" -MastersOnly
        Searches Discogs for master releases matching "Fats Waller" and "Handful of Keys".
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Spotify', 'Qobuz', 'Discogs', 'MusicBrainz')]
        [string]$Provider,

        [Parameter()]
        [string]$ArtistId,

        [Parameter(Mandatory)]
        [string]$ArtistName,

        [Parameter(Mandatory)]
        [string]$AlbumName,

        [Parameter()]
        [switch]$MastersOnly,  # Discogs-specific

        [Parameter()]
        [array]$AllAlbumsCache  # Pre-fetched albums for cache-based filtering
    )

    Write-Verbose "Searching $Provider for albums: Artist='$ArtistName', Album='$AlbumName'"

    switch ($Provider) {
        'Spotify' {
            $results = Search-SAlbumsByName -ArtistName $ArtistName -AlbumName $AlbumName -ArtistId $ArtistId
            @($results)
        }
        'Qobuz' {
            if (-not $ArtistId) {
                Write-Warning "Qobuz album search requires ArtistId (artist URL)"
                return @()
            }
            $results = Search-QAlbumsByName -ArtistId $ArtistId -AlbumName $AlbumName -ArtistName $ArtistName
            @($results)
        }
        'Discogs' {
            $searchParams = @{
                ArtistName = $ArtistName
                AlbumName = $AlbumName
            }
            if ($ArtistId) {
                $searchParams.ArtistId = $ArtistId
            }
            if ($MastersOnly) {
                $searchParams.MastersOnly = $true
            }
            if ($AllAlbumsCache) {
                $searchParams.AllAlbumsCache = $AllAlbumsCache
            }
            $results = Search-DAlbumsByName @searchParams
            @($results)
        }
        'MusicBrainz' {
            # MusicBrainz: If we have cached albums, filter them locally
            # Otherwise fetch all albums and filter (no direct album name search API)
            # Normalize cache to array before checking Count
            $cache = @($AllAlbumsCache)
            if ($cache -and $cache.Count -gt 0) {
                Write-Verbose "Filtering $($cache.Count) cached albums for: $AlbumName"
                $cache | Where-Object { $_.title -like "*$AlbumName*" -or $_.name -like "*$AlbumName*" }
            } else {
                Write-Verbose "No cache provided, fetching all albums and filtering for: $AlbumName"
                $allAlbums = Get-MBArtistAlbums -ArtistId $ArtistId
                @($allAlbums) | Where-Object { $_.title -like "*$AlbumName*" -or $_.name -like "*$AlbumName*" }
            }
        }
    }
}

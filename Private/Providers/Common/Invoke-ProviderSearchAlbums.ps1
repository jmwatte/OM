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
        [array]$AllAlbumsCache,  # Pre-fetched albums for cache-based filtering

        [Parameter()]
        [int]$Page = 1,

        [Parameter()]
        [ValidateRange(1, 100)]
        [int]$PerPage = 10,

        [Parameter()]
        [int]$MaxResults = 10
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
            
            $results = Search-QAlbum -ArtistName $ArtistName -AlbumName $AlbumName
            #$results = Search-QAlbumsByName -ArtistId $ArtistId -AlbumName $AlbumName -ArtistName $ArtistName
            @($results)
        }
        'Discogs' {
            $searchParams = @{
                ArtistName = $ArtistName
                AlbumName  = $AlbumName
                Page       = $Page
                PerPage    = $PerPage
                MaxResults = $MaxResults
            }
            if ($ArtistId) {
                $searchParams.ArtistId = $ArtistId
            }
            if ($MastersOnly) {
                $searchParams.MastersOnly = "Masters"
            }
            if ($AllAlbumsCache) {
                $searchParams.AllAlbumsCache = $AllAlbumsCache
            }
            #  $searchParams.AlbumName='Album'
            # $results=Get-DArtistAlbums @searchParams
            $results = Search-DAlbumsByName @searchParams
            #is this rewritable with get-ifexists

            if ($null -eq $results -or $results.Count -eq 0 ) {
                $searchParams.MastersOnly = 'Release'
                $results = Search-DAlbumsByName @searchParams

            }
            if ( $null -eq $results -or $results.Count -eq 0 ) {
                $searchParams.MastersOnly = 'All'
                $results = Search-DAlbumsByName @searchParams

            }

            @($results)
        }
        'MusicBrainz' {
            # Use release-group search to find canonical albums, avoiding duplicate editions
            if (-not $ArtistId) {
                Write-Warning "MusicBrainz album search requires ArtistId (MBID)"
                return @()
            }
            
            Write-Verbose "Searching MusicBrainz release-groups: ArtistId='$ArtistId', Album='$AlbumName'"
            $query = "releasegroup:""$AlbumName"" AND arid:$ArtistId"

            try {
                $response = Invoke-MusicBrainzRequest -Endpoint 'release-group' -Query @{ query = $query; limit = 100 }
                
                if (-not $response -or -not (Get-IfExists $response 'release-groups')) {
                    Write-Verbose "No release-groups found for query: $query"
                    return @()
                }
                
                $releaseGroups = $response.'release-groups'
                Write-Verbose "Found $($releaseGroups.Count) release-groups matching query"
                
                # Normalize to consistent format, fetching track count from one release per group
                $normalizedReleaseGroups = foreach ($rg in $releaseGroups) {
                    $track_count = 0
                    
                    try {
                        # Fetch one release for this release-group to get track count
                        $relResponse = Invoke-MusicBrainzRequest -Endpoint 'release' -Query @{ 'release-group' = $rg.id; inc = 'media' }
                        
                        if ($relResponse -and (Get-IfExists $relResponse 'releases') -and $relResponse.releases.Count -gt 0) {
                            foreach ($release in $relResponse.releases) {
                                # Calculate track count from media
                                $track_count = 0
                                if (Get-IfExists $release 'media') {
                                    $track_count = ($release.media | ForEach-Object { 
                                            if (Get-IfExists $_ 'track-count') { [int]$_.'track-count' } 
                                            else { 0 } 
                                        } | Measure-Object -Sum).Sum
                                }
                                
                                # Get genre from release-group tags
                                $genre = if (Get-IfExists $rg 'tags') {
                                    ($rg.tags | ForEach-Object { $_.name }) -join ', '
                                }
                                else { $null }
                                
                                # Get artist from artist-credits, fallback to passed ArtistName
                                $artist = if (Get-IfExists $release 'artist-credit') {
                                    ($release.'artist-credit' | ForEach-Object { $_.name }) -join ', '
                                }
                                else { $ArtistName }
                                
                                # Get release date from release.date
                                $release_date = if (Get-IfExists $release 'date') { $release.date } else { "0000" }
                                
                                [PSCustomObject]@{
                                    id           = $release.id
                                    name         = $release.title
                                    title        = $release.title
                                    genre        = $genre
                                    artist       = $artist
                                    track_count  = $track_count
                                    release_date = $release_date
                                }
                            }
                        }
                    }
                    catch {
                        Write-Verbose "Failed to get track count for release-group $($rg.id): $_"
                    }
                    
                    # [PSCustomObject]@{
                    #     id           = $rg.id
                    #     name         = $rg.title
                    #     title        = $rg.title  # Keep original title for filtering
                    #     release_date = if (Get-IfExists $rg 'first-release-date') { $rg.'first-release-date' } else { $null }
                    #     track_count  = $track_count
                    # }
                }
                
                # Sort by first-release-date (newest first), then by title
                $normalizedReleaseGroups | Sort-Object -Property @{Expression = { 
                        if ($_.release_date) { 
                            try { [DateTime]::Parse($_.release_date) } catch { [DateTime]::MinValue } 
                        }
                        else { 
                            [DateTime]::MinValue 
                        } 
                    }; Descending                                             = $true
                }, title
            }
            catch {
                Write-Warning "MusicBrainz release-group search failed: $_"
                return @()
            }
        }
    }
}
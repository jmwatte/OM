function Search-DAlbumsByName {
    <#
    .SYNOPSIS
        Search Discogs for albums by artist and album name.
    
    .DESCRIPTION
        Uses Discogs /database/search API with title and artist parameters to find matching albums.
        Supports pagination and can be interrupted during processing.
        Falls back to cache-based filtering if API search fails or cache is provided.
    
    .PARAMETER ArtistName
        The artist name to search for.
    
    .PARAMETER AlbumName
        The album name to search for.
    
    .PARAMETER ArtistId
        Discogs artist ID (optional, used for cache-based fallback).
    
    .PARAMETER MastersOnly
        If specified, only return master releases (canonical album versions).
    
    .PARAMETER AllAlbumsCache
        Optional: Pre-fetched list of all albums. If provided, skips API search and filters locally.
    
    .PARAMETER Page
        Page number for pagination (default: 1).
    
    .PARAMETER PerPage
        Number of results per page (default: 10, max: 100).
    
    .PARAMETER MaxResults
        Maximum number of albums to process with track counts (default: 10). Press 'Q' to stop early.
    
    .EXAMPLE
        Search-DAlbumsByName -ArtistName "Fats Waller" -AlbumName "Complete Recorded Works"
        Searches Discogs API for albums matching the title.
    
    .EXAMPLE
        Search-DAlbumsByName -ArtistName "Fats Waller" -AlbumName "Keys" -AllAlbumsCache $cached
        Filters pre-cached albums locally (no API call).
    
    .EXAMPLE
        Search-DAlbumsByName -ArtistName "The Beatles" -AlbumName "Help" -Page 2 -PerPage 20
        Gets page 2 with 20 results per page.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ArtistName,

        [Parameter(Mandatory)]
        [string]$AlbumName,

        [Parameter()]
        [string]$ArtistId,

        [Parameter()]
        [ValidateSet('Masters', 'Release', 'All')]
        [string]$MastersOnly = 'Release',

        [Parameter()]
        [array]$AllAlbumsCache,

        [Parameter()]
        [int]$Page = 1,

        [Parameter()]
        [ValidateRange(1, 100)]
        [int]$PerPage = 10,

        [Parameter()]
        [int]$MaxResults = 10
    )

    Write-Verbose "Searching Discogs for artist '$ArtistName' albums matching '$AlbumName' (Page: $Page, PerPage: $PerPage, MaxResults: $MaxResults)"
    Write-Debug "Search-DAlbumsByName called: Artist='$ArtistName', Album='$AlbumName', MastersOnly=$MastersOnly, CacheProvided=$($null -ne $AllAlbumsCache), Page=$Page, PerPage=$PerPage, MaxResults=$MaxResults"

    # If cache provided, use cache-based filtering (fast, no API calls)
    if ($AllAlbumsCache) {
        Write-Debug "Using cache path"
        Write-Verbose "Using cached album list ($($AllAlbumsCache.Count) albums)"
        $allAlbums = $AllAlbumsCache
        
        # Filter albums by name using case-insensitive matching
        $filtered = @($allAlbums | Where-Object { 
                $_.name -like "*$AlbumName*" 
            })

        # If no direct matches, try fuzzy matching with Jaccard similarity
        if ($filtered.Count -eq 0 -and (Get-Command Get-StringSimilarity-Jaccard -ErrorAction SilentlyContinue)) {
            Write-Verbose "No direct matches, trying fuzzy matching with Jaccard similarity"
            $filtered = @($allAlbums | ForEach-Object {
                    $similarity = Get-StringSimilarity-Jaccard -String1 $AlbumName -String2 $_.name
                    if ($similarity -gt 0.3) {
                        $_ | Add-Member -NotePropertyName '_similarity' -NotePropertyValue $similarity -Force -PassThru
                    }
                } | Sort-Object { - $_._similarity })
        }

        Write-Verbose "Found $($filtered.Count) matching albums from cache"
        return $filtered
    }

    # No cache - use Discogs API search
    Write-Debug "Using API search path"
    Write-Verbose "Searching Discogs API with title='$AlbumName' and artist='$ArtistName'"
    
    try {

        # Build search parameters with pagination
        $searchParams = @{
            page     = $Page
            per_page = $PerPage
        }

        # Add search-specific parameters based on MastersOnly
        switch ($MastersOnly) {
            'Masters' {
                $searchParams['artist'] = $ArtistName
                $searchParams['title']  = $AlbumName
                $searchParams['type']   = 'master'
            }
            'Release' {
                $searchParams['artist'] = $ArtistName
                $searchParams['title']  = $AlbumName
                $searchParams['type']   = 'release'
            }
            'All' {
                $searchParams['q']    = "$AlbumName $ArtistName"
                $searchParams['type'] = 'release'
            }
        }
        $queryString = ($searchParams.GetEnumerator() | ForEach-Object {
                [System.Web.HttpUtility]::UrlEncode($_.Key) + '=' + [System.Web.HttpUtility]::UrlEncode($_.Value)
            }) -join '&'
        $uri = "https://api.discogs.com/database/search?$queryString" 
        Write-Debug "Calling Invoke-DiscogsRequest with pagination..."
        $searchResult = Invoke-DiscogsRequest -Uri $uri -Method GET
        Write-Debug "API call completed, processing results..."
        
        if (-not $searchResult.results -or $searchResult.results.Count -eq 0) {
            Write-Verbose "No albums found via API search"
            return @()
        }
        
        Write-Verbose "Found $($searchResult.results.Count) albums via API search (page $Page of $($searchResult.pagination.pages) total)"
        Write-Verbose "Processing up to $MaxResults albums with track counts..."
        
        # Convert Discogs search results to album objects (Spotify-compatible format)
        $albums = @()
        $processed = 0
        $totalResults = $searchResult.results.Count
        
        foreach ($result in $searchResult.results) {
            try {
            # Check for user interruption
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true)
                if ($key.Key -eq 'Q' -or $key.Key -eq 'q' -or $key.Key -eq 'Escape') {
                    Write-Host "Processing interrupted by user. Returning $($albums.Count) albums processed so far." -ForegroundColor Yellow
                    break
                }
            }

            # Stop if we've reached MaxResults
            if ($processed -ge $MaxResults) {
                Write-Verbose "Reached MaxResults limit ($MaxResults). Stopping processing."
                break
            }

            Write-Verbose "Processing result: id=$((Get-IfExists $result 'id')), title=$((Get-IfExists $result 'title')), type=$((Get-IfExists $result 'type'))"
            Write-Host "Processing album $($processed + 1)/$([Math]::Min($totalResults, $MaxResults)): $((Get-IfExists $result 'title')) (Press Q to stop)" -ForegroundColor DarkGray
            
            # Extract album name from title (format: "Artist - Album Name")
            $albumTitle = Get-IfExists $result 'title'
            if (-not $albumTitle) { $albumTitle = 'Unknown Album' }
            if ($albumTitle -match '^\s*(.+?)\s*[-–]\s*(.+?)\s*$') {
                $albumTitle = $matches[2].Trim()
            }

            # Get track count (with rate limiting)
            $trackCount = 0
            try {
                $releaseUri = Get-IfExists $result 'resource_url'
                if ($releaseUri) {
                    Start-Sleep -Milliseconds 850  # Rate limiting
                    $releaseDetails = Invoke-DiscogsRequest -Uri $releaseUri -Method 'GET'
                    $trackCount = $releaseDetails.tracklist.Count
                    Write-Host "$albumTitle with $trackCount tracks" -ForegroundColor DarkGray
                }
            }
            catch {
                Write-Verbose "Failed to get track count for $($albumTitle): $_"
                $trackCount = 0
            }

            # Extract properties once for efficiency
            $resultId = Get-IfExists $result 'id'
            $resultType = Get-IfExists $result 'type'
            $resultFormat = Get-IfExists $result 'format'
            $resultLabel = Get-IfExists $result 'label'
            $resultGenre = Get-IfExists $result 'genre'
            $resultTitle = Get-IfExists $result 'title'

            # Extract cover art URL (prefer larger images over thumb)
            $coverUrl = ""
            if ($result.PSObject.Properties['images'] -and $result.images.Count -gt 0) {
                # Find primary image or use first image
                $primaryImage = $result.images | Where-Object { $_.type -eq 'primary' } | Select-Object -First 1
                if (-not $primaryImage) { $primaryImage = $result.images[0] }
                
                # Use largest available size (uri1200 > uri500 > uri250 > uri150 > uri)
                if ($primaryImage.PSObject.Properties['uri1200']) { $coverUrl = $primaryImage.uri1200 }
                elseif ($primaryImage.PSObject.Properties['uri500']) { $coverUrl = $primaryImage.uri500 }
                elseif ($primaryImage.PSObject.Properties['uri250']) { $coverUrl = $primaryImage.uri250 }
                elseif ($primaryImage.PSObject.Properties['uri150']) { $coverUrl = $primaryImage.uri150 }
                elseif ($primaryImage.PSObject.Properties['uri']) { $coverUrl = $primaryImage.uri }
            }
            # Fallback to thumb if no images array
            if (-not $coverUrl) {
                $coverUrl = Get-IfExists $result 'thumb'
            }

            # Build canonical album object
            $resultUri = Get-IfExists $result 'uri'
            $resourceUri = Get-IfExists $result 'resource_url'
            $urlVal = $null
            if ($resultUri) {
                if ($resultUri -match '^https?://') { $urlVal = $resultUri } else { $urlVal = "https://www.discogs.com$resultUri" }
            } elseif ($resourceUri -and $resourceUri -match '^https?://') { $urlVal = $resourceUri }

            # Determine primary artist name
            $primaryArtist = $ArtistName
            if ($resultTitle -match '^\s*(.+?)\s*[-–]\s*(.+?)\s*$') { $primaryArtist = $matches[1].Trim() }

            $album = [PSCustomObject]@{
                id           = if ($MastersOnly -eq 'Masters') { "m$resultId" } else { "r$resultId" }
                name         = $albumTitle
                release_date = Get-IfExists $result 'year'
                type         = $resultType
                format       = if ($resultFormat) { $resultFormat -join ', ' } else { '' }
                label        = if ($resultLabel) { $resultLabel -join ', ' } else { '' }
                country      = Get-IfExists $result 'country'
                cover_url    = $coverUrl  # High-quality cover art URL
                genres       = if ($resultGenre) { @($resultGenre) } else { @() }
                artists      = @([PSCustomObject]@{ name = $primaryArtist })
                artist       = $primaryArtist
                resource_url = $resourceUri
                url          = $urlVal
                track_count  = $trackCount
                disc_count   = $null
            }
            
            Write-Debug "Album '$albumTitle' assigned ID: $($album.id) (result type: $resultType, MastersOnly: $MastersOnly)"
            
            $albums += $album
            $processed++
            Write-Verbose "Added album: $albumTitle (id: $($album.id))"
            } catch {
                Write-Warning "Failed processing Discogs result id $((Get-IfExists $result 'id')): $_"
                continue
            }
        }
        
        Write-Verbose "Processed $processed albums, returning $($albums.Count) albums"
        if ($processed -lt $totalResults) {
            Write-Host "Note: Only processed $processed of $totalResults available results. Use -Page or -MaxResults to get more." -ForegroundColor Cyan
        }
        return $albums
        
    }
    catch {
        Write-Warning "Discogs API search failed: $_"
        
        # Fallback to fetching all albums if ArtistId provided
        if ($ArtistId) {
            Write-Verbose "Falling back to fetching all albums for artist ID: $ArtistId"
            try {
                $allAlbums = Get-DArtistAlbums -Id $ArtistId -MastersOnly:$MastersOnly
                $allAlbums = @($allAlbums)
                
                $filtered = @($allAlbums | Where-Object { $_.name -like "*$AlbumName*" })
                Write-Verbose "Found $($filtered.Count) albums via fallback method"
                return $filtered
            }
            catch {
                Write-Warning "Fallback album fetch failed: $_"
                return @()
            }
        }
        
        return @()
    }
}

function Search-MBItem {
    <#
    .SYNOPSIS
    Search for artists or albums in MusicBrainz database.

    .DESCRIPTION
    Searches MusicBrainz for artists or releases (albums) matching the query string.
    Returns normalized objects compatible with OM workflow.

    .PARAMETER Query
    Search query (artist name for artist searches)

    .PARAMETER Album
    Album name for album searches

    .PARAMETER Artist
    Artist name for album searches

    .PARAMETER Type
    Type of search: 'artist' or 'album'

    .PARAMETER Limit
    Maximum number of results to return (default: 25)

    .EXAMPLE
    Search-MBItem -Query "Henryk Górecki" -Type artist

    .EXAMPLE
    Search-MBItem -Album "Help" -Artist "The Beatles" -Type album
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Query,

        [Parameter(Mandatory = $false)]
        [string]$Album,

        [Parameter(Mandatory = $false)]
        [string]$Artist,

        [Parameter(Mandatory = $true)]
        [ValidateSet('artist', 'album')]
        [string]$Type,

        [Parameter(Mandatory = $false)]
        [int]$Limit = 25
    )

    try {
        Write-Verbose "Searching MusicBrainz for $Type : $Query$Album$Artist"

        # Build MusicBrainz query
        if ($Type -eq 'artist') {
            if (-not $Query) { throw "Query required for artist search" }
            $searchQuery = "artist:$Query"
            $endpoint = 'artist'
        }
        elseif ($Type -eq 'album') {
            if (-not $Album) { throw "Album required for album search" }
            if ($Artist) {
                $searchQuery = "release:$Album AND artist:$Artist AND format:CD"
            } else {
                $searchQuery = "release:$Album AND format:CD"
            }
            $endpoint = 'release'
        }

        $queryParams = @{
            query = $searchQuery
            limit = $Limit
        }

        $response = Invoke-MusicBrainzRequest -Endpoint $endpoint -Query $queryParams

        if (-not $response) {
            Write-Verbose "No response from MusicBrainz"
            return [PSCustomObject]@{
                ($Type + 's') = [PSCustomObject]@{
                    items = @()
                }
            }
        }

        # Get the items array
        $items = @()
        $propertyName = if ($Type -eq 'artist') { 'artists' } else { 'releases' }
        if ($response.PSObject.Properties[$propertyName]) {
            $items = @($response.$propertyName)
        }
        else {
            Write-Verbose "Response does not contain '$propertyName' property."
            return [PSCustomObject]@{
                ($Type + 's') = [PSCustomObject]@{
                    items = @()
                }
            }
        }

        if ($items.Count -eq 0) {
            Write-Verbose "No $Type found for query: $Query$Album$Artist"
            return [PSCustomObject]@{
                ($Type + 's') = [PSCustomObject]@{
                    items = @()
                }
            }
        }

        Write-Verbose "Found $($items.Count) $Type"

        # Normalize to OM structure
        $normalizedItems = foreach ($item in $items) {
            if (-not $item) { continue }

            if ($Type -eq 'artist') {
                # Similar to Search-MBArtist
                $genres = @()
                if ($item.PSObject.Properties['tags'] -and $item.tags) {
                    $genres = $item.tags | Where-Object { $_ -and $_.PSObject.Properties['name'] } | Select-Object -First 5 -ExpandProperty name
                }
                $normalizedItem = [PSCustomObject]@{
                    id = $item.id
                    name = $item.name
                    genres = $genres
                    score = if ($item.PSObject.Properties['score']) { $item.score } else { 0 }
                }
            }
            elseif ($Type -eq 'album') {
                # For releases - get cover art from Cover Art Archive
                $artistName = if ($item.PSObject.Properties['artist-credit'] -and $item.'artist-credit' -and $item.'artist-credit'.name) {
                    $item.'artist-credit'.name
                } else { 'Unknown' }
                
                # Get cover art from Cover Art Archive
                $coverUrl = $null
                try {
                    $coverArtUrl = "http://coverartarchive.org/release/$($item.id)/front-500"
                    Write-Verbose "Fetching cover art for search result: $coverArtUrl"
                    
                    # Simple HEAD request to check if cover exists
                    $response = Invoke-WebRequest -Uri $coverArtUrl -Method Head -TimeoutSec 5 -ErrorAction Stop
                    if ($response.StatusCode -eq 200) {
                        $coverUrl = $coverArtUrl
                        Write-Verbose "Found cover art for album: $($item.title)"
                    }
                }
                catch {
                    Write-Verbose "No cover art found for album $($item.id): $($_.Exception.Message)"
                    # Try without size specification as fallback
                    try {
                        $fallbackUrl = "http://coverartarchive.org/release/$($item.id)/front"
                        $response = Invoke-WebRequest -Uri $fallbackUrl -Method Head -TimeoutSec 5 -ErrorAction Stop
                        if ($response.StatusCode -eq 200) {
                            $coverUrl = $fallbackUrl
                            Write-Verbose "Found cover art (fallback) for album: $($item.title)"
                        }
                    }
                    catch {
                        Write-Verbose "No cover art available for album $($item.id)"
                    }
                }
                
                # Calculate total track count from media
                $trackCount = 0
                if (Get-IfExists $item 'media') {
                    $trackCount = ($item.media | ForEach-Object { 
                        if (Get-IfExists $_ 'track-count') { [int]$_.'track-count' } 
                        else { 0 } 
                    } | Measure-Object -Sum).Sum
                }
                
                # Compute disc count (number of media objects)
                $discCount = $null
                if (Get-IfExists $item 'media') { $discCount = (@($item.media).Count) }

                # Build web URL to MusicBrainz release page
                $mbUrl = if ($item.id) { "https://musicbrainz.org/release/$($item.id)" } else { $null }

                # Extract genres/tags if present
                $mbGenres = @()
                if ($item.PSObject.Properties['genres'] -and $item.genres) {
                    $mbGenres = $item.genres | Where-Object { $_ -and $_.PSObject.Properties['name'] } | Select-Object -First 5 -ExpandProperty name
                }
                elseif ($item.PSObject.Properties['tags'] -and $item.tags) {
                    $mbGenres = $item.tags | Where-Object { $_ -and $_.PSObject.Properties['name'] } | Select-Object -First 5 -ExpandProperty name
                }

                $normalizedItem = [PSCustomObject]@{
                    id = $item.id
                    name = $item.title
                    artists = @([PSCustomObject]@{ name = $artistName })
                    score = if ($item.PSObject.Properties['score']) { $item.score } else { 0 }
                    cover_url = $coverUrl  # Cover Art Archive URL
                    release_date = if ($item.PSObject.Properties['date']) { $item.date } else { $null }
                    track_count = $trackCount
                    disc_count = $discCount
                    url = $mbUrl
                    genres = $mbGenres
                }
            }
            $normalizedItem
        }

        # Sort by score
        $sortedItems = $normalizedItems | Sort-Object -Property score -Descending

        return [PSCustomObject]@{
            ($Type + 's') = [PSCustomObject]@{
                items = $sortedItems
            }
        }
    }
    catch {
        Write-Warning "MusicBrainz $Type search failed: $_"
        return [PSCustomObject]@{
            ($Type + 's') = [PSCustomObject]@{
                items = @()
            }
        }
    }
}
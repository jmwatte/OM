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
                # For releases
                $artistName = if ($item.PSObject.Properties['artist-credit'] -and $item.'artist-credit' -and $item.'artist-credit'.name) {
                    $item.'artist-credit'.name
                } else { 'Unknown' }
                $normalizedItem = [PSCustomObject]@{
                    id = $item.id
                    name = $item.title
                    artists = @([PSCustomObject]@{ name = $artistName })
                    score = if ($item.PSObject.Properties['score']) { $item.score } else { 0 }
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
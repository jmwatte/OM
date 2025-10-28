function Search-MBItem {
    <#
    .SYNOPSIS
    Search for artists or albums in MusicBrainz database.

    .DESCRIPTION
    Searches MusicBrainz for artists or releases (albums) matching the query string.
    Returns normalized objects compatible with OM workflow.

    .PARAMETER Query
    Search query (artist name or "artist album")

    .PARAMETER Type
    Type of search: 'artist' or 'album'

    .PARAMETER Limit
    Maximum number of results to return (default: 25)

    .EXAMPLE
    Search-MBItem -Query "Henryk Górecki" -Type artist

    .EXAMPLE
    Search-MBItem -Query "The Beatles Help" -Type album
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Query,

        [Parameter(Mandatory = $true)]
        [ValidateSet('artist', 'album')]
        [string]$Type,

        [Parameter(Mandatory = $false)]
        [int]$Limit = 25
    )

    try {
        Write-Verbose "Searching MusicBrainz for $Type: $Query"

        # Build MusicBrainz query
        if ($Type -eq 'artist') {
            $searchQuery = "artist:$Query"
            $endpoint = 'artist'
        }
        elseif ($Type -eq 'album') {
            # For album, try to parse "artist album"
            $parts = $Query -split ' ', 2
            if ($parts.Count -eq 2) {
                $artistPart = $parts[0]
                $albumPart = $parts[1]
                $searchQuery = "release:$albumPart AND artist:$artistPart AND format:CD"
            }
            else {
                $searchQuery = "release:$Query AND format:CD"
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
            Write-Verbose "No $Type found for query: $Query"
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
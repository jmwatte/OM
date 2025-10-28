function Search-DItem {
    <#
    .SYNOPSIS
    Search Discogs for artists.
    
    .DESCRIPTION
    Queries Discogs database API for artist matches using the Invoke-DiscogsRequest helper.
    
    .PARAMETER Query
    The search query string (artist name).
    
    .PARAMETER Type
    The type of item to search for. Currently only 'artist' is supported.
    
    .EXAMPLE
    Search-DItem -Query "Pink Floyd" -Type artist
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Query,

        [Parameter(Mandatory = $true)]
        [ValidateSet('artist')]
        [string]$Type
    )

    if ($Type -ne 'artist') {
        throw "Only 'artist' type is currently supported for Discogs search."
    }




    


    try {
        # Use Invoke-DiscogsRequest which handles authentication automatically
        $escapedQuery = [uri]::EscapeDataString($Query)
        $response = Invoke-DiscogsRequest -Uri "/database/search?q=$escapedQuery&type=artist"
        
        # Transform Discogs results to match Spotify-like structure
        $items = @()
        if ($response.results) {
            foreach ($result in $response.results) {
                $item = [PSCustomObject]@{
                    name   = $result.title
                    id     = $result.id
                    genres = @()  # Genres come from artist details page, not search
                    type   = $result.type
                    thumb  = $result.thumb
                    uri    = $result.uri  # Discogs resource URI
                }
                $items += $item
            }
        }
        
        # Return structure compatible with Spotify/Qobuz pattern
        return [PSCustomObject]@{
            artists = [PSCustomObject]@{
                items = $items
            }
        }
    }
    catch {
        Write-Warning "Discogs artist search failed: $_"
        if ($_.Exception.Message -eq "The property 'Discogs' cannot be found on this object. Verify that the property exists.") {
         
            Write-Warning "It seems the Discogs module is not properly installed or configured. Please ensure you have set up the Discogs API credentials."
         }
        return [PSCustomObject]@{
            artists = [PSCustomObject]@{
                items = @()
            }
        }
    }
}

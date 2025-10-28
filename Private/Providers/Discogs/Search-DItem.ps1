function Search-DItem {
    <#
    .SYNOPSIS
    Search Discogs for artists or albums.
    
    .DESCRIPTION
    Queries Discogs database API for artist or album matches using the Invoke-DiscogsRequest helper.
    
    .PARAMETER Query
    The search query string (artist name or "artist album").
    
    .PARAMETER Type
    The type of item to search for: 'artist' or 'album'.
    
    .EXAMPLE
    Search-DItem -Query "Pink Floyd" -Type artist
    
    .EXAMPLE
    Search-DItem -Query "Pink Floyd Dark Side of the Moon" -Type album
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Query,

        [Parameter(Mandatory = $true)]
        [ValidateSet('artist', 'album')]
        [string]$Type
    )

    try {
        # Use Invoke-DiscogsRequest which handles authentication automatically
        $escapedQuery = [uri]::EscapeDataString($Query)
        $apiType = if ($Type -eq 'album') { 'release' } else { 'artist' }
        $uri = "/database/search?q=$escapedQuery&type=$apiType"
        if ($Type -eq 'album') {
            $uri += "&format_exact=CD"  # Focus on CD releases for albums
        }
        $response = Invoke-DiscogsRequest -Uri $uri
        
        # Transform Discogs results to match Spotify-like structure
        $items = @()
        if ($response.results) {
            foreach ($result in $response.results) {
                $item = [PSCustomObject]@{
                    name   = $result.title
                    id     = $result.id
                    genres = @()  # Genres come from details page
                    type   = $result.type
                    thumb  = $result.thumb
                    uri    = $result.uri  # Discogs resource URI
                }
                if ($Type -eq 'album') {
                    # Add artist info for albums
                    $item | Add-Member -MemberType NoteProperty -Name 'artists' -Value @([PSCustomObject]@{ name = $result.title.Split(' - ')[0] }) -Force
                }
                $items += $item
            }
        }
        
        # Return structure compatible with Spotify/Qobuz pattern
        $resultType = if ($Type -eq 'album') { 'albums' } else { 'artists' }
        return [PSCustomObject]@{
            $resultType = [PSCustomObject]@{
                items = $items
            }
        }
    }
    catch {
        Write-Warning "Discogs $Type search failed: $_"
        if ($_.Exception.Message -eq "The property 'Discogs' cannot be found on this object. Verify that the property exists.") {
         
            Write-Warning "It seems the Discogs module is not properly installed or configured. Please ensure you have set up the Discogs API credentials."
         }
        $resultType = if ($Type -eq 'album') { 'albums' } else { 'artists' }
        return [PSCustomObject]@{
            $resultType = [PSCustomObject]@{
                items = @()
            }
        }
    }
}

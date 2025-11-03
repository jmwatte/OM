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

    Write-Verbose "Searching Discogs for $Type with query: '$Query'"

    try {
        # Use Invoke-DiscogsRequest which handles authentication automatically
        $escapedQuery = [uri]::EscapeDataString($Query)
        $apiType = if ($Type -eq 'album') { 'release' } else { 'artist' }
        $uri = "/database/search?q=$escapedQuery&type=$apiType"
        if ($Type -eq 'album') {
            $uri += "&format_exact=CD"  # Focus on CD releases for albums
        }
        Write-Verbose "Calling Discogs API with URI: $uri"
        $response = Invoke-DiscogsRequest -Uri $uri
        
        # Transform Discogs results to match Spotify-like structure
        $items = @()
        if ($response.results) {
            Write-Verbose "Found $($response.results.Count) results from Discogs"
            foreach ($result in $response.results) {
                Write-Verbose "Processing result: $(Get-IfExists $result 'title')"
                $genres = Get-IfExists $result 'genre'
                
                # Extract cover art URL (prefer larger images over thumb)
                $coverUrl = ""
                if ($result.PSObject.Properties['images'] -and $result.images.Count -gt 0) {
                    # Find primary image or use first image
                    $primaryImage = $result.images | Where-Object { $_.type -eq 'primary' } | Select-Object -First 1
                    if (-not $primaryImage) { $primaryImage = $result.images[0] }
                    
                    # Use largest available size (uri > uri1200 > uri500 > uri250 > uri150)
                    if ($primaryImage.PSObject.Properties['uri']) { $coverUrl = $primaryImage.uri }
                    elseif ($primaryImage.PSObject.Properties['uri1200']) { $coverUrl = $primaryImage.uri1200 }
                    elseif ($primaryImage.PSObject.Properties['uri500']) { $coverUrl = $primaryImage.uri500 }
                    elseif ($primaryImage.PSObject.Properties['uri250']) { $coverUrl = $primaryImage.uri250 }
                    elseif ($primaryImage.PSObject.Properties['uri150']) { $coverUrl = $primaryImage.uri150 }
                    Write-Verbose "Found cover art for $(Get-IfExists $result 'title'): $coverUrl"
                }
                # Fallback to thumb if no images array
                if (-not $coverUrl) {
                    $coverUrl = Get-IfExists $result 'thumb'
                    if ($coverUrl) {
                        Write-Verbose "Using thumbnail cover art for $(Get-IfExists $result 'title'): $coverUrl"
                    } else {
                        Write-Verbose "No cover art found for $(Get-IfExists $result 'title')"
                    }
                }
                
                $item = [PSCustomObject]@{
                    release_date = Get-IfExists $result 'year'
                    type         = Get-IfExists $result 'type'
                    name         = Get-IfExists $result 'title'
                    id = switch (Get-IfExists $result 'type') {
                        'release' { "r$(Get-IfExists $result 'id')" }
                        'master' { "m$(Get-IfExists $result 'id')" }
                        default { Get-IfExists $result 'id' }
                    }
                    genres       = if ($genres) { $genres -join ', ' } else { '' }  # Genres come from details page
                    cover_url    = $coverUrl  # High-quality cover art URL
                    uri          = Get-IfExists $result 'uri'  # Discogs resource URI
                }
                if ($Type -eq 'album') {
                    # Add artist info for albums
                    $title = Get-IfExists $result 'title'
                    $artistName = if ($title) {
                        $titleParts = $title.Split(' - ')
                        if ($titleParts.Count -gt 1) { $titleParts[0] } else { 'Unknown Artist' }
                    } else { 'Unknown Artist' }
                    $item | Add-Member -MemberType NoteProperty -Name 'artists' -Value @([PSCustomObject]@{ name = $artistName }) -Force
                    Write-Verbose "Extracted artist '$artistName' from album title '$title'"
                }
                $items += $item
            }
        } else {
            Write-Verbose "No results found in Discogs response"
        }
        
        # Return structure compatible with Spotify/Qobuz pattern
        $resultType = if ($Type -eq 'album') { 'albums' } else { 'artists' }
        Write-Verbose "Returning $($items.Count) $resultType from Discogs search"
        return [PSCustomObject]@{
            $resultType = [PSCustomObject]@{
                items = $items
            }
        }
    }
    catch {
        Write-Verbose "Discogs search encountered an error, returning empty results"
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

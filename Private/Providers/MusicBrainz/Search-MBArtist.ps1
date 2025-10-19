function Search-MBArtist {
    <#
    .SYNOPSIS
    Search for artists in MusicBrainz database.
    
    .DESCRIPTION
    Searches MusicBrainz for artists matching the query string.
    Returns normalized artist objects compatible with MuFo workflow.
    
    .PARAMETER Query
    Artist name or search query
    
    .PARAMETER Limit
    Maximum number of results to return (default: 25)
    
    .EXAMPLE
    Search-MBArtist -Query "Henryk Górecki"
    
    .EXAMPLE
    Search-MBArtist -Query "London Symphony Orchestra" -Limit 10
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Query,
        
        [Parameter(Mandatory = $false)]
        [int]$Limit = 25
    )

    try {
        Write-Verbose "Searching MusicBrainz for artist: $Query"
        
        # Build MusicBrainz query using Lucene syntax
        # Escape special characters and build query
        $searchQuery = "artist:$Query"
        
        $queryParams = @{
            query = $searchQuery
            limit = $Limit
        }
        
        $response = Invoke-MusicBrainzRequest -Endpoint 'artist' -Query $queryParams
        
        if (-not $response) {
            Write-Verbose "No response from MusicBrainz"
            return @()
        }
        
        # MusicBrainz returns artists in 'artists' property
        $artists = @()
        if ($response.PSObject.Properties['artists']) {
            $artists = @($response.artists)
        } else {
            Write-Verbose "Response does not contain 'artists' property. Response type: $($response.GetType().Name)"
            Write-Verbose "Available properties: $($response.PSObject.Properties.Name -join ', ')"
            return @()
        }
        
        if ($artists.Count -eq 0) {
            Write-Verbose "No artists found for query: $Query"
            return @()
        }
        
        Write-Verbose "Found $($artists.Count) artists"
        
        # Normalize to Spotify-like structure
        $normalizedArtists = foreach ($artist in $artists) {
            if (-not $artist) { continue }
            
            # Verify required properties exist
            if (-not $artist.PSObject.Properties['id'] -or -not $artist.PSObject.Properties['name']) {
                Write-Verbose "Skipping artist with missing id or name"
                continue
            }
            
            # Extract genres/tags (MusicBrainz uses 'tags')
            $genres = @()
            if ($artist.PSObject.Properties['tags'] -and $artist.tags) {
                $genres = $artist.tags | 
                    Where-Object { $_ -and $_.PSObject.Properties['name'] } | 
                    Select-Object -First 5 -ExpandProperty name
            }
            
            # Get artist type (Person, Group, Orchestra, Choir, etc.)
            $artistType = if ($artist.PSObject.Properties['type'] -and $artist.type) { 
                $artist.type 
            } else { 
                'Unknown' 
            }
            
            # Build disambiguation if available
            $disambiguation = if ($artist.PSObject.Properties['disambiguation'] -and $artist.disambiguation) { 
                " ($($artist.disambiguation))" 
            } else { 
                "" 
            }
            
            [PSCustomObject]@{
                id = $artist.id  # MBID
                name = $artist.name
                displayName = $artist.name + $disambiguation
                type = $artistType
                genres = $genres
                score = if ($artist.PSObject.Properties['score']) { $artist.score } else { 0 }
                country = if ($artist.PSObject.Properties['country'] -and $artist.country) { $artist.country } else { $null }
                _rawMusicBrainzObject = $artist
            }
        }
        
        # Sort by score (MusicBrainz provides relevance score)
        return $normalizedArtists | Sort-Object -Property score -Descending
    }
    catch {
        Write-Warning "MusicBrainz artist search failed: $_"
        return @()
    }
}

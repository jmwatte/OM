function Search-QAlbumsByName {
    <#
    .SYNOPSIS
        Search Qobuz for albums by artist and album name.
    
    .DESCRIPTION
        Since Qobuz has no direct search API, this function fetches all albums for the artist
        and filters them by album name locally using fuzzy matching.
    
    .PARAMETER ArtistId
        The Qobuz artist URL/href (e.g., /be-fr/interpreter/artist-slug/12345).
    
    .PARAMETER AlbumName
        The album name to search for.
    
    .PARAMETER ArtistName
        Optional artist name for display purposes.
    
    .EXAMPLE
        Search-QAlbumsByName -ArtistId "/be-fr/interpreter/pink-floyd/123" -AlbumName "Dark Side"
        Fetches all Pink Floyd albums from Qobuz and filters for "Dark Side" matches.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ArtistId,

        [Parameter(Mandatory)]
        [string]$AlbumName,

        [Parameter()]
        [string]$ArtistName
    )

    Write-Verbose "Fetching Qobuz albums for artist: $ArtistId"
    Write-Verbose "Filtering for album name: $AlbumName"

    try {
        $allAlbums = Get-QArtistAlbums -Id $ArtistId
        # Normalize to array before checking Count
        $allAlbums = @($allAlbums)
    }
    catch {
        Write-Warning "Failed to fetch Qobuz albums: $_"
        return @()
    }

    if (-not $allAlbums -or $allAlbums.Count -eq 0) {
        Write-Verbose "No albums found for artist"
        return @()
    }

    # Filter albums by name using fuzzy matching
    $filteredAlbums = @()
    
    foreach ($album in $allAlbums) {
        # Simple contains match (case-insensitive)
        if ($album.name -like "*$AlbumName*") {
            $filteredAlbums += $album
            continue
        }

        # Try Jaccard similarity if available
        if (Get-Command Get-StringSimilarity-Jaccard -ErrorAction SilentlyContinue) {
            $similarity = Get-StringSimilarity-Jaccard -String1 $AlbumName -String2 $album.name
            # Include if similarity is above threshold (0.3 = 30% similar)
            if ($similarity -gt 0.3) {
                # Add similarity score for sorting
                $album | Add-Member -NotePropertyName '_similarity' -NotePropertyValue $similarity -Force
                $filteredAlbums += $album
            }
        }
    }

    # Sort by similarity score (if available) or keep original order
    if ($filteredAlbums.Count -gt 0 -and $filteredAlbums[0].PSObject.Properties['_similarity']) {
        $filteredAlbums = $filteredAlbums | Sort-Object { -$_._similarity }
    }

    Write-Verbose "Found $($filteredAlbums.Count) matching albums out of $($allAlbums.Count) total albums"
    
    return $filteredAlbums
}

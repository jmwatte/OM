function Search-SAlbumsByName {
    <#
    .SYNOPSIS
        Search Spotify for albums by artist and album name.
    
    .DESCRIPTION
        Uses Spotishell's Search-Item to find albums matching both artist and album name.
        Returns targeted results instead of full artist discography.
    
    .PARAMETER ArtistName
        The artist name to search for.
    
    .PARAMETER AlbumName
        The album name to search for.
    
    .PARAMETER ArtistId
        Optional Spotify artist ID to filter results.
    
    .EXAMPLE
        Search-SAlbumsByName -ArtistName "Pink Floyd" -AlbumName "Dark Side of the Moon"
        Searches Spotify for albums matching "Pink Floyd Dark Side of the Moon".
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ArtistName,

        [Parameter(Mandatory)]
        [string]$AlbumName,

        [Parameter()]
        [string]$ArtistId
    )

    # Build search query: start with strict artist+album search, then try broader keywords
    $escapedArtist = $ArtistName.Replace('"', '\"')
    $escapedAlbum = $AlbumName.Replace('"', '\"')

    $queryAttempts = @(
        @{ Query = "artist:`"$escapedArtist`" album:`"$escapedAlbum`""; Description = 'strict artist+album' },
        @{ Query = ("$ArtistName $AlbumName").Trim(); Description = 'broad keyword' }
    )

    $searchResults = $null

    foreach ($attempt in $queryAttempts) {
        $queryText = $attempt.Query
        $description = $attempt.Description

        if ($searchResults) { break }

        Write-Verbose "Searching Spotify ($description) for: $queryText"

        try {
            $candidateResults = Search-Item -Query $queryText -Type Album
        }
        catch {
            Write-Warning "Spotify album search failed for query '$queryText': $_"
            continue
        }

        if ($candidateResults -and $candidateResults.albums -and $candidateResults.albums.items -and $candidateResults.albums.items.Count -gt 0) {
            $searchResults = $candidateResults
            break
        }

        Write-Verbose "No albums found for query: $queryText; trying next fallback if available."
    }

    if (-not $searchResults -or -not $searchResults.albums -or -not $searchResults.albums.items) {
        Write-Verbose "No albums found after all query attempts for artist '$ArtistName' and album '$AlbumName'"
        return @()
    }

    $albums = $searchResults.albums.items

    # If ArtistId provided, filter by artist
    if ($ArtistId) {
        $albums = $albums | Where-Object {
            $albumArtists = $_.artists
            if ($albumArtists) {
                # Check if any of the album's artists match the provided ArtistId
                $matchFound = $false
                foreach ($artist in $albumArtists) {
                    if ($artist.id -eq $ArtistId) {
                        $matchFound = $true
                        break
                    }
                }
                $matchFound
            }
            else {
                $false
            }
        }
    }

    Write-Verbose "Found $($albums.Count) albums for: $attempt.Query"
    
    return $albums
}

function Search-SItem {
    <#
    .SYNOPSIS
        Search Spotify for artists or albums.

    .DESCRIPTION
        Wraps Spotishell's Search-Item cmdlet to provide standardized search for OM.
        Supports searching for artists or albums based on query.

    .PARAMETER Query
        The search query (e.g., artist name or "artist album").

    .PARAMETER Type
        The type of search: 'artist' or 'album'. Defaults to 'artist'.

    .EXAMPLE
        Search-SItem -Query "Pink Floyd" -Type artist
        Searches for artists matching "Pink Floyd".

    .EXAMPLE
        Search-SItem -Query "Pink Floyd Dark Side of the Moon" -Type album
        Searches for albums matching the query.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Query,

        [Parameter()]
        [ValidateSet('artist', 'album')]
        [string]$Type = 'artist'
    )

    # Load similarity helper if not available
    if (-not (Get-Command -Name Get-StringSimilarity-Jaccard -ErrorAction SilentlyContinue)) {
        $utilsDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Utils'
        $similarityPath = Join-Path $utilsDir 'Get-StringSimilarity-Jaccard.ps1'
        if (Test-Path $similarityPath) { . $similarityPath }
    }

    try {
        $result = Search-Item -Query $Query -Type $Type
        if ($result) {
            # Standardize output to match OM expectations
            if ($Type -eq 'album' -and $result.albums) {
                # Score and filter albums by similarity to query
                $scoredAlbums = @()
                foreach ($album in $result.albums.items) {
                    $albumName = if ($album.name) { $album.name } else { '' }
                    $artistName = if ($album.artists -and $album.artists[0].name) { $album.artists[0].name } else { '' }
                    $combinedName = "$artistName $albumName".Trim()
                    
                    if ($combinedName) {
                        $similarity = Get-StringSimilarity-Jaccard -String1 $Query -String2 $combinedName
                        $scoredAlbums += [PSCustomObject]@{
                            Album = $album
                            Score = $similarity
                        }
                    }
                }
                
                # Sort by similarity and take top 10
                $topAlbums = $scoredAlbums | Sort-Object -Property Score -Descending | Select-Object -First 10
                Write-Verbose "Processing top $($topAlbums.Count) albums based on similarity to query"
                
                # Extract cover art URLs from album objects
                $albumsWithCover = $topAlbums | ForEach-Object {
                    $album = $_.Album
                    Write-Verbose "Processing album: $($album.name) by $($album.artists[0].name) (similarity: $($_.Score.ToString('F3')))"
                    #$album = $_
                    
                    # Extract cover art URL from images array (prefer largest image)
                    $coverUrl = $null
                    if ($album.images -and $album.images.Count -gt 0) {
                        # Sort by area (width * height) descending and take the first (largest)
                        $largestImage = $album.images | 
                            Sort-Object { [int]$_.width * [int]$_.height } -Descending | 
                            Select-Object -First 1
                        $coverUrl = $largestImage.url
                    }
                    
                    # Add cover_url property to match other providers
                    $album | Add-Member -MemberType NoteProperty -Name 'cover_url' -Value $coverUrl -Force

                    # Canonical fields expected by Normalize-AlbumResult
                    $trackCount = $null
                    if ($album.total_tracks) { try { $trackCount = [int]$album.total_tracks } catch { $trackCount = $album.total_tracks } }
                    $album | Add-Member -MemberType NoteProperty -Name 'track_count' -Value $trackCount -Force

                    $urlVal = $null
                    if ($album.external_urls -and $album.external_urls.spotify) { $urlVal = $album.external_urls.spotify } elseif ($album.href) { $urlVal = $album.href }
                    $album | Add-Member -MemberType NoteProperty -Name 'url' -Value $urlVal -Force

                    $album | Add-Member -MemberType NoteProperty -Name 'disc_count' -Value $null -Force

                    $album
                }
                
                return [PSCustomObject]@{
                    albums = [PSCustomObject]@{
                        items = $albumsWithCover
                    }
                }
            }
            elseif ($Type -eq 'artist' -and $result.artists) {
                # Score and filter artists by similarity to query
                $scoredArtists = @()
                foreach ($artist in $result.artists.items) {
                    $artistName = if ($artist.name) { $artist.name } else { '' }
                    
                    if ($artistName) {
                        $similarity = Get-StringSimilarity-Jaccard -String1 $Query -String2 $artistName
                        $scoredArtists += [PSCustomObject]@{
                            Artist = $artist
                            Score = $similarity
                        }
                    }
                }
                
                # Sort by similarity and take top 10
                $topArtists = $scoredArtists | Sort-Object -Property Score -Descending | Select-Object -First 10
                Write-Verbose "Processing top $($topArtists.Count) artists based on similarity to query"
                
                $filteredArtists = $topArtists | ForEach-Object {
                    Write-Verbose "Processing artist: $($_.Artist.name) (similarity: $($_.Score.ToString('F3')))"
                    $_.Artist
                }
                
                return [PSCustomObject]@{
                    artists = [PSCustomObject]@{
                        items = $filteredArtists
                    }
                }
            }
        }
    }
    catch {
        Write-Verbose "Spotify search failed for query '$Query' type '$Type': $_"
    }

    # Return empty result on failure
    return [PSCustomObject]@{
        ($Type + 's') = [PSCustomObject]@{
            items = @()
        }
    }
}
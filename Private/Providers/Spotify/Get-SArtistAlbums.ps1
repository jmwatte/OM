function Get-SArtistAlbums {
    <#
    .SYNOPSIS
        Get Spotify artist albums with cover art URLs.

    .DESCRIPTION
        Wraps Spotishell's Get-ArtistAlbums cmdlet and extracts cover art URLs
        from the images array, adding a cover_url property to match other providers.

    .PARAMETER Id
        The Spotify artist ID.

    .PARAMETER Album
        Switch to get albums (required for Spotishell compatibility).

    .EXAMPLE
        Get-SArtistAlbums -Id "4gzpq5DPGxSnKTe4SA8HAU"
        Gets albums for the specified Spotify artist ID.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Id,

        [Parameter()]
        [switch]$Album
    )

    try {
        # Call Spotishell's Get-ArtistAlbums
        $albums = Get-ArtistAlbums -Id $Id -Album

        if ($albums) {
            # Extract cover art URLs from album objects
            $albums = $albums | ForEach-Object {
                $album = $_

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
        }

        return $albums
    }
    catch {
        Write-Warning "Failed to get Spotify artist albums for ID '$Id': $_"
        return @()
    }
}
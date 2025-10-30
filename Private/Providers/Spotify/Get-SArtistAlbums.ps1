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
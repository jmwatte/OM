function Get-CoverArtUrl {
    <#
    .SYNOPSIS
        Gets an appropriately sized cover art URL for a provider.

    .DESCRIPTION
        Modifies provider cover URLs to request images at the desired size.
        Different providers have different URL patterns for different sizes.

    .PARAMETER CoverUrl
        Original cover URL from the provider

    .PARAMETER Provider
        Music provider (Spotify, Qobuz, Discogs, MusicBrainz)

    .PARAMETER Size
        Desired size: 'small', 'medium', 'large', 'original'

    .EXAMPLE
        Get-CoverArtUrl -CoverUrl "https://..." -Provider Qobuz -Size large
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CoverUrl,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Spotify', 'Qobuz', 'Discogs', 'MusicBrainz')]
        [string]$Provider,

        [Parameter(Mandatory = $true)]
        [ValidateSet('small', 'medium', 'large', 'original')]
        [string]$Size
    )

    if (-not $CoverUrl) {
        return $null
    }

    # Size mappings to pixel dimensions
    $sizeMap = @{
        'small' = 150    # Qobuz 150px
        'medium' = 600   # Qobuz 600px
        'large' = 600    # Qobuz max is 600px
        'original' = 0   # Use original size
    }

    $targetSize = $sizeMap[$Size]

    switch ($Provider) {
        'Qobuz' {
            # Qobuz URLs can be modified by changing the size parameter
            # Available sizes: 50, 150, 600, org (original)
            # Example: https://static.qobuz.com/images/covers/12/34/123456789_150.jpg
            # Can be changed to: https://static.qobuz.com/images/covers/12/34/123456789_600.jpg
            # Or: https://static.qobuz.com/images/covers/12/34/123456789.jpg (original)

            if ($CoverUrl -match '_(\d+)\.(jpg|png|jpeg)$') {
                $extension = $matches[2]
                if ($Size -eq 'original') {
                    # Remove size suffix to get original
                    $newUrl = $CoverUrl -replace '_(\d+)\.(jpg|png|jpeg)$', ".$extension"
                }
                else {
                    $newUrl = $CoverUrl -replace '_(\d+)\.(jpg|png|jpeg)$', "_${targetSize}.$extension"
                }
                return $newUrl
            }
            elseif ($CoverUrl -match '\.(jpg|png|jpeg)$' -and -not ($CoverUrl -match '_\d+\.')) {
                # URL already has no size suffix (might be original)
                if ($Size -eq 'original') {
                    return $CoverUrl
                }
                else {
                    # Add size suffix
                    $extension = $matches[1]
                    $newUrl = $CoverUrl -replace '\.(jpg|png|jpeg)$', "_${targetSize}.$extension"
                    return $newUrl
                }
            }
        }

        'Spotify' {
            # Spotify images are already provided in different sizes in the images array
            # The current implementation selects the largest, so for different sizes we'd need
            # to modify the selection logic. For now, return the original URL.
            return $CoverUrl
        }

        'Discogs' {
            # Discogs provides multiple image URLs (uri150, uri250, uri500, uri1200)
            # The current implementation selects the largest available
            # For different sizes, we'd need to modify the selection logic
            return $CoverUrl
        }

        'MusicBrainz' {
            # MusicBrainz Cover Art Archive provides different sizes via URL parameters
            # Example: http://coverartarchive.org/release/123/front-500
            # Can be changed to: http://coverartarchive.org/release/123/front-1000 or front (original)

            if ($CoverUrl -match 'front-(\d+)$') {
                if ($Size -eq 'original') {
                    $newUrl = $CoverUrl -replace 'front-\d+$', 'front'
                }
                else {
                    $newUrl = $CoverUrl -replace 'front-\d+$', "front-${targetSize}"
                }
                return $newUrl
            }
        }
    }

    # If we can't modify the URL, return the original
    return $CoverUrl
}
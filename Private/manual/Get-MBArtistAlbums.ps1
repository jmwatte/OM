function Get-MBArtistAlbums {
    <#
    .SYNOPSIS
    Get all releases (albums) for a MusicBrainz artist.
    
    .DESCRIPTION
    Retrieves all releases for a given MusicBrainz artist ID (MBID).
    Returns normalized album objects compatible with MuFo workflow.
    
    .PARAMETER ArtistId
    MusicBrainz Artist ID (MBID)
    
    .PARAMETER Limit
    Maximum number of results to return (default: 100)
    
    .EXAMPLE
    Get-MBArtistAlbums -ArtistId "38712b30-5501-487e-8d15-0a9ca8e9009c"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ArtistId,
        
        [Parameter(Mandatory = $false)]
        [int]$Limit = 100
    )

    try {
        Write-Verbose "Fetching releases for MusicBrainz artist: $ArtistId"
        
        # Query for releases by this artist
        # We want official albums (not singles, compilations by default)
        $queryParams = @{
            artist = $ArtistId
            type = 'album'  # Focus on albums
            status = 'official'  # Only official releases
            limit = $Limit
        }
        
        $response = Invoke-MusicBrainzRequest -Endpoint 'release' -Query $queryParams
        
        if (-not $response -or -not (Get-IfExists $response 'releases')) {
            Write-Verbose "No releases found for artist: $ArtistId"
            return @()
        }
        
        $releases = $response.releases
        Write-Verbose "Found $($releases.Count) releases"
        
        # Normalize to Spotify-like structure
        $normalizedReleases = foreach ($release in $releases) {
            # Extract release date (MusicBrainz has various date formats)
            $releaseDate = $null
            if (Get-IfExists $release 'date') {
                $releaseDate = $release.date
            } elseif (Get-IfExists $release 'release-events' -and $release.'release-events'.Count -gt 0) {
                $firstEvent = $release.'release-events'[0]
                if (Get-IfExists $firstEvent 'date') {
                    $releaseDate = $firstEvent.date
                }
            }
            
            # Extract year from date
            $year = $null
            if ($releaseDate -and $releaseDate -match '^(\d{4})') {
                $year = [int]$matches[1]
            }
            
            # Get country
            $country = if (Get-IfExists $release 'country') { 
                " [$($release.country)]" 
            } else { 
                "" 
            }
            
            # Get label info if available
            $label = ""
            if ($release.PSObject.Properties['label-info'] -and $release.'label-info' -and $release.'label-info'.Count -gt 0) {
                $labelObj = $release.'label-info'[0]
                if ($labelObj -and $labelObj.PSObject.Properties['label'] -and $labelObj.label -and $labelObj.label.PSObject.Properties['name']) {
                    $label = " - $($labelObj.label.name)"
                }
            }
            
            # Build display name with disambiguation
            $displayName = $release.title
            if (Get-IfExists $release 'disambiguation') {
                $displayName += " ($($release.disambiguation))"
            }
            $displayName += $country + $label
            
            [PSCustomObject]@{
                id = $release.id  # MBID
                name = $displayName
                title = $release.title  # Clean title without extra info
                release_date = $releaseDate
                year = $year
                country = if (Get-IfExists $release 'country') { $release.country } else { $null }
                barcode = if (Get-IfExists $release 'barcode') { $release.barcode } else { $null }
                status = if (Get-IfExists $release 'status') { $release.status } else { 'Official' }
                _rawMusicBrainzObject = $release
            }
        }
        
        # Sort by year (newest first), then by title
        return $normalizedReleases | Sort-Object -Property @{Expression = {$_.year}; Descending = $true}, title
    }
    catch {
        Write-Warning "MusicBrainz get artist albums failed: $_"
        return @()
    }
}

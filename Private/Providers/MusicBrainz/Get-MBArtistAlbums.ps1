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
            type   = 'album'  # Focus on albums
            status = 'official'  # Only official releases
            limit  = $Limit
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
            write-host "extracting release: $($release.title)" -ForegroundColor Cyan
            # Extract release date (MusicBrainz has various date formats)
            $releaseDate = $null
            if (Get-IfExists $release 'date') {
                $releaseDate = $release.date
            }
            elseif (Get-IfExists $release 'release-events') {
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
            else{$year="0000"}
            # Get country
            $country = if (Get-IfExists $release 'country') { 
                " [$($release.country)]" 
            }
            else { 
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
            
            # Get track count by querying the release endpoint with inc=recordings
            $track_count = 0
            try {
                $releaseResponse = Invoke-MusicBrainzRequest -Endpoint 'release' -Id $release.id -Inc 'recordings'
                if ($releaseResponse -and (Get-IfExists $releaseResponse 'media')) {
                    $track_count = ($releaseResponse.media | ForEach-Object { 
                            if (Get-IfExists $_ 'track-count') { [int]$_.'track-count' } 
                            elseif (Get-IfExists $_ 'tracks') { $_.tracks.Count } 
                            else { 0 } 
                        } | Measure-Object -Sum).Sum
                }
            }
            catch {
                Write-Verbose "Failed to get track count for release $($release.id): $_"
            }

            # Get cover art from Cover Art Archive
            $coverUrl = $null
            try {
                $coverArtUrl = "http://coverartarchive.org/release/$($release.id)/front-500"
                Write-Verbose "Fetching cover art: $coverArtUrl"
                
                # Simple HEAD request to check if cover exists (don't download full image)
                $response = Invoke-WebRequest -Uri $coverArtUrl -Method Head -TimeoutSec 5 -ErrorAction Stop
                if ($response.StatusCode -eq 200) {
                    $coverUrl = $coverArtUrl
                    Write-Verbose "Found cover art for release: $($release.title)"
                }
            }
            catch {
                Write-Verbose "No cover art found for release $($release.id): $($_.Exception.Message)"
                # Try without size specification as fallback
                try {
                    $fallbackUrl = "http://coverartarchive.org/release/$($release.id)/front"
                    $response = Invoke-WebRequest -Uri $fallbackUrl -Method Head -TimeoutSec 5 -ErrorAction Stop
                    if ($response.StatusCode -eq 200) {
                        $coverUrl = $fallbackUrl
                        Write-Verbose "Found cover art (fallback) for release: $($release.title)"
                    }
                }
                catch {
                    Write-Verbose "No cover art available for release $($release.id)"
                }
            }

            [PSCustomObject]@{
                id           = $release.id
                name         = $release.title
                displayName  = $displayName
                year         = $year
                release_date = $releaseDate
                track_count  = $track_count
                disc_count   = if (Get-IfExists $release 'media') { (@($release.media).Count) } else { $null }
                type         = 'album'  # Assuming all are albums as per query
                cover_url    = $coverUrl  # Cover Art Archive URL
                url          = if ($release.id) { "https://musicbrainz.org/release/$($release.id)" } else { $null }
                artists      = if (Get-IfExists $release 'artist-credit') { 
                                    @($release.'artist-credit' | ForEach-Object { if (Get-IfExists $_ 'name') { [PSCustomObject]@{ name = $_.name } } }) 
                                } else { @() }
            }




        }
        
        # Sort by year (newest first), then by title
        return $normalizedReleases | Sort-Object -Property @{Expression = { $_.year }; Descending = $true }, title
    }
    catch {
        Write-Warning "MusicBrainz get artist albums failed: $_"
        return @()
    }
}

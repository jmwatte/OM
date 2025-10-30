function Get-DArtistAlbums {
    <#
    .SYNOPSIS
    Get albums/releases for a Discogs artist.
    
    .DESCRIPTION
    Retrieves the list of releases (albums) for a given Discogs artist ID.
    Handles pagination automatically.
    
    .PARAMETER ArtistId
    The Discogs artist ID (numeric).
    
    .PARAMETER Album
    For compatibility with Spotify API pattern. Only 'Album' is supported.
    
    .EXAMPLE
    Get-DArtistAlbums -Id 45467
    Gets all releases for Pink Floyd (artist ID 45467).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ArtistId,
        [Parameter(Mandatory = $false)]
        [string]$ArtistName,
        [Parameter(Mandatory = $false)]
        [ValidateSet('Album')]
        [string]$AlbumName = 'Album',

        [Parameter(Mandatory = $false)]
        [switch]$MastersOnly,  # DEFAULT: Only get master releases (canonical versions) - reduces duplicates

        [Parameter(Mandatory = $false)]
        [switch]$IncludeSingles,  # Include singles

        [Parameter(Mandatory = $false)]
        [switch]$IncludeCompilations,  # Include compilations

        [Parameter(Mandatory = $false)]
        [switch]$IncludeAppearances  # Include guest appearances
    )

    try {
        $allReleases = @()
        $page = 1
        $perPage = 100  # Maximum per page
        
        do {
            Write-Verbose "Fetching Discogs artist releases page $page..."
            
            # Get releases page
            $response = Invoke-DiscogsRequest -Uri "/artists/$ArtistId/releases?page=$page&per_page=$perPage&sort=year&sort_order=asc"

            if ($response.releases) {
                foreach ($release in $response.releases) {
                    # Apply filters based on parameters
                    $includeRelease = $true
                    
                    # Check role - skip appearances unless requested
                    if ($release.PSObject.Properties['role'] -and $release.role -ne 'Main' -and -not $IncludeAppearances) {
                        Write-Verbose "Skipping appearance: $($release.title)"
                        $includeRelease = $false
                    }
                    
                    # Check type - filter singles, compilations, etc.
                    if ($release.PSObject.Properties['type'] -and $release.type) {
                        $releaseType = $release.type.ToLower()
                        
                        # Skip singles unless requested
                        if ($releaseType -match 'single' -and -not $IncludeSingles) {
                            Write-Verbose "Skipping single: $($release.title)"
                            $includeRelease = $false
                        }
                        
                        # Skip compilations unless requested
                        if ($releaseType -match 'compilation' -and -not $IncludeCompilations) {
                            Write-Verbose "Skipping compilation: $($release.title)"
                            $includeRelease = $false
                        }
                        
                        # If MastersOnly=false, skip master releases
                        if (-not $MastersOnly -and $releaseType -eq 'master') {
                            Write-Verbose "Skipping master release: $($release.title)"
                            $includeRelease = $false
                        }
                        if ($MastersOnly -and $releaseType -ne 'master') {
                            Write-Verbose "Skipping non-master release: $($release.title)"
                            $includeRelease = $false
                        }

                    }
                    
                    if ($includeRelease) {
                        $releaseUri = $release.resource_url
                        Write-Host "Fetching release details for track count from $releaseUri" -ForegroundColor DarkGray
                        Start-Sleep -Milliseconds 850
                        $releaseDetails = Invoke-DiscogsRequest -Uri $releaseUri -Method 'GET'
                        $trackCount = $releaseDetails.tracklist.Count
                    

                        # Transform to match Spotify-like structure
                        # Handle optional properties that may not be present
                        $albumObj = [PSCustomObject]@{
                            name         = if ($release.PSObject.Properties['title']) { $release.title } else { "Unknown Album" }
                            id           = if ($release.type -eq 'master') { "m$($release.id)" } else { "r$($release.id)" }
                            release_date = if ($release.PSObject.Properties['year']) { $release.year } else { "" }
                            type         = if ($release.PSObject.Properties['type']) { $release.type } else { "release" }
                            artist       = if ($release.PSObject.Properties['artist']) { $release.artist } else { "" }
                            format       = if ($release.PSObject.Properties['format']) { $release.format } else { "" }
                            label        = if ($release.PSObject.Properties['label']) { $release.label } else { "" }
                            genres       = if ($release.PSObject.Properties['genre']) { @($release.genre) } else { @() }
                            resource_url = if ($release.PSObject.Properties['resource_url']) { $release.resource_url } else { "" }
                            track_count  = $trackCount
                            thumb        = if ($releaseDetails.PSObject.Properties['thumb']) { $releaseDetails.thumb } else { "" }
                            # artist       = if ($result.PSObject.Properties['user_data']) { 
                            #     # Extract artist from title
                            #     if ($result.title -match '^\s*(.+?)\s*[-–]\s*') { $matches[1].Trim() } else { $ArtistName }
                            # }
                            # else { 
                            #     $ArtistName 
                            # }
                        }
                        
                        $allReleases += $albumObj
                    }
                }
            }
            
            # Check if there are more pages
            if ($response.pagination) {
                $totalPages = $response.pagination.pages
                Write-Verbose "Page $page of $totalPages"
                
                if ($page -ge $totalPages) {
                    break
                }
            }
            else {
                break
            }
            
            $page++
            Start-Sleep -Milliseconds 550  # Small delay between requests
            write-Host "Fetching next page $page..." -ForegroundColor DarkGray
        } while ($true)
        
        Write-Verbose "Found $($allReleases.Count) releases for artist $ArtistId"
        return $allReleases
    }
    catch {
        Write-Warning "Failed to get Discogs artist albums: $_"
        return @()
    }
}

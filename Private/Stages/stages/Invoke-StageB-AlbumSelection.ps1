function Invoke-StageB-AlbumSelection {
    <#
    .SYNOPSIS
        Stage B: Album selection for Start-OM workflow.
    
    .DESCRIPTION
        Handles album search, selection, and navigation. Supports:
        - Smart search with fallback to full album list
        - Pagination and filtering
        - Multi-album selection and combination
        - Provider switching
        - Discogs masters-only toggle
        - ID-based direct selection
    
    .PARAMETER Provider
        Music metadata provider (Spotify, Qobuz, Discogs).
    
    .PARAMETER ProviderArtist
        Artist object from provider API.
    
    .PARAMETER AlbumName
        Local album folder name for matching.
    
    .PARAMETER Year
        Year from local album folder (optional).
    
    .PARAMETER CachedAlbums
        Previously fetched album list to avoid re-fetching.
    
    .PARAMETER CachedArtistId
        ID of artist for cached albums.
    
    .PARAMETER NormalizeDiscogsId
        Scriptblock to normalize Discogs IDs (strip brackets, resolve masters).
    
    .PARAMETER Artist
        Original artist name from folder.
    
    .PARAMETER NonInteractive
        Skip interactive prompts (auto-select first album).
    
    .PARAMETER AutoSelect
        Automatically select first album without prompting.
    
    .PARAMETER AlbumId
        Specific album ID to select directly.
    
    .PARAMETER GoB
        Auto-select first album (from workflow flags).

    .PARAMETER FetchAlbums
        if true fetch albums from provider even if cached albums exist (default false)
    .OUTPUTS
        Hashtable with:
        - NextStage: 'A', 'C', or 'Skip'
        - SelectedAlbum: Album object or $null
        - UpdatedCache: Album list for caching
        - UpdatedCachedArtistId: Artist ID for cache validation
        - UpdatedProvider: Provider (if changed)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Provider,
        
        [Parameter(Mandatory)]
        [object]$ProviderArtist,
        
        [Parameter(Mandatory)]
        [string]$AlbumName,
        
        [Parameter()]
        [string]$Year,
        
        [Parameter()]
        [array]$CachedAlbums,
        
        [Parameter()]
        [string]$CachedArtistId,
        
        [Parameter(Mandatory)]
        [scriptblock]$NormalizeDiscogsId,
        
        [Parameter()]
        [string]$Artist,
        
        [Parameter()]
        [switch]$NonInteractive,
        
        [Parameter()]
        [switch]$AutoSelect,
        
        [Parameter()]
        [string]$AlbumId,
        
        [Parameter()]
        [switch]$GoB,
        
        [Parameter()]
        [scriptblock]$ShowHeader,
        [Parameter()]
        [int]$trackCount,
        [Parameter()]
        [switch]$FetchAlbums
    )
    
    Clear-Host
    if ($ShowHeader) {
        & $ShowHeader -Provider $Provider -Artist $Artist -AlbumName $AlbumName -trackCount $trackCount
    }
    
    # Initialize pagination
    $page = 1
    $pageSize = 25
    $mastersOnlyMode = $true  # Default for Discogs
    $albumsForArtist = @($CachedAlbums)



if($FetchAlbums)
{
    Write-Host "Fetching albums from provider: $Provider"
    # Enhance artist with full details (including genres) if needed
    if ($Provider -eq 'Spotify' -and $ProviderArtist -and $ProviderArtist.id) {
        if (-not $ProviderArtist.genres -or $ProviderArtist.genres.Count -eq 0) {
            Write-Verbose "Fetching full artist details with genres for $($ProviderArtist.name)..."
            $fullArtist = Invoke-ProviderGetArtist -Provider $Provider -ArtistId $ProviderArtist.id
            if ($fullArtist) {
                $ProviderArtist = $fullArtist
            }
        }
    }
    
    Write-Host "Original Artist: $Artist" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Searching for albums for artist: $($ProviderArtist.name) (id: $($ProviderArtist.id))"
    
    # Clear cache if artist changed
    if ($CachedArtistId -ne $ProviderArtist.id) {
        $CachedAlbums = $null
        $CachedArtistId = $ProviderArtist.id
    }
    
    # Try smart API search FIRST (fast, targeted results)
    Write-Host "Searching for albums matching: $AlbumName..." -ForegroundColor Cyan
    Write-Verbose "Trying smart search for: $AlbumName"
    Write-Verbose "Parameters: Provider=$Provider, ArtistId=$($ProviderArtist.id), ArtistName=$($ProviderArtist.name), AlbumName=$AlbumName, MastersOnly=$($Provider -eq 'Discogs'), CacheProvided=$($null -ne $CachedAlbums)"
    
    try { 
        $searchAlbumsParams = @{
            Provider       = $Provider
            ArtistId       = $ProviderArtist.id
            ArtistName     = $ProviderArtist.name
            AlbumName      = $AlbumName
            MastersOnly    = ($Provider -eq 'Discogs')
            AllAlbumsCache = $CachedAlbums
        }

        $albumsForArtist = Invoke-ProviderSearchAlbums @searchAlbumsParams
        $albumsForArtist = @($albumsForArtist)  # Ensure array
        
        Write-Verbose "Smart search returned: $($albumsForArtist.Count) albums"
        if ($albumsForArtist.Count -gt 0) {
            Write-Host "✓ Found $($albumsForArtist.Count) albums via smart search" -ForegroundColor Green
        } else {
            Write-Verbose "Smart search returned 0 albums - will fall back to fetching all"
        }
    } catch { 
        Write-Warning "Smart search exception: $_"
        Write-Verbose "Exception details: $($_.Exception.Message)"
        $albumsForArtist = @() 
    }
    
    # If smart search returned nothing, fetch all albums as fallback
    if (-not $albumsForArtist -or $albumsForArtist.Count -eq 0) {
        if (-not $CachedAlbums) {
            Write-Host "Smart search returned no results, fetching all albums (this may take a while)..." -ForegroundColor Yellow
            Write-Verbose "Fetching all albums for artist..."
            try { 
                $CachedAlbums = Invoke-ProviderGetAlbums -Provider $Provider -ArtistId $ProviderArtist.id -AlbumType 'Album'
                $CachedAlbums = @($CachedAlbums)  # Ensure array
                Write-Host "✓ Fetched $($CachedAlbums.Count) albums" -ForegroundColor Green
            } catch { 
                Write-Warning "Failed to fetch artist albums: $_"
                $CachedAlbums = @() 
            }
        }
        
        Write-Verbose "Using all cached albums ($($CachedAlbums.Count) albums)"
        $albumsForArtist = $CachedAlbums
    }
    
    # Normalize to array so .Count works reliably
    $albumsForArtist = @($albumsForArtist)
    
    # Handle no albums found
    if (-not $albumsForArtist -or $albumsForArtist.Count -eq 0) {
        Write-Host "No albums found for artist id $($ProviderArtist.id)."
        
        if ($NonInteractive) {
            Write-Warning "NonInteractive: skipping album because no albums found for artist id $($ProviderArtist.id)."
            return @{
                NextStage = 'Skip'
                SelectedAlbum = $null
                UpdatedCache = $CachedAlbums
                UpdatedCachedArtistId = $CachedArtistId
                UpdatedProvider = $Provider
            }
        }
    
        $inputF = Read-Host "Enter '(b)ack', '(s)kip', 'id:<id>' or album name to filter"
        switch -Regex ($inputF) {
            '^b$' {
                return @{
                    NextStage = 'A'
                    SelectedAlbum = $null
                    UpdatedCache = $CachedAlbums
                    UpdatedCachedArtistId = $CachedArtistId
                    UpdatedProvider = $Provider
                }
            }
            '^s$' {
                return @{
                    NextStage = 'Skip'
                    SelectedAlbum = $null
                    UpdatedCache = $CachedAlbums
                    UpdatedCachedArtistId = $CachedArtistId
                    UpdatedProvider = $Provider
                }
            }
            '^id:.*' {
                $id = $inputF.Substring(3)
                if ($Provider -eq 'Discogs') { $id = & $NormalizeDiscogsId $id }
                return @{
                    NextStage = 'C'
                    SelectedAlbum = @{ id = $id; name = $id }
                    UpdatedCache = $CachedAlbums
                    UpdatedCachedArtistId = $CachedArtistId
                    UpdatedProvider = $Provider
                }
            }
            default {
                if ($inputF) {
                    # New artist search
                    return @{
                        NextStage = 'A'
                        SelectedAlbum = $null
                        UpdatedCache = $CachedAlbums
                        UpdatedCachedArtistId = $CachedArtistId
                        UpdatedProvider = $Provider
                        NewArtistQuery = $inputF
                    }
                }
                # Empty input, stay in loop (should not reach here)
                return @{
                    NextStage = 'B'
                    SelectedAlbum = $null
                    UpdatedCache = $CachedAlbums
                    UpdatedCachedArtistId = $CachedArtistId
                    UpdatedProvider = $Provider
                }
            }
        }
    }
    
    Clear-Host
    
    # Sort by Jaccard similarity descending
    $albumsForArtist = $albumsForArtist | Sort-Object { - (Get-StringSimilarity-Jaccard -String1 $AlbumName -String2 $_.Name) }




}

$CachedAlbums=$albumsForArtist


    # Main album selection loop
    while ($true) {
        Clear-Host
        if ($ShowHeader) {
            & $ShowHeader -Provider $Provider -Artist $Artist -AlbumName $AlbumName -trackCount $trackCount
        }
        
        # Show filter mode indicator for Discogs
        if ($Provider -eq 'Discogs') {
            $modeIndicator = if ($mastersOnlyMode) { 
                "[Filter: MASTERS ONLY - type '*' to include all releases]" 
            } else { 
                "[Filter: ALL RELEASES - type '*' for masters only]" 
            }
            Write-Host $modeIndicator -ForegroundColor Yellow
        }
        
        
    Write-Host "$Provider Albums for artist $($ProviderArtist.name):"
        Write-Host "for local album: $($AlbumName) (year: $Year)"
        
        
        $totalPages = [math]::Ceiling($albumsForArtist.Count / $pageSize)
        $startIdx = ($page - 1) * $pageSize
        $endIdx = [math]::Min($startIdx + $pageSize - 1, $albumsForArtist.Count - 1)

        for ($i = $startIdx; $i -le $endIdx; $i++) {
 $album = $albumsForArtist[$i]
            $trackInfo = ""
            if ($album.PSObject.Properties.Match('total_tracks')) {
                $trackInfo = " ($($album.total_tracks) tracks)"
            } elseif ($album.PSObject.Properties.Match('track_count')) {
                $trackInfo = " ($($album.track_count) tracks)"
            } elseif ($album.PSObject.Properties.Match('tracks_count')) {
                $trackInfo = " ($($album.tracks_count) tracks)"
            }
            Write-Host "[$($i+1)] $($album.name)  (id: $($album.id)) (year: $($album.release_date))$trackInfo"
       }

        # Non-interactive album selection
        if ($AlbumId) {
            return @{
                NextStage = 'C'
                SelectedAlbum = @{ id = $AlbumId; name = $AlbumId }
                UpdatedCache = $CachedAlbums
                UpdatedCachedArtistId = $CachedArtistId
                UpdatedProvider = $Provider
            }
        }
        if ($GoB) {
            return @{
                NextStage = 'C'
                SelectedAlbum = $albumsForArtist[0]
                UpdatedCache = $CachedAlbums
                UpdatedCachedArtistId = $CachedArtistId
                UpdatedProvider = $Provider
            }
        }
        if ($AutoSelect -or $NonInteractive) {
            return @{
                NextStage = 'C'
                SelectedAlbum = $albumsForArtist[0]
                UpdatedCache = $CachedAlbums
                UpdatedCachedArtistId = $CachedArtistId
                UpdatedProvider = $Provider
            }
        }

        $inputF = Read-Host "Select album(s) [1] (Enter=first), number(s) (e.g., 1,3,5-8), '(b)ack', '(n)ext', '(p)rev', '(s)kip', 'id:<id>', '(cp)' change provider [$Provider], '*' (all albums), or text to search:"
        
        switch -Regex ($inputF) {
             '^s$' {
                return @{
                    NextStage = 'Skip'
                    SelectedAlbum = $null
                    UpdatedCache = $CachedAlbums
                    UpdatedCachedArtistId = $CachedArtistId
                    UpdatedProvider = $Provider
                }
            }
            '^n$' {
                if ($page -lt $totalPages) { $page++ }
                continue
            }
            '^p$' {
                if ($page -gt 1) { $page-- }
                continue
            }
            'cp' {
                Write-Host "`nCurrent provider: $Provider" -ForegroundColor Cyan
                Write-Host "Available providers: (S)potify, (Q)obuz, (D)iscogs, (M)usicBrainz" -ForegroundColor Gray
                $newProvider = Read-Host "Enter provider (full name or first letter)"
                $providerMap = @{ 's' = 'Spotify'; 'q' = 'Qobuz'; 'd' = 'Discogs'; 'm' = 'MusicBrainz'; 'spotify' = 'Spotify'; 'qobuz' = 'Qobuz'; 'discogs' = 'Discogs'; 'musicbrainz' = 'MusicBrainz' }
                $matched = $providerMap[$newProvider.ToLower()]
                if ($matched) {
                    $Provider = $matched
                    Write-Host "Switched to provider: $Provider" -ForegroundColor Green
                    return @{
                        NextStage = 'A'
                        SelectedAlbum = $null
                        UpdatedCache = $CachedAlbums
                        UpdatedCachedArtistId = $CachedArtistId
                        UpdatedProvider = $Provider
                    }
                } else {
                    Write-Warning "Invalid provider: $newProvider. Staying with $Provider."
                    continue
                }
            }
            '^b$' {
                return @{
                    NextStage = 'A'
                    SelectedAlbum = $null
                    UpdatedCache = $null
                    UpdatedCachedArtistId = $null
                    UpdatedProvider = $Provider
                }
            }
            '^$' {
                return @{
                    NextStage = 'C'
                    SelectedAlbum = $albumsForArtist[0]
                    UpdatedCache = $CachedAlbums
                    UpdatedCachedArtistId = $CachedArtistId
                    UpdatedProvider = $Provider
                }
            }
            '^id:(.+)$' {
                $id = $matches[1].Trim()
                if ($Provider -eq 'Discogs') { $id = & $NormalizeDiscogsId $id }
                 if ($Provider -eq 'MusicBrainz') {
                    Write-Host "Fetching MusicBrainz release information..." -ForegroundColor Cyan
                    try {
                        $release = Invoke-MusicBrainzRequest -Endpoint 'release' -Id $id -Inc 'artist-credits'
                        if ($release) {
                            $selectedAlbum = @{
                                id = $id
                                name = if (Get-IfExists $release 'title') { $release.title } else { $id }
                                release_date = if (Get-IfExists $release 'date') { $release.date } else { $null }
                            }
                            Write-Host "✓ Found release: $($selectedAlbum.name)" -ForegroundColor Green
                        } else {
                            Write-Warning "Could not fetch release information for ID: $id"
                        }
                    } catch {
                        Write-Warning "Failed to fetch MusicBrainz release information: $_"
                    }
                }
                return @{
                    NextStage = 'C'
                    SelectedAlbum = @{ id = $id; name = $id }
                    UpdatedCache = $CachedAlbums
                    UpdatedCachedArtistId = $CachedArtistId
                    UpdatedProvider = $Provider
                }
            }
            '^\*$' {
                # Toggle between Masters-only and All-releases for Discogs
                if ($Provider -eq 'Discogs') {
                    $mastersOnlyMode = -not $mastersOnlyMode
                    $modeText = if ($mastersOnlyMode) { "MASTER releases only" } else { "ALL release types" }
                    Write-Host "`nToggling to: $modeText" -ForegroundColor Yellow
                    Write-Host "Fetching albums..." -ForegroundColor Cyan
                } else {
                    Write-Host "Fetching all albums for artist..." -ForegroundColor Cyan
                }
                
                try {
                    $fetchParams = @{
                        Provider = $Provider
                        ArtistId = $ProviderArtist.id
                        AlbumType = 'Album'
                    }
                    
                    # Add MastersOnly parameter for Discogs
                    if ($Provider -eq 'Discogs') {
                        $fetchParams['MastersOnly'] = $mastersOnlyMode
                    }
                    
                    $albumsForArtist = Invoke-ProviderGetAlbums @fetchParams
                    $albumsForArtist = @($albumsForArtist)
                    $albumsForArtist = $albumsForArtist | Sort-Object { - (Get-StringSimilarity-Jaccard -String1 $AlbumName -String2 $_.Name) }
                    $CachedAlbums = $albumsForArtist
                    $page = 1
                    
                    $statusMsg = if ($Provider -eq 'Discogs') {
                        "✓ Loaded $($albumsForArtist.Count) albums [$modeText]"
                    } else {
                        "✓ Loaded $($albumsForArtist.Count) albums"
                    }
                    Write-Host $statusMsg -ForegroundColor Green
                } catch {
                    Write-Warning "Failed to fetch all albums: $_"
                }
                continue
            }
            '^[\d,\-\s]+$' {
                # Parse multi-selection: "1,3,5-8,12"
                $selectedIndices = @()
                $parts = $inputF -split ','
                foreach ($part in $parts) {
                    $part = $part.Trim()
                    if ($part -match '^(\d+)-(\d+)$') {
                        # Range: 5-8
                        $start = [int]$matches[1]
                        $end = [int]$matches[2]
                        $selectedIndices += $start..$end
                    } elseif ($part -match '^\d+$') {
                        # Single number: 3
                        $selectedIndices += [int]$part
                    }
                }
                
                # Validate all indices
                $validIndices = @(
                    $selectedIndices |
                        Where-Object { $_ -ge 1 -and $_ -le $albumsForArtist.Count } |
                        Select-Object -Unique |
                        Sort-Object
                )
                
                if ($validIndices.Count -eq 0) {
                    Write-Warning "No valid album numbers selected"
                    continue
                }
                
                # If single selection, check if it's a Discogs master that needs resolution
                if ($validIndices.Count -eq 1) {
                    $selectedAlbum = $albumsForArtist[$validIndices[0] - 1]
                    
                    # For Discogs masters: fetch releases and let user choose
                    if ($Provider -eq 'Discogs' -and (Get-IfExists $selectedAlbum 'type') -eq 'master') {
                        Write-Host "`n📀 Selected album is a Discogs MASTER - fetching releases..." -ForegroundColor Yellow
                        
                        try {
                            $masterVersions = Invoke-DiscogsRequest -Uri "/masters/$($selectedAlbum.id)/versions?per_page=50"
                            
                            if ($masterVersions -and (Get-IfExists $masterVersions 'versions') -and $masterVersions.versions.Count -gt 0) {
                                $releases = $masterVersions.versions
                                Write-Host "Found $($releases.Count) releases for this master:`n" -ForegroundColor Cyan
                                
                                for ($i = 0; $i -lt [Math]::Min(20, $releases.Count); $i++) {
                                    $rel = $releases[$i]
                                    $country = if (Get-IfExists $rel 'country') { " [$($rel.country)]" } else { "" }
                                    $format = if (Get-IfExists $rel 'format') { " - $($rel.format)" } else { "" }
                                    $label = if (Get-IfExists $rel 'label') { " ($($rel.label))" } else { "" }
                                    Write-Host "[$($i+1)] $($rel.title)$country$format$label" -ForegroundColor Gray
                                }
                                
                                if ($releases.Count -gt 20) {
                                    Write-Host "... and $($releases.Count - 20) more" -ForegroundColor DarkGray
                                }
                                
                                $relInput = Read-Host "`nSelect release [1-$($releases.Count)], [0] for main_release, or Enter for #1"
                                
                                $selectedRelease = $null
                                if ($relInput -eq '') {
                                    $selectedRelease = $releases[0]
                                } elseif ($relInput -eq '0' -or $relInput -eq 'main') {
                                    # Fetch master details to get main_release
                                    try {
                                        $masterDetails = Invoke-DiscogsRequest -Uri "/masters/$($selectedAlbum.id)"
                                        if ($masterDetails -and (Get-IfExists $masterDetails 'main_release')) {
                                            $mainReleaseId = [string]$masterDetails.main_release
                                            Write-Host "Using main_release: $mainReleaseId" -ForegroundColor Green
                                            # Create a minimal release object with the main_release ID
                                            $selectedRelease = @{ id = $mainReleaseId; title = $selectedAlbum.name }
                                        } else {
                                            Write-Warning "Master has no main_release, using first release"
                                            $selectedRelease = $releases[0]
                                        }
                                    } catch {
                                        Write-Warning "Failed to fetch main_release: $_. Using first release."
                                        $selectedRelease = $releases[0]
                                    }
                                } elseif ($relInput -match '^\d+$') {
                                    $idx = [int]$relInput
                                    if ($idx -ge 1 -and $idx -le $releases.Count) {
                                        $selectedRelease = $releases[$idx - 1]
                                    } else {
                                        Write-Warning "Invalid selection, using first release"
                                        $selectedRelease = $releases[0]
                                    }
                                } else {
                                    Write-Warning "Invalid input, using first release"
                                    $selectedRelease = $releases[0]
                                }
                                
                                # Return the selected release instead of the master
                                Write-Host "✓ Selected release: $($selectedRelease.id) - $($selectedRelease.title)" -ForegroundColor Green
                                return @{
                                    NextStage = 'C'
                                    SelectedAlbum = @{
                                        id = [string]$selectedRelease.id
                                        name = $selectedRelease.title
                                        type = 'release'  # Mark as release, not master
                                        _resolvedFromMaster = $selectedAlbum.id
                                        _masterReleases = $releases  # Store releases for potential retry
                                        _masterName = $selectedAlbum.name
                                    }
                                    UpdatedCache = $CachedAlbums
                                    UpdatedCachedArtistId = $CachedArtistId
                                    UpdatedProvider = $Provider
                                }
                            } else {
                                Write-Warning "No releases found for master $($selectedAlbum.id), attempting to use master ID directly"
                            }
                        } catch {
                            Write-Warning "Failed to fetch releases for master: $_. Will attempt to use master ID."
                        }
                    }
                    
                    # Normal path: return selected album (non-master or master resolution failed)
                    return @{
                        NextStage = 'C'
                        SelectedAlbum = $selectedAlbum
                        UpdatedCache = $CachedAlbums
                        UpdatedCachedArtistId = $CachedArtistId
                        UpdatedProvider = $Provider
                    }
                }
                
                # Multiple selections: combine all albums into one bucket
                Write-Host "`nFetching tracks from $($validIndices.Count) selected albums..." -ForegroundColor Cyan
                
                $combinedTracks = @()
                $albumNames = @()
                $failedAlbums = 0
                
                foreach ($idx in $validIndices) {
                    $currentAlbum = $albumsForArtist[$idx - 1]
                    $albumNames += $currentAlbum.name
                    
                    Write-Host "  [$idx] Fetching: $($currentAlbum.name)..." -ForegroundColor Gray
                    
                    try {
                        $tracks = Invoke-ProviderGetTracks -Provider $Provider -AlbumId $currentAlbum.id
                        if ($tracks) {
                            $combinedTracks += $tracks
                            Write-Host "    ✓ Added $($tracks.Count) tracks" -ForegroundColor Green
                        } else {
                            Write-Warning "    ✗ No tracks returned for album: $($currentAlbum.name)"
                            $failedAlbums++
                        }
                    }
                    catch {
                        Write-Warning "    ✗ Failed to fetch tracks for album: $($currentAlbum.name) - $_"
                        $failedAlbums++
                    }
                }
                
                if ($combinedTracks.Count -eq 0) {
                    Write-Warning "No tracks retrieved from any selected albums. Please try again."
                    continue
                }
                
                # Create a synthetic combined album object
                $firstAlbum = $albumsForArtist[$validIndices[0] - 1]
                $combinedAlbum = [PSCustomObject]@{
                    id = "combined_$($validIndices -join '_')"
                    name = if ($validIndices.Count -eq 2) { 
                        "$($albumNames[0]) + $($albumNames[1])" 
                    } else { 
                        "$($albumNames[0]) + $($validIndices.Count - 1) more albums" 
                    }
                    release_date = $firstAlbum.release_date
                     track_count = $combinedTracks.Count
                    _isCombined = $true
                    _albumCount = $validIndices.Count
                    _albumNames = $albumNames
                    _selectedIndices = $validIndices
                    _tracks = $combinedTracks
                }
                
                Write-Host "`n✓ Combined $($combinedTracks.Count) tracks from $($validIndices.Count) albums" -ForegroundColor Green
                if ($failedAlbums -gt 0) {
                    Write-Warning "  Note: $failedAlbums album(s) failed to load"
                }
                
                return @{
                    NextStage = 'C'
                    SelectedAlbum = $combinedAlbum
                    UpdatedCache = $CachedAlbums
                    UpdatedCachedArtistId = $CachedArtistId
                    UpdatedProvider = $Provider
                }
            }
            default {
                # User entered text - try as a new search term first
                Write-Host "Searching for albums matching: '$inputF'..." -ForegroundColor Cyan
                try {
                    $searchParams = @{
                        Provider    = $Provider
                        ArtistId    = $ProviderArtist.id
                        ArtistName  = $ProviderArtist.name
                        AlbumName   = $inputF
                    }
                    
                    # Add MastersOnly parameter for Discogs, respecting toggle state
                    if ($Provider -eq 'Discogs') {
                        $searchParams['MastersOnly'] = $mastersOnlyMode
                    }

                    $searchResults = Invoke-ProviderSearchAlbums @searchParams
                    
                    # Normalize to array before checking Count
                    $searchResults = @($searchResults)
                    
                    if ($searchResults -and $searchResults.Count -gt 0) {
                        $albumsForArtist = $searchResults
                        # Wrap Sort-Object result to ensure it stays an array (single results can be unwrapped)
                        $albumsForArtist = @($albumsForArtist | Sort-Object { - (Get-StringSimilarity-Jaccard -String1 $inputF -String2 $_.name) })
                        $CachedAlbums = $albumsForArtist
                        $page = 1
                        Write-Host "Found $($albumsForArtist.Count) albums matching '$inputF'" -ForegroundColor Green
                        continue
                    }
                } catch {
                    Write-Verbose "Search failed: $_"
                }
                
                # Fallback to local filtering if search failed or returned no results
                $filtered = @($albumsForArtist | Where-Object { $_.name -like "*$inputF*" })
                if ($filtered.Count -gt 0) {
                    $albumsForArtist = $filtered
                    $page = 1
                    Write-Host "Filtered to $($filtered.Count) albums" -ForegroundColor Green
                    continue
                }
                else {
                    Write-Warning "No matches found for '$inputF'"
                    continue
                }
            }
        }
    }
}

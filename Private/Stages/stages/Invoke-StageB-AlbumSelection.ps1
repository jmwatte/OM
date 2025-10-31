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
        [switch]$FetchAlbums,

        [Parameter()]
        [int]$Page = 1,

        [Parameter()]
        [ValidateRange(1, 100)]
        [int]$PerPage = 10,

        [Parameter()]
        [int]$MaxResults = 10,

        [Parameter()]
        [int]$CurrentPage = 1
    )
    
    Clear-Host
    if ($ShowHeader) {
        & $ShowHeader -Provider $Provider -Artist $script:artist -AlbumName $script:albumName -trackCount $script:trackCount
    }
    
    # Initialize pagination
    $currentPage = $CurrentPage
    $pageSize = $PerPage  # Use PerPage for display pagination
    $maxResults = $MaxResults
    $mastersOnlyMode = $true  # Default for Discogs
    $albumsForArtist = @($CachedAlbums) | Where-Object {$_ -ne $null}  # Ensure array



    if ($FetchAlbums) {
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
                Page           = $currentPage
                PerPage        = $pageSize
                MaxResults     = $maxResults
            }

            $albumsForArtist = Invoke-ProviderSearchAlbums @searchAlbumsParams
            $albumsForArtist = @($albumsForArtist) | Where-Object {$_ -ne $null}  # Ensure array
        
            Write-Verbose "Smart search returned: $($albumsForArtist.Count) albums"
            if ($albumsForArtist.Count -gt 0) {
                Write-Host "✓ Found $($albumsForArtist.Count) albums via smart search" -ForegroundColor Green
            }
            else {
                Write-Verbose "Smart search returned 0 albums - will fall back to fetching all"
            }
        }
        catch { 
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
                    $CachedAlbums = @($CachedAlbums) |Where-Object {$_ -ne $null}
                     # Ensure array
                    Write-Host "✓ Fetched $($CachedAlbums.Count) albums" -ForegroundColor Green
                }
                catch { 
                    Write-Warning "Failed to fetch artist albums: $_"
                    $CachedAlbums = @() 
                }
            }
        
            Write-Verbose "Using all cached albums ($($CachedAlbums.Count) albums)"
            if ($null -eq $CachedAlbums -or $CachedAlbums.Count -eq 0) {
                Write-Verbose "Cache is empty or has no items (Count: $($CachedAlbums.Count))"
                Write-Verbose "Cache type: $(if ($null -ne $CachedAlbums) { $CachedAlbums.GetType().FullName } else { 'null' })"
                $albumsForArtist = @()
            }
            else {
                Write-Verbose "Cache contents first item: $(if ($CachedAlbums[0]) { $CachedAlbums[0] | ConvertTo-Json -Compress } else { 'null' })"
                $albumsForArtist = $CachedAlbums
            }
            
            # Filter to most likely matches based on album title similarity
            if ($null -ne $albumsForArtist -and $albumsForArtist.Count -gt 0) {
                Write-Host "Filtering albums by similarity to '$AlbumName'..." -ForegroundColor Cyan
                Write-Verbose "Albums before filtering: $($albumsForArtist.Count)"
                # wait till usere input a key
                # Read-Host "Press Enter to continue..."
                # Normalize to array so .Count works reliably
                $albumsForArtist = @($albumsForArtist)

                # Diagnostic: log count and a sample of types
                
                # Write-Verbose("album1 is $($albumsForArtist[0].GetType().FullName)")
                # Diagnostic: log count and a sample of types
                # Diagnostic: log count and a sample of types
                Write-Verbose ("Albums fetched: {0}" -f $albumsForArtist.Count)
                
                # Add more defensive checks for type information
                if ($null -ne $albumsForArtist -and $albumsForArtist.Count -gt 0) {
                    $typeInfo = @()
                    foreach ($album in ($albumsForArtist | Select-Object -First 10)) {
                        if ($null -ne $album) {
                            try {
                                $typeInfo += $album.GetType().FullName
                            }
                            catch {
                                $typeInfo += "Unable to get type: $($Error[0].Exception.Message)"
                            }
                        }
                        else {
                            $typeInfo += "null"
                        }
                    }
                    
                    if ($typeInfo.Count -gt 0) {
                        Write-Verbose ("Album item types (first 10): {0}" -f ($typeInfo -join ', '))
                    }
                    else {
                        Write-Verbose "No valid album types found in the first 10 items"
                    }
                    
                    # Add debug information about the first album
                    if ($null -ne $albumsForArtist[0]) {
                        Write-Verbose "First album content: $($albumsForArtist[0] | ConvertTo-Json -Depth 1 -Compress)"
                    }
                } 
                else {
                    Write-Verbose "No albums or empty album array to check types"
                }

                # Calculate similarity scores and filter
                # Calculate similarity scores and filter
                $albumsWithSimilarity = @()
                foreach ($candidate in $albumsForArtist) {
                    # Use Get-IfExists to safely read 'name'
                    $cName = Get-IfExists -target $candidate -path 'name'
                    if (-not $cName) {
                        Write-Verbose ("Skipping album item without 'name' property. Type: {0}. Value: {1}" -f ($candidate.GetType().FullName), ($candidate | ConvertTo-Json -Depth 2 -ErrorAction SilentlyContinue))
                        continue
                    }

                    # Optionally trim HTML or decode entities if needed
                    $cName = $cName.ToString().Trim()

                    $similarity = Get-StringSimilarity-Jaccard -String1 $AlbumName -String2 $cName
                    $albumsWithSimilarity += [PSCustomObject]@{
                        Album      = $candidate
                        Similarity = $similarity
                    }
                }
                
                # Filter to albums with similarity >= 0.3 or top 20 most similar (whichever is larger)
                $minSimilarity = 0.3
                $maxResults = 20
                write-host "----> $($albumsForArtist[0])"
                $filteredAlbums = @(
                    $albumsWithSimilarity | 
                    Where-Object { $_.Similarity -ge $minSimilarity } | 
                    Sort-Object -Property Similarity -Descending
                )
                
                # If we have fewer than maxResults with minSimilarity, add more from the top
                if ($filteredAlbums.Count -lt $maxResults) {
                    $topAlbums = @(
                        $albumsWithSimilarity | 
                        Sort-Object -Property Similarity -Descending | 
                        Select-Object -First $maxResults
                    )
                    $filteredAlbums = @($topAlbums)
                }
                
                $albumsForArtist = @($filteredAlbums | ForEach-Object { $_.Album })
                
                if ($albumsForArtist.Count -gt 0) {
                    Write-Host "✓ Filtered to $($albumsForArtist.Count) most similar albums" -ForegroundColor Green
                }
                else {
                    Write-Warning "No albums found with sufficient similarity to '$AlbumName'"
                }
            }
        }
    
        # Normalize to array so .Count works reliably
        $albumsForArtist = @($albumsForArtist)
   
        # Handle no albums found
        if ($null -eq $albumsForArtist -or $albumsForArtist.Count -eq 0) {
            Write-Verbose "No albums found - albumsForArtist is $(if ($null -eq $albumsForArtist) { 'null' } else { 'empty array' })"
            Write-Host "No albums found for artist id $($ProviderArtist.id)."
        
            if ($NonInteractive) {
                Write-Warning "NonInteractive: skipping album because no albums found for artist id $($ProviderArtist.id)."
                return @{
                    NextStage             = 'Skip'
                    SelectedAlbum         = $null
                    UpdatedCache          = $CachedAlbums
                    UpdatedCachedArtistId = $CachedArtistId
                    UpdatedProvider       = $Provider
                    CurrentPage           = $currentPage
                }
            }
    
            $inputF = Read-Host "Enter '(b)ack', '(s)kip', 'id:<id>' or album name to filter"
            switch -Regex ($inputF) {
                '^b$' {
                    return @{
                        NextStage             = 'A'
                        SelectedAlbum         = $null
                        UpdatedCache          = $CachedAlbums
                        UpdatedCachedArtistId = $CachedArtistId
                        UpdatedProvider       = $Provider
                        CurrentPage           = $currentPage
                    }
                }
                '^s$' {
                    return @{
                        NextStage             = 'Skip'
                        SelectedAlbum         = $null
                        UpdatedCache          = $CachedAlbums
                        UpdatedCachedArtistId = $CachedArtistId
                        UpdatedProvider       = $Provider
                        CurrentPage           = $currentPage
                    }
                }
                '^id:.*' {
                    $id = $inputF.Substring(3)
                    if ($Provider -eq 'Discogs') { $id = & $NormalizeDiscogsId $id }
                    return @{
                        NextStage             = 'C'
                        SelectedAlbum         = @{ id = $id; name = $id }
                        UpdatedCache          = $CachedAlbums
                        UpdatedCachedArtistId = $CachedArtistId
                        UpdatedProvider       = $Provider
                        CurrentPage           = $currentPage
                    }
                }
                default {
                    if ($inputF) {
                        # New artist search
                        return @{
                            NextStage             = 'A'
                            SelectedAlbum         = $null
                            UpdatedCache          = $CachedAlbums
                            UpdatedCachedArtistId = $CachedArtistId
                            UpdatedProvider       = $Provider
                            NewArtistQuery        = $inputF
                            CurrentPage           = $currentPage
                        }
                    }
                    # Empty input, stay in loop (should not reach here)
                    return @{
                        NextStage             = 'B'
                        SelectedAlbum         = $null
                        UpdatedCache          = $CachedAlbums
                        UpdatedCachedArtistId = $CachedArtistId
                        UpdatedProvider       = $Provider
                        CurrentPage           = $currentPage
                    }
                }
            }
        }
    
        Clear-Host
    
        # Sort by Jaccard similarity descending
        $albumsForArtist = $albumsForArtist | Sort-Object { - (Get-StringSimilarity-Jaccard -String1 $AlbumName -String2 $_.Name) }




    }

    $CachedAlbums = $albumsForArtist


    # Main album selection loop
    while ($true) {
        Clear-Host
        if ($ShowHeader) {
            & $ShowHeader -Provider $Provider -Artist $script:artist -AlbumName $script:albumName -trackCount $script:trackCount
        }
        
        # Show find mode indicator
        if ($script:findMode -eq 'quick') {
            Write-Host "🔍 Find Mode: Quick Album Search" -ForegroundColor Magenta
        } else {
            Write-Host "🔍 Find Mode: Artist-First Search" -ForegroundColor Magenta
        }
        Write-Host ""
        
        # Show filter mode indicator for Discogs
        if ($Provider -eq 'Discogs') {
            $modeIndicator = if ($mastersOnlyMode) { 
                "[Filter: MASTERS ONLY - type '*' to include all releases]" 
            }
            else { 
                "[Filter: ALL RELEASES - type '*' for masters only]" 
            }
            Write-Host $modeIndicator -ForegroundColor Yellow
        }
        
        
                $ThisManyAlbums = $albumsForArtist.Count
        Write-Host "$ThisManyAlbums $Provider albums for artist $($ProviderArtist.name):"
        Write-Host "for local album: $($AlbumName) (year: $Year)"
        
        
        $totalPages = [math]::Ceiling($albumsForArtist.Count / $pageSize)
        # Ensure currentPage is within valid range
        if ($currentPage -gt $totalPages) { $currentPage = $totalPages }
        if ($currentPage -lt 1) { $currentPage = 1 }
        $startIdx = ($currentPage - 1) * $pageSize
        $endIdx = [math]::Min($startIdx + $pageSize - 1, $albumsForArtist.Count - 1)

        for ($i = $startIdx; $i -le $endIdx; $i++) {
            if ($Provider -eq 'Discogs' -and -not (Get-IfExists $albumsForArtist[$i] 'track_count')) {
                Write-Host "Fetching track count for album id $($albumsForArtist[$i].id)..." -ForegroundColor DarkGray
                try {
                    $releaseDetails = Invoke-DiscogsRequest -Uri "/releases/$($albumsForArtist[$i].id)" -Method 'GET'
                    if ($releaseDetails -and (Get-IfExists $releaseDetails 'tracklist')) {
                        $trackCount = $releaseDetails.tracklist.Count
                        $albumsForArtist[$i].track_count = $trackCount
                        Write-Verbose "Updated track count: $trackCount"
                    }
                }
                catch {
                    Write-Warning "Failed to fetch release details for track count: $_"
                }
            }




            $album = $albumsForArtist[$i]
            $trackInfo = ""
            $trackCount = Get-IfExists $album 'total_tracks'
            if (-not $trackCount) { $trackCount = Get-IfExists $album 'track_count' }
            if (-not $trackCount) { $trackCount = Get-IfExists $album 'tracks_count' }
            if ($trackCount) {
                $trackInfo = " ($trackCount tracks)"
            }
            Write-Host "[$($i+1)] $($album.name)  (id: $($album.id)) (year: $($album.release_date))$trackInfo"
        }

        # Non-interactive album selection
        if ($AlbumId) {
            return @{
                NextStage             = 'C'
                SelectedAlbum         = @{ id = $AlbumId; name = $AlbumId }
                UpdatedCache          = $CachedAlbums
                UpdatedCachedArtistId = $CachedArtistId
                UpdatedProvider       = $Provider
                CurrentPage           = $currentPage
            }
        }
        if ($GoB) {
            return @{
                NextStage             = 'C'
                SelectedAlbum         = $albumsForArtist[0]
                UpdatedCache          = $CachedAlbums
                UpdatedCachedArtistId = $CachedArtistId
                UpdatedProvider       = $Provider
                CurrentPage           = $currentPage
            }
        }
        if ($AutoSelect -or $NonInteractive) {
            return @{
                NextStage             = 'C'
                SelectedAlbum         = $albumsForArtist[0]
                UpdatedCache          = $CachedAlbums
                UpdatedCachedArtistId = $CachedArtistId
                UpdatedProvider       = $Provider
                CurrentPage           = $currentPage
            }
        }

        $inputF = Read-Host "Select album(s) [1] (Enter=first), number(s) (e.g., 1,3,5-8), '(b)ack', '(n)ext', '(pr)ev', '(s)kip', 'id:<id>', '(p)rovider', 'vc(ViewCover)', 'sc(SaveCover)', 'sct(SaveCoverToTags)', '*' (all albums), or text to search:"
        
        switch -Regex ($inputF) {
            '^s$' {
                return @{
                    NextStage             = 'Skip'
                    SelectedAlbum         = $null
                    UpdatedCache          = $CachedAlbums
                    UpdatedCachedArtistId = $CachedArtistId
                    UpdatedProvider       = $Provider
                    CurrentPage           = $currentPage
                }
            }
            '^n$' {
                if ($currentPage * $pageSize -lt $albumsForArtist.Count -or $currentPage * $pageSize -lt 100) {  # Allow fetching up to 100 results
                    $currentPage++
                    
                    # If we need more results, fetch the next page
                    if ($currentPage * $pageSize -gt $albumsForArtist.Count) {
                        Write-Host "Fetching page $($currentPage)..." -ForegroundColor Cyan
                        try {
                            $searchParams = @{
                                Provider   = $Provider
                                ArtistId   = $ProviderArtist.id
                                ArtistName = $ProviderArtist.name
                                AlbumName  = $AlbumName
                                Page       = $currentPage
                                PerPage    = $pageSize
                                MaxResults = $maxResults
                            }
                            
                            # Add MastersOnly parameter for Discogs
                            if ($Provider -eq 'Discogs') {
                                $searchParams['MastersOnly'] = $mastersOnlyMode
                            }

                            $newResults = Invoke-ProviderSearchAlbums @searchParams
                            $newResults = @($newResults)
                            
                            if ($newResults -and $newResults.Count -gt 0) {
                                $albumsForArtist = $albumsForArtist + $newResults
                                Write-Host "✓ Added $($newResults.Count) more albums (total: $($albumsForArtist.Count))" -ForegroundColor Green
                            } else {
                                Write-Host "No more results available from provider." -ForegroundColor Yellow
                                $currentPage--  # Go back to previous page
                            }
                        }
                        catch {
                            Write-Warning "Failed to fetch page $($currentPage): $_"
                            $currentPage--  # Go back to previous page
                        }
                    }
                    
                    $CachedAlbums = $albumsForArtist
                    continue
                } else {
                    Write-Host "No more pages available. Use text search for different results." -ForegroundColor Yellow
                    continue
                }
            }
            '^pr$' {
                if ($currentPage -gt 1) {
                    $currentPage--
                    continue
                } else {
                    Write-Host "Already on first page." -ForegroundColor Yellow
                    continue
                }
            }
            '^p$' {
                $config = Get-OMConfig
                $defaultProvider = $config.DefaultProvider
                $newProvider = Read-Host "Current provider: $Provider`nAvailable providers: (p) default ($defaultProvider), (ps)potify, (pq)obuz, (pd)iscogs, (pm)usicbrainz`nEnter provider"
                $providerMap = @{
                    'p' = $defaultProvider
                    'ps' = 'Spotify'; 's' = 'Spotify'; 'spotify' = 'Spotify'
                    'pq' = 'Qobuz'; 'q' = 'Qobuz'; 'qobuz' = 'Qobuz'
                    'pd' = 'Discogs'; 'd' = 'Discogs'; 'discogs' = 'Discogs'
                    'pm' = 'MusicBrainz'; 'm' = 'MusicBrainz'; 'musicbrainz' = 'MusicBrainz'
                }
                $matched = $providerMap[$newProvider.ToLower()]
                if ($matched) {
                    $Provider = $matched
                    Write-Host "Switched to provider: $Provider" -ForegroundColor Green
                    return @{
                        NextStage             = 'A'
                        SelectedAlbum         = $null
                        UpdatedCache          = $CachedAlbums
                        UpdatedCachedArtistId = $CachedArtistId
                        UpdatedProvider       = $Provider
                        CurrentPage           = $currentPage
                    }
                }
                else {
                    Write-Warning "Invalid provider: $newProvider. Staying with $Provider."
                    continue
                }
            }
            '^ps$' {
                $Provider = 'Spotify'
                Write-Host "Switched to provider: $Provider" -ForegroundColor Green
                return @{
                    NextStage             = 'A'
                    SelectedAlbum         = $null
                    UpdatedCache          = $CachedAlbums
                    UpdatedCachedArtistId = $CachedArtistId
                    UpdatedProvider       = $Provider
                    CurrentPage           = $currentPage
                }
            }
            '^pq$' {
                $Provider = 'Qobuz'
                Write-Host "Switched to provider: $Provider" -ForegroundColor Green
                return @{
                    NextStage             = 'A'
                    SelectedAlbum         = $null
                    UpdatedCache          = $CachedAlbums
                    UpdatedCachedArtistId = $CachedArtistId
                    UpdatedProvider       = $Provider
                    CurrentPage           = $currentPage
                }
            }
            '^pd$' {
                $Provider = 'Discogs'
                Write-Host "Switched to provider: $Provider" -ForegroundColor Green
                return @{
                    NextStage             = 'A'
                    SelectedAlbum         = $null
                    UpdatedCache          = $CachedAlbums
                    UpdatedCachedArtistId = $CachedArtistId
                    UpdatedProvider       = $Provider
                    CurrentPage           = $currentPage
                }
            }
            '^pm$' {
                $Provider = 'MusicBrainz'
                Write-Host "Switched to provider: $Provider" -ForegroundColor Green
                return @{
                    NextStage             = 'A'
                    SelectedAlbum         = $null
                    UpdatedCache          = $CachedAlbums
                    UpdatedCachedArtistId = $CachedArtistId
                    UpdatedProvider       = $Provider
                    CurrentPage           = $currentPage
                }
            }
            '^b$' {
                return @{
                    NextStage             = 'A'
                    SelectedAlbum         = $null
                    UpdatedCache          = $null
                    UpdatedCachedArtistId = $null
                    UpdatedProvider       = $Provider
                    CurrentPage           = $currentPage
                }
            }
            '^$' {
                return @{
                    NextStage             = 'C'
                    SelectedAlbum         = $albumsForArtist[$startIdx]
                    UpdatedCache          = $CachedAlbums
                    UpdatedCachedArtistId = $CachedArtistId
                    UpdatedProvider       = $Provider
                    CurrentPage           = $currentPage
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
                                id           = $id
                                name         = if (Get-IfExists $release 'title') { $release.title } else { $id }
                                release_date = if (Get-IfExists $release 'date') { $release.date } else { $null }
                            }
                            Write-Host "✓ Found release: $($selectedAlbum.name)" -ForegroundColor Green
                        }
                        else {
                            Write-Warning "Could not fetch release information for ID: $id"
                        }
                    }
                    catch {
                        Write-Warning "Failed to fetch MusicBrainz release information: $_"
                    }
                }
                return @{
                    NextStage             = 'C'
                    SelectedAlbum         = @{ id = $id; name = $id }
                    UpdatedCache          = $CachedAlbums
                    UpdatedCachedArtistId = $CachedArtistId
                    UpdatedProvider       = $Provider
                    CurrentPage           = $currentPage
                }
            }
            '^\*$' {
                # Toggle between Masters-only and All-releases for Discogs
                if ($Provider -eq 'Discogs') {
                    $mastersOnlyMode = -not $mastersOnlyMode
                    $modeText = if ($mastersOnlyMode) { "MASTER releases only" } else { "ALL release types" }
                    Write-Host "`nToggling to: $modeText" -ForegroundColor Yellow
                    Write-Host "Fetching albums..." -ForegroundColor Cyan
                }
                else {
                    Write-Host "Fetching all albums for artist..." -ForegroundColor Cyan
                }
                
                try {
                    $fetchParams = @{
                        Provider  = $Provider
                        ArtistId  = $ProviderArtist.id
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
                    $currentPage = 1
                    
                    $statusMsg = if ($Provider -eq 'Discogs') {
                        "✓ Loaded $($albumsForArtist.Count) albums [$modeText]"
                    }
                    else {
                        "✓ Loaded $($albumsForArtist.Count) albums"
                    }
                    Write-Host $statusMsg -ForegroundColor Green
                }
                catch {
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
                    }
                    elseif ($part -match '^\d+$') {
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
                                }
                                elseif ($relInput -eq '0' -or $relInput -eq 'main') {
                                    # Fetch master details to get main_release
                                    try {
                                        $masterDetails = Invoke-DiscogsRequest -Uri "/masters/$($selectedAlbum.id)"
                                        if ($masterDetails -and (Get-IfExists $masterDetails 'main_release')) {
                                            $mainReleaseId = [string]$masterDetails.main_release
                                            Write-Host "Using main_release: $mainReleaseId" -ForegroundColor Green
                                            # Create a minimal release object with the main_release ID
                                            $selectedRelease = @{ id = $mainReleaseId; title = $selectedAlbum.name }
                                        }
                                        else {
                                            Write-Warning "Master has no main_release, using first release"
                                            $selectedRelease = $releases[0]
                                        }
                                    }
                                    catch {
                                        Write-Warning "Failed to fetch main_release: $_. Using first release."
                                        $selectedRelease = $releases[0]
                                    }
                                }
                                elseif ($relInput -match '^\d+$') {
                                    $idx = [int]$relInput
                                    if ($idx -ge 1 -and $idx -le $releases.Count) {
                                        $selectedRelease = $releases[$idx - 1]
                                    }
                                    else {
                                        Write-Warning "Invalid selection, using first release"
                                        $selectedRelease = $releases[0]
                                    }
                                }
                                else {
                                    Write-Warning "Invalid input, using first release"
                                    $selectedRelease = $releases[0]
                                }
                                
                                # Return the selected release instead of the master
                                Write-Host "✓ Selected release: $($selectedRelease.id) - $($selectedRelease.title)" -ForegroundColor Green
                                return @{
                                    NextStage             = 'C'
                                    SelectedAlbum         = @{
                                        id                  = [string]$selectedRelease.id
                                        name                = $selectedRelease.title
                                        type                = 'release'  # Mark as release, not master
                                        _resolvedFromMaster = $selectedAlbum.id
                                        _masterReleases     = $releases  # Store releases for potential retry
                                        _masterName         = $selectedAlbum.name
                                    }
                                    UpdatedCache          = $CachedAlbums
                                    UpdatedCachedArtistId = $CachedArtistId
                                    UpdatedProvider       = $Provider
                                    CurrentPage           = $currentPage
                                }
                            }
                            else {
                                Write-Warning "No releases found for master $($selectedAlbum.id), attempting to use master ID directly"
                            }
                        }
                        catch {
                            Write-Warning "Failed to fetch releases for master: $_. Will attempt to use master ID."
                        }
                    }
                    
                    # Normal path: return selected album (non-master or master resolution failed)
                    return @{
                        NextStage             = 'C'
                        SelectedAlbum         = $selectedAlbum
                        UpdatedCache          = $CachedAlbums
                        UpdatedCachedArtistId = $CachedArtistId
                        UpdatedProvider       = $Provider
                        CurrentPage           = $currentPage
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
                        }
                        else {
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
                    id               = "combined_$($validIndices -join '_')"
                    name             = if ($validIndices.Count -eq 2) { 
                        "$($albumNames[0]) + $($albumNames[1])" 
                    }
                    else { 
                        "$($albumNames[0]) + $($validIndices.Count - 1) more albums" 
                    }
                    release_date     = $firstAlbum.release_date
                    track_count      = $combinedTracks.Count
                    _isCombined      = $true
                    _albumCount      = $validIndices.Count
                    _albumNames      = $albumNames
                    _selectedIndices = $validIndices
                    _tracks          = $combinedTracks
                }
                
                Write-Host "`n✓ Combined $($combinedTracks.Count) tracks from $($validIndices.Count) albums" -ForegroundColor Green
                if ($failedAlbums -gt 0) {
                    Write-Warning "  Note: $failedAlbums album(s) failed to load"
                }
                
                return @{
                    NextStage             = 'C'
                    SelectedAlbum         = $combinedAlbum
                    UpdatedCache          = $CachedAlbums
                    UpdatedCachedArtistId = $CachedArtistId
                    UpdatedProvider       = $Provider
                    CurrentPage           = $currentPage
                }
            }
            '^vc(\d*)$' {
                # View Cover art: vc (first album) or vc<number> (specific album)
                $albumIndex = if ($matches[1]) { [int]$matches[1] - 1 } else { 0 }  # Convert to 0-based index
                
                if ($albumIndex -ge 0 -and $albumIndex -lt $albumsForArtist.Count) {
                    $selectedAlbum = $albumsForArtist[$albumIndex]
                    $coverUrl = Get-IfExists $selectedAlbum 'cover_url'
                    
                    if ($coverUrl) {
                        Write-Host "Displaying cover art from $coverUrl" -ForegroundColor Green
                        try {
                            Start-Process $coverUrl
                        } catch {
                            Write-Warning "Failed to open cover art URL: $_"
                        }
                    } else {
                        Write-Warning "No cover art available for this album"
                    }
                } else {
                    Write-Warning "Invalid album number: $(if ($matches[1]) { $matches[1] } else { 'first' })"
                }
                continue
            }
            '^sc(\d*)$' {
                # Save Cover art to folder: sc (first album) or sc<number> (specific album)
                $albumIndex = if ($matches[1]) { [int]$matches[1] - 1 } else { 0 }  # Convert to 0-based index
                
                if ($albumIndex -ge 0 -and $albumIndex -lt $albumsForArtist.Count) {
                    $selectedAlbum = $albumsForArtist[$albumIndex]
                    $coverUrl = Get-IfExists $selectedAlbum 'cover_url'
                    
                    if ($coverUrl) {
                        $config = Get-OMConfig
                        $maxSize = $config.CoverArt.FolderImageSize
                        $result = Save-CoverArt -CoverUrl $coverUrl -AlbumPath $Artist.FullName -Action SaveToFolder -MaxSize $maxSize -WhatIf:$NonInteractive
                        if (-not $result.Success) {
                            Write-Warning "Failed to save cover art: $($result.Error)"
                        }
                    } else {
                        Write-Warning "No cover art available for this album"
                    }
                } else {
                    Write-Warning "Invalid album number: $(if ($matches[1]) { $matches[1] } else { 'first' })"
                }
                continue
            }
            '^sct(\d*)$' {
                # Save Cover art to tags: sct (first album) or sct<number> (specific album)
                $albumIndex = if ($matches[1]) { [int]$matches[1] - 1 } else { 0 }  # Convert to 0-based index
                
                if ($albumIndex -ge 0 -and $albumIndex -lt $albumsForArtist.Count) {
                    $selectedAlbum = $albumsForArtist[$albumIndex]
                    $coverUrl = Get-IfExists $selectedAlbum 'cover_url'
                    
                    if ($coverUrl) {
                        $config = Get-OMConfig
                        $maxSize = $config.CoverArt.TagImageSize
                        # Get audio files for embedding
                        $audioFiles = Get-ChildItem -LiteralPath $Artist.FullName -File -Recurse | Where-Object { $_.Extension -match '\.(mp3|flac|wav|m4a|aac|ogg|ape)' } | ForEach-Object {
                            try {
                                $tagFile = [TagLib.File]::Create($_.FullName)
                                [PSCustomObject]@{
                                    FilePath = $_.FullName
                                    TagFile = $tagFile
                                }
                            } catch {
                                Write-Warning "Skipping invalid audio file: $($_.FullName)"
                                $null
                            }
                        } | Where-Object { $_ -ne $null }

                        if ($audioFiles.Count -gt 0) {
                            $result = Save-CoverArt -CoverUrl $coverUrl -AudioFiles $audioFiles -Action EmbedInTags -MaxSize $maxSize -WhatIf:$NonInteractive
                            if (-not $result.Success) {
                                Write-Warning "Failed to embed cover art: $($result.Error)"
                            }
                            # Clean up tag files
                            foreach ($af in $audioFiles) {
                                if ($af.TagFile) {
                                    try { $af.TagFile.Dispose() } catch { }
                                }
                            }
                        } else {
                            Write-Warning "No audio files found to embed cover art in"
                        }
                    } else {
                        Write-Warning "No cover art available for this album"
                    }
                } else {
                    Write-Warning "Invalid album number: $(if ($matches[1]) { $matches[1] } else { 'first' })"
                }
                continue
            }
            default {
                # User entered text - try as a new search term first
                Write-Host "Searching for albums matching: '$inputF'..." -ForegroundColor Cyan
                try {
                    $searchParams = @{
                        Provider   = $Provider
                        ArtistId   = $ProviderArtist.id
                        ArtistName = $ProviderArtist.name
                        AlbumName  = $inputF
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
                        $currentPage = 1  # Reset pagination when new search results are loaded
                        Write-Host "Found $($albumsForArtist.Count) albums matching '$inputF'" -ForegroundColor Green
                        continue
                    }
                }
                catch {
                    Write-Verbose "Search failed: $_"
                }
                
                # Fallback to local filtering if search failed or returned no results
                $filtered = @($albumsForArtist | Where-Object { $_.name -like "*$inputF*" })
                if ($filtered.Count -gt 0) {
                    $albumsForArtist = $filtered
                    $page = 1
                    $currentPage = 1
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

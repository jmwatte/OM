function Search-GQAlbum {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Query
    )

    # Ensure PowerHTML is available
    if (-not (Get-Module -Name PowerHTML -ListAvailable)) {
        Write-Verbose "PowerHTML module not present; Search-GQAlbum will not run."
        return [PSCustomObject]@{ albums = [PSCustomObject]@{ items = @() } }
    }
    Import-Module PowerHTML -ErrorAction Stop
    Add-Type -AssemblyName System.Web

    # When debugging (dot-sourcing single files), ensure helper functions are available
    if (-not (Get-Command -Name Get-IfExists -ErrorAction SilentlyContinue)) {
        $privateDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $getIfExistsPath = Join-Path $privateDir 'Get-IfExists.ps1'
        if (Test-Path $getIfExistsPath) { . $getIfExistsPath }
    }
    if (-not (Get-Command -Name Get-QAlbumTracks -ErrorAction SilentlyContinue)) {
        $qobuzDir = Split-Path -Parent $PSScriptRoot
        $getQAlbumTracksPath = Join-Path $qobuzDir 'Get-QAlbumTracks.ps1'
        if (Test-Path $getQAlbumTracksPath) { . $getQAlbumTracksPath }
    }
    if (-not (Get-Command -Name Get-QobuzUrlLocale -ErrorAction SilentlyContinue)) {
        $privateDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $qobuzLocalesPath = Join-Path $privateDir 'QobuzLocales.ps1'
        if (Test-Path $qobuzLocalesPath) { . $qobuzLocalesPath }
    }

    # Cache results in script scope
    if (-not (Get-Variable -Name QobuzGQAlbumCache -Scope Script -ErrorAction SilentlyContinue) -or -not ($script:QobuzGQAlbumCache -is [hashtable])) {
        Set-Variable -Name QobuzGQAlbumCache -Value @{} -Scope Script -Force
    }
    # Use the query as cache key
    $cacheKey = $Query
    if ($script:QobuzGQAlbumCache.ContainsKey($cacheKey)) { return $script:QobuzGQAlbumCache[$cacheKey] }

    # Resolve configured locale (culture) -> URL locale
    # Use Get-IfExists to safely obtain the configured locale
    $configuredLocale = Get-IfExists -target (Get-OMConfig -Provider Qobuz) -path 'Locale'
    if (-not $configuredLocale -or [string]::IsNullOrWhiteSpace($configuredLocale)) {
        $configuredLocale = $PSCulture
    }
    Write-Verbose "Using Qobuz configured locale: $configuredLocale (PSCulture: $PSCulture)"
    # Get URL locale and language for prioritization
    $urlLocale = Get-QobuzUrlLocale -CultureCode $configuredLocale
    $language = ($urlLocale -split '-')[1]

    # Prefer qobuz album pages for albums
    # For Google (HTML and CSE) prefer searching the album name only (no site: filter)
    # This helps Google return qobuz album pages when configured to search qobuz.
    $searchQueryGoogle = "`"$Query`""
    $targetUrl = $null

    # Try Google Custom Search API first (if configured via config or env)
    $google = Get-OMConfig -Provider Google
    $gApiKey = Get-IfExists -target $google -path 'ApiKey'
    if (-not $gApiKey) { $gApiKey = $env:GOOGLE_API_KEY }
    $gCse = Get-IfExists -target $google -path 'Cse'
    if (-not $gCse) { $gCse = $env:GOOGLE_CSE }
    Write-Verbose "Google API key present: $([bool]$gApiKey); Google CSE present: $([bool]$gCse)"

    # Google CSE (preferred) - try this first if configured
    if (-not $targetUrl -and $gApiKey -and $gCse) {
        try {
            # Use the album-only query for Google CSE
            $csq = [uri]::EscapeDataString($searchQueryGoogle)
            $num = 10  # Google CSE limit per request
            # Hint the search by country based on configured locale (e.g., en-US -> us)
            $country = if ($configuredLocale -and ($configuredLocale -match '-')) { ($configuredLocale.Split('-')[-1]).ToLower() } else { $PSCulture.Split('-')[-1].ToLower() }

            # Collect results from multiple pages (start=1 and start=11 for 20 total results)
            $allItems = @()
            $starts = @(1, 11)  # Get first 10, then next 10

            foreach ($start in $starts) {
                $apiUrl = "https://www.googleapis.com/customsearch/v1?key=$($gApiKey)&cx=$($gCse)&q=$csq&num=$num&start=$start&gl=$country"
                $apiResp = Invoke-RestMethod -Uri $apiUrl -Method Get -ErrorAction Stop
                Write-Verbose "Google CSE API URL (start=$start): $apiUrl"
                if ($apiResp.items) {
                    $allItems += $apiResp.items
                    Write-Verbose ("Google CSE returned {0} items for start={1}" -f $apiResp.items.Count, $start)
                } else {
                    Write-Verbose ("No items returned for start={0}" -f $start)
                }
            }

            Write-Verbose ("Total Google CSE items collected: {0}" -f $allItems.Count)

            if ($allItems.Count -gt 0) {
                # Prioritize by locale: exact match first, then language match, then fallback
                # First, look for exact locale match
                foreach ($it in $allItems) {
                    Write-Verbose ("CSE item: {0}" -f $it.link)
                    if ($it.link -match "/$urlLocale/" -and $it.link -match '/album/') {
                        $targetUrl = $it.link
                        Write-Verbose "Found exact locale match: $targetUrl"
                        break
                    }
                }
                # If not found, look for language match
                if (-not $targetUrl) {
                    foreach ($it in $allItems) {
                        if ($it.link -match "/[a-z]{2}-$language/" -and $it.link -match '/album/') {
                            $targetUrl = $it.link
                            Write-Verbose "Found language match: $targetUrl"
                            break
                        }
                    }
                }
                # If still not found, use fallback: first album or first item
                if (-not $targetUrl) {
                    foreach ($it in $allItems) {
                        if ($it.link -match '/album/') { $targetUrl = $it.link; break }
                    }
                    if (-not $targetUrl -and $allItems.Count -gt 0) { $targetUrl = $allItems[0].link }
                    Write-Verbose "Using fallback selection: $targetUrl"
                }
            }
        }
        catch {
            Write-Verbose "Google CSE failed: $_"
        }
    }

    # If nothing found, return empty result
    if (-not $targetUrl) {
        Write-Verbose "No Qobuz album URL found via CSE; returning empty result."
        $res = [PSCustomObject]@{ albums = [PSCustomObject]@{ items = @() } }
        $script:QobuzGQAlbumCache[$cacheKey] = $res
        return $res
    }

    # Extract album ID from URL and get tracks (which contain album metadata)
    try {
        if ($targetUrl -match '/album/[^/]+/(\d+)') { $albumId = $matches[1] }
        else { $albumId = ($targetUrl.TrimEnd('/').Split('/')[-1]) }

        Write-Verbose "Extracted album ID: $albumId, fetching tracks to get album metadata..."
        $tracks = Get-QAlbumTracks -Id $albumId

        if (-not $tracks -or $tracks.Count -eq 0) {
            Write-Verbose "No tracks found for album ID $albumId"
            $res = [PSCustomObject]@{ albums = [PSCustomObject]@{ items = @() } }
            $script:QobuzGQAlbumCache[$cacheKey] = $res
            return $res
        }

        # Extract album metadata from the first track
        $firstTrack = $tracks[0]
        $albumName = $firstTrack.album_name
        $albumArtistName = $firstTrack.album_artist
        $genres = $firstTrack.genres
        $releaseDate = $firstTrack.release_date

        # Get track/disc counts
        $trackCount = $tracks.Count
        $discCount = ($tracks | Measure-Object -Property disc_number -Maximum).Maximum

        # Extract cover URL from the page (not available in tracks)
        $albumResp = Invoke-WebRequest -Uri $targetUrl -UseBasicParsing -ErrorAction Stop -TimeoutSec 15
        $albumDoc = ConvertFrom-Html -Content $albumResp.Content
        $coverNode = $albumDoc.SelectSingleNode("//*[@id='page_catalog_page']/link")
        $coverUrl = if ($coverNode) { $coverNode.GetAttributeValue('href','') } else { '' }

        $item = [PSCustomObject]@{
            name        = $albumName
            id          = $albumId
            url         = $targetUrl
            artists     = @([PSCustomObject]@{ name = $albumArtistName })
            genres      = $genres
            cover_url   = $coverUrl
            track_count = $trackCount
            disc_count  = $discCount
            release_date = $releaseDate
        }

        $res = [PSCustomObject]@{
            albums = [PSCustomObject]@{
                items = @($item)
            }
        }

        $script:QobuzGQAlbumCache[$cacheKey] = $res
        return $res
    }
    catch {
        Write-Verbose "Failed to get album data: $_"
        $res = [PSCustomObject]@{ albums = [PSCustomObject]@{ items = @() } }
        $script:QobuzGQAlbumCache[$cacheKey] = $res
        return $res
    }
}
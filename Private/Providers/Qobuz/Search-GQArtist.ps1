function Search-GQArtist {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Query
    )

    # Ensure PowerHTML is available
    if (-not (Get-Module -Name PowerHTML -ListAvailable)) {
        Write-Verbose "PowerHTML module not present; Search-GQArtist will not run."
        return [PSCustomObject]@{ artists = [PSCustomObject]@{ items = @() } }
    }
    Import-Module PowerHTML -ErrorAction Stop
    Add-Type -AssemblyName System.Web

    # Cache results in script scope
    if (-not (Get-Variable -Name QobuzGQCache -Scope Script -ErrorAction SilentlyContinue) -or -not ($script:QobuzGQCache -is [hashtable])) {
        Set-Variable -Name QobuzGQCache -Value @{} -Scope Script -Force
    }
   # $cacheKey = $Query
   # if ($script:QobuzGQCache.ContainsKey($cacheKey)) { return $script:QobuzGQCache[$cacheKey] }

    # Resolve configured locale (culture) -> URL locale
    $qobuzConfig = Get-OMConfig -Provider Qobuz
    # Use Get-IfExists to safely obtain the configured locale
    $configuredLocale = Get-IfExists -target $qobuzConfig -path 'Locale'
    if (-not $configuredLocale -or [string]::IsNullOrWhiteSpace($configuredLocale)) {
        $configuredLocale = $PSCulture
    }
    Write-Verbose "Using Qobuz configured locale: $configuredLocale (PSCulture: $PSCulture)"
    $urlLocale = Get-QobuzUrlLocale -CultureCode $configuredLocale

    # Prefer qobuz interpreter pages for artists
    $searchQuery = "site:qobuz.com/interpreter \"+$($Query)+"\"
    $targetUrl = $null

    # Try Google Custom Search API first (if configured via config or env)
    $google = Get-OMConfig -Provider Google
    $gApiKey = Get-IfExists -target $google -path 'ApiKey'
    if (-not $gApiKey) { $gApiKey = $env:GOOGLE_API_KEY }
    $gCse = Get-IfExists -target $google -path 'Cse'
    if (-not $gCse) { $gCse = $env:GOOGLE_CSE }
    Write-Verbose "Google API key present: $([bool]$gApiKey); Google CSE present: $([bool]$gCse)"
    if ($gApiKey -and $gCse) {
        try {
            $csq = [uri]::EscapeDataString($searchQuery)
            $num = 10
            # Hint the search by country based on configured locale (e.g., en-US -> us)
            $country = if ($configuredLocale -and ($configuredLocale -match '-')) { ($configuredLocale.Split('-')[-1]).ToLower() } else { $PSCulture.Split('-')[-1].ToLower() }
            $apiUrl = "https://www.googleapis.com/customsearch/v1?key=$($gApiKey)&cx=$($gCse)&q=$csq&num=$num&gl=$country"
            $apiResp = Invoke-RestMethod -Uri $apiUrl -Method Get -ErrorAction Stop
            Write-Verbose "Google CSE API URL: $apiUrl"
            $count = 0
            if ($apiResp.items) { $count = $apiResp.items.Count }
            Write-Verbose ("Google CSE returned {0} items" -f $count)
            if ($apiResp.items -and $apiResp.items.Count -gt 0) {
                foreach ($it in $apiResp.items) {
                    Write-Verbose ("CSE item: {0}" -f $it.link)
                    if ($it.link -match '/interpreter/') { $targetUrl = $it.link; break }
                }
                if (-not $targetUrl) { $targetUrl = $apiResp.items[0].link }
                Write-Verbose "Google CSE selected url: $targetUrl"
            }
            else {
                Write-Verbose "Google CSE returned 0 items; retrying with siteSearch restriction..."
                try {
                    $siteApiUrl = "https://www.googleapis.com/customsearch/v1?key=$($gApiKey)&cx=$($gCse)&q=$csq&num=$num&gl=$country&siteSearch=qobuz.com"
                    $apiResp2 = Invoke-RestMethod -Uri $siteApiUrl -Method Get -ErrorAction Stop
                    $count2 = 0
                    if ($apiResp2.items) { $count2 = $apiResp2.items.Count }
                    Write-Verbose ("Google CSE siteSearch returned {0} items" -f $count2)
                    if ($apiResp2.items -and $apiResp2.items.Count -gt 0) {
                        foreach ($it2 in $apiResp2.items) {
                            Write-Verbose ("CSE siteSearch item: {0}" -f $it2.link)
                            if ($it2.link -match '/interpreter/') { $targetUrl = $it2.link; break }
                        }
                        if (-not $targetUrl) { $targetUrl = $apiResp2.items[0].link }
                        Write-Verbose "Google CSE siteSearch selected url: $targetUrl"
                    }
                }
                catch {
                    Write-Verbose "Google CSE siteSearch retry failed: $_"
                }
            }
            Write-Verbose "Google CSE API URL: $apiUrl"
            $count = 0
            if ($apiResp.items) { $count = $apiResp.items.Count }
            Write-Verbose ("Google CSE response items: {0}" -f $count)
            if ($apiResp.items -and $apiResp.items.Count -gt 0) {
                $targetUrl = $apiResp.items[0].link
                Write-Verbose "Google CSE selected url: $targetUrl"
            }
        }
        catch {
            Write-Verbose "Google CSE failed: $_"
        }
    }

    # DuckDuckGo HTML fallback
    if (-not $targetUrl) {
        try {
            $ddgUrl = "https://duckduckgo.com/html?q=$([uri]::EscapeDataString($searchQuery))"
            $ddgResp = Invoke-WebRequest -Uri $ddgUrl -Headers @{ 'User-Agent' = 'Mozilla/5.0' } -UseBasicParsing -ErrorAction Stop
            $html = $ddgResp.Content
            if ($html -match 'https?://(?:www\.)?qobuz\.com[^\s"<>]+') {
                $targetUrl = $matches[0]
                Write-Verbose "DuckDuckGo quick regex selected: $targetUrl"
            }
            else {
                $doc = ConvertFrom-Html -Content $html
                $linkNode = $doc.SelectSingleNode("//a[contains(@href,'qobuz.com')]")
                # Try direct Google HTML search (faster/more reliable for this use-case)
                try {
                    $hl = if ($configuredLocale -and ($configuredLocale -match '-')) { ($configuredLocale.Split('-')[0]).ToLower() } else { $PSCulture.Split('-')[0].ToLower() }
                    $gUrl = "https://www.google.com/search?q=$([uri]::EscapeDataString($searchQuery))&num=10&hl=$hl"
                    Write-Verbose "Google HTML search URL: $gUrl"
                    $gResp = Invoke-WebRequest -Uri $gUrl -Headers @{ 'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' } -UseBasicParsing -ErrorAction Stop
                    $gHtml = $gResp.Content
                    $gDoc = ConvertFrom-Html -Content $gHtml
                    $gLinks = $gDoc.SelectNodes('//a[contains(@href,"/url?q=") or contains(@href,"qobuz.com")]')
                    if ($gLinks) {
                        foreach ($l in $gLinks) {
                            $href = $l.GetAttributeValue('href','')
                            $url = $null
                            if ($href -match '/url\?q=(https?://[^&]+)') { $url = [uri]::UnescapeDataString($matches[1]) }
                            elseif ($href -match '^https?://') { $url = $href }
                            else { $url = "https://www.qobuz.com$href" }
                            Write-Verbose "Google result link: $url"
                            if ($url -match '/interpreter/') { $targetUrl = $url; break }
                        }
                    }
                }
                catch {
                    Write-Verbose "Google HTML search failed: $_"
                }

                # If Google HTML didn't find results, fall back to CSE when configured
                if (-not $targetUrl -and $gApiKey -and $gCse) {
                    try {
                        $csq = [uri]::EscapeDataString($searchQuery)
                        $num = 10
                        # Hint the search by country based on configured locale (e.g., en-US -> us)
                        $country = if ($configuredLocale -and ($configuredLocale -match '-')) { ($configuredLocale.Split('-')[-1]).ToLower() } else { $PSCulture.Split('-')[-1].ToLower() }
                        $apiUrl = "https://www.googleapis.com/customsearch/v1?key=$($gApiKey)&cx=$($gCse)&q=$csq&num=$num&gl=$country"
                        $apiResp = Invoke-RestMethod -Uri $apiUrl -Method Get -ErrorAction Stop
                        Write-Verbose "Google CSE API URL: $apiUrl"
                        $count = 0
                        if ($apiResp.items) { $count = $apiResp.items.Count }
                        Write-Verbose ("Google CSE returned {0} items" -f $count)
                        if ($apiResp.items -and $apiResp.items.Count -gt 0) {
                            foreach ($it in $apiResp.items) {
                                Write-Verbose ("CSE item: {0}" -f $it.link)
                                if ($it.link -match '/interpreter/') { $targetUrl = $it.link; break }
                            }
                            if (-not $targetUrl) { $targetUrl = $apiResp.items[0].link }
                            Write-Verbose "Google CSE selected url: $targetUrl"
                        }
                        else {
                            Write-Verbose "Google CSE returned 0 items; retrying with siteSearch restriction..."
                            try {
                                $siteApiUrl = "https://www.googleapis.com/customsearch/v1?key=$($gApiKey)&cx=$($gCse)&q=$csq&num=$num&gl=$country&siteSearch=qobuz.com"
                                $apiResp2 = Invoke-RestMethod -Uri $siteApiUrl -Method Get -ErrorAction Stop
                                $count2 = 0
                                if ($apiResp2.items) { $count2 = $apiResp2.items.Count }
                                Write-Verbose ("Google CSE siteSearch returned {0} items" -f $count2)
                                if ($apiResp2.items -and $apiResp2.items.Count -gt 0) {
                                    foreach ($it2 in $apiResp2.items) {
                                        Write-Verbose ("CSE siteSearch item: {0}" -f $it2.link)
                                        if ($it2.link -match '/interpreter/') { $targetUrl = $it2.link; break }
                                    }
                                    if (-not $targetUrl) { $targetUrl = $apiResp2.items[0].link }
                                    Write-Verbose "Google CSE siteSearch selected url: $targetUrl"
                                }
                            }
                            catch {
                                Write-Verbose "Google CSE siteSearch retry failed: $_"
                            }
                        }
                    }
                    catch {
                        Write-Verbose "Google CSE failed: $_"
                    }
                }

    # Fetch artist page and extract properties
    try {
        $artistResp = Invoke-WebRequest -Uri $targetUrl -UseBasicParsing -ErrorAction Stop -TimeoutSec 15
        $artistDoc = ConvertFrom-Html -Content $artistResp.Content

        $nameNode = $artistDoc.SelectSingleNode("//*[@id='artist']//h1")
        if (-not $nameNode) { $nameNode = $artistDoc.SelectSingleNode("//meta[@property='og:title']") }
        if ($nameNode) {
            $artistName = if ($nameNode.InnerText -and $nameNode.InnerText.Trim()) { $nameNode.InnerText.Trim() } else { $nameNode.GetAttributeValue('content','').Trim() }
        } else { $artistName = $Query }
        $artistName = [System.Web.HttpUtility]::HtmlDecode($artistName)

        $imgNode = $artistDoc.SelectSingleNode("//*[@id='artist']//img")
        $coverUrl = if ($imgNode) { $imgNode.GetAttributeValue('src','') } else { '' }

        $genreNode = $artistDoc.SelectSingleNode("//*[@id='artist']/section[2]/div[2]/ul/li[1]/div/div[1]/a/div/p[1]")
        $genres = if ($genreNode -and $genreNode.InnerText.Trim()) { @([System.Web.HttpUtility]::HtmlDecode($genreNode.InnerText.Trim())) } else { @() }

        if ($targetUrl -match '/interpreter/[^/]+/(\d+)') { $artistId = $matches[1] }
        else { $artistId = ($targetUrl.TrimEnd('/').Split('/')[-1]) }

        $item = [PSCustomObject]@{
            name      = $artistName
            id        = $artistId
            url       = $targetUrl
            genres    = $genres
            cover_url = $coverUrl
        }

        $res = [PSCustomObject]@{
            artists = [PSCustomObject]@{
                items = @($item)
            }
        }

        $script:QobuzGQCache[$cacheKey] = $res
        return $res
    }
    catch {
        Write-Verbose "Failed to fetch/parse artist page: $_"
        $res = [PSCustomObject]@{ artists = [PSCustomObject]@{ items = @() } }
        $script:QobuzGQCache[$cacheKey] = $res
        return $res
    }
}

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
    $configuredLocale = $qobuzConfig?.Locale ?? $PSCulture
    $urlLocale = Get-QobuzUrlLocale -CultureCode $configuredLocale

    $searchQuery = "site:qobuz.com $Query artist"
    $targetUrl = $null

    # Try Google Custom Search API first (if configured via config or env)
    $google = Get-OMConfig -Provider Google
    $gApiKey = $google?.ApiKey ?? $env:GOOGLE_API_KEY
    $gCse    = $google?.Cse ?? $env:GOOGLE_CSE
    if ($gApiKey -and $gCse) {
        try {
            $csq = [uri]::EscapeDataString($searchQuery)
            $apiUrl = "https://www.googleapis.com/customsearch/v1?key=$($gApiKey)&cx=$($gCse)&q=$csq&num=1"
            $apiResp = Invoke-RestMethod -Uri $apiUrl -Method Get -ErrorAction Stop
            if ($apiResp.items -and $apiResp.items.Count -gt 0) { $targetUrl = $apiResp.items[0].link }
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
            }
            else {
                $doc = ConvertFrom-Html -Content $html
                $linkNode = $doc.SelectSingleNode("//a[contains(@href,'qobuz.com')]")
                if ($linkNode) {
                    $href = $linkNode.GetAttributeValue('href','')
                    if ($href -match 'uddg=([^&]+)') { $targetUrl = [uri]::UnescapeDataString($matches[1]) }
                    elseif ($href -match '^https?://') { $targetUrl = $href }
                    else { $targetUrl = "https://www.qobuz.com$href" }
                }
            }
        }
        catch {
            Write-Verbose "DuckDuckGo search failed: $_"
        }
    }

    if (-not $targetUrl) {
        $res = [PSCustomObject]@{ artists = [PSCustomObject]@{ items = @() } }
        $script:QobuzGQCache[$cacheKey] = $res
        return $res
    }

    # Canonicalize and attempt to resolve to an interpreter (artist) page
    if ($targetUrl -notmatch '^https?://') { $targetUrl = "https://www.qobuz.com$targetUrl" }

    try {
        $pageResp = Invoke-WebRequest -Uri $targetUrl -UseBasicParsing -ErrorAction Stop -TimeoutSec 15
        $pageDoc = ConvertFrom-Html -Content $pageResp.Content

        # If we landed on an album or other page, try to extract the interpreter link
        $artistAnchor = $pageDoc.SelectSingleNode("//a[contains(@href,'/interpreter/')]")
        if ($artistAnchor) {
            $ahref = $artistAnchor.GetAttributeValue('href','')
            $targetUrl = if ($ahref -match '^https?://') { $ahref } else { "https://www.qobuz.com$ahref" }
        }
    }
    catch {
        Write-Verbose "Failed to fetch search result page: $_"
    }

    if ($targetUrl -notmatch '/interpreter/') {
        $res = [PSCustomObject]@{ artists = [PSCustomObject]@{ items = @() } }
        $script:QobuzGQCache[$cacheKey] = $res
        return $res
    }

    # Normalize locale in the URL
    $targetUrl = $targetUrl -replace '/[a-z]{2}-[a-z]{2}/interpreter/', "/$urlLocale/interpreter/"

    # Fetch artist page and extract properties
    try {
        $artistResp = Invoke-WebRequest -Uri $targetUrl -UseBasicParsing -ErrorAction Stop -TimeoutSec 15
        $artistDoc = ConvertFrom-Html -Content $artistResp.Content

        $nameNode = $artistDoc.SelectSingleNode("//*[@id='artist']//h1")
        if (-not $nameNode) { $nameNode = $artistDoc.SelectSingleNode("//meta[@property='og:title']") }
        $artistName = if ($nameNode) { ($nameNode.InnerText??$nameNode.GetAttributeValue('content','')).Trim() } else { $Query }
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

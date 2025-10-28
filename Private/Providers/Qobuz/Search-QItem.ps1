# Private/QSearch-Item.ps1
function Search-QItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Query,

        [Parameter(Mandatory = $true)]
        [ValidateSet('artist', 'album')]
        [string]$Type
    )

    if ($Type -ne 'artist' -and $Type -ne 'album') {
        throw "Only 'artist' and 'album' types are supported for Qobuz search."
    }

    # Ensure PowerHTML is available
    if (-not (Get-Module -Name PowerHTML -ListAvailable)) {
        throw "PowerHTML module is required but not installed. Install it with: Install-Module PowerHTML"
    }
    Import-Module PowerHTML

    # Load System.Web for HTML decoding
    Add-Type -AssemblyName System.Web

    # For album search, try Google CSE first
    if ($Type -eq 'album') {
        try {
            $gApiKey = Get-OMConfig | Select-Object -ExpandProperty GoogleApiKey -ErrorAction SilentlyContinue
            $gCse = Get-OMConfig | Select-Object -ExpandProperty GoogleCse -ErrorAction SilentlyContinue
            $locale = Get-QobuzUrlLocale
            $searchQuery = "site:qobuz.com/$locale/ `"$Query`" -playlist"
            if ($gApiKey -and $gCse) {
                $cseUrl = "https://www.googleapis.com/customsearch/v1?key=$gApiKey&cx=$gCse&q=$([uri]::EscapeDataString($searchQuery))"
                $cseResp = Invoke-WebRequest -Uri $cseUrl -UseBasicParsing
                $cseData = $cseResp.Content | ConvertFrom-Json
                if ($cseData.items) {
                    $albumUrls = @()
                    foreach ($item in $cseData.items) {
                        if ($item.link -match 'qobuz\.com') {
                            $albumUrls += $item.link
                        }
                    }
                    if ($albumUrls) {
                        $targetUrl = $albumUrls[0]
                        Write-Verbose "Google CSE selected album: $targetUrl"
                        # Parse album details from URL (simplified)
                        $albumName = $Query  # Placeholder
                        $artistName = "Unknown"  # Placeholder
                        $items = @([PSCustomObject]@{
                            name = $albumName
                            id = $targetUrl.Split('/')[-1]
                            url = $targetUrl
                            artists = @([PSCustomObject]@{ name = $artistName })
                        })
                        return [PSCustomObject]@{
                            albums = [PSCustomObject]@{
                                items = $items
                            }
                        }
                    }
                }
            }
            # Fallback to DuckDuckGo
            $ddgUrl = "https://duckduckgo.com/html?q=$([uri]::EscapeDataString($searchQuery))"
            $ddgResp = Invoke-WebRequest -Uri $ddgUrl -Headers @{ 'User-Agent' = 'Mozilla/5.0' } -UseBasicParsing
            $html = $ddgResp.Content
            if ($html -match 'https?://(?:www\.)?qobuz\.com[^\s"<>]+') {
                $targetUrl = $matches[0]
                Write-Verbose "DuckDuckGo selected album: $targetUrl"
                $albumName = $Query
                $artistName = "Unknown"
                $items = @([PSCustomObject]@{
                    name = $albumName
                    id = $targetUrl.Split('/')[-1]
                    url = $targetUrl
                    artists = @([PSCustomObject]@{ name = $artistName })
                })
                return [PSCustomObject]@{
                    albums = [PSCustomObject]@{
                        items = $items
                    }
                }
            }
        }
        catch {
            Write-Verbose "Album search via web failed: $_"
        }
        # If no results, return empty
        return [PSCustomObject]@{
            albums = [PSCustomObject]@{
                items = @()
            }
        }
    }

    # When debugging (dot-sourcing single files), ensure helper functions are available
    # if (-not (Get-Command -Name Get-QobuzUrlLocale -ErrorAction SilentlyContinue)) {
    #     $privateDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    #     $localesPath = Join-Path $privateDir 'QobuzLocales.ps1'
    #     if (Test-Path $localesPath) { . $localesPath }
    # }











    # Try a quick web search for the artist first (Google CSE or DuckDuckGo)
    try {
        $quick = Search-GQArtist -Query $Query
        if ($quick -and $quick.artists -and $quick.artists.items -and $quick.artists.items.Count -gt 0) {
            Write-Verbose "Found artist via web search; returning quick result."
            return $quick
        }
    }
    catch {
        Write-Verbose "Quick web search failed or returned no results: $_"
    }

    # Construct the search URL (use configured Qobuz locale)
    $locale = Get-QobuzUrlLocale
    $url = "https://www.qobuz.com/$locale/search/artists/$([uri]::EscapeDataString($Query))"
   
    try {
        # Fetch the HTML
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing
        $html = $response.Content

        # Parse with PowerHTML
        $doc = ConvertFrom-Html -Content $html

        # Select artist cards using explicit XPath; fallback to FollowingCard class
        $cards = $doc.SelectNodes("//*[@id='search']/section[2]/div/ul/li/div")
       

        $items = @()
        foreach ($card in $cards) {
            $title = $card.GetAttributeValue('title', '')
            # fallback: some card variants embed the artist link in a child node
            
            if (-not $title) { continue }

            # Decode HTML entities in the title
            $title = [System.Web.HttpUtility]::HtmlDecode($title)

            # Extract the first artist link that looks like an interpreter link
            $link = $card.SelectSingleNode('.//a[contains(@href, "/interpreter/")]')
            if (-not $link) { continue }

            $href = $link.GetAttributeValue('href', '')
            if (-not $href) { continue }
            # Clean href (remove query/fragment)
            if ($href -match '^[^?#]+') { $hrefClean = $matches[0] } else { $hrefClean = $href }
            # Build full URL for convenience
            $fullUrl = if ($hrefClean -match '^https?://') { $hrefClean } else { "https://www.qobuz.com$hrefClean" }
            # fetch first album genre from artist page (XPath: //*[@id="artist"]/section[2]/div[2]/ul/li[1]/div/div[1]/a/div/p[1])
                        # Ensure script-level cache exists and is a hashtable
            if (-not (Get-Variable -Name QobuzArtistGenresCache -Scope Script -ErrorAction SilentlyContinue) -or -not ($script:QobuzArtistGenresCache -is [hashtable])) {
                Set-Variable -Name QobuzArtistGenresCache -Value @{} -Scope Script -Force
            }
            
            $genres = @()
            $cacheKey = $fullUrl
            write-host "getting genres for $fullUrl"
            # Only call ContainsKey if the cache exists and is a hashtable
            if ($cacheKey -and ($script:QobuzArtistGenresCache -is [hashtable]) -and $script:QobuzArtistGenresCache.ContainsKey($cacheKey)) {
                $genres = $script:QobuzArtistGenresCache[$cacheKey]
            }
            elseif ($cacheKey) {
                try {
                    $artistResp = Invoke-WebRequest -Uri $fullUrl -UseBasicParsing -ErrorAction Stop -TimeoutSec 15
                    $artistDoc  = ConvertFrom-Html -Content $artistResp.Content
            
                    $genreNode = $artistDoc.SelectSingleNode("//*[@id='artist']/section[2]/div[2]/ul/li[1]/div/div[1]/a/div/p[1]")
                    if ($genreNode -and $genreNode.InnerText.Trim()) {
                        $genres = @([System.Web.HttpUtility]::HtmlDecode($genreNode.InnerText.Trim()))
                    }
                    else {
                        $altNode = $artistDoc.SelectSingleNode("//*[@id='artist']//ul/li[1]//a/div/p[1]")
                        if ($altNode -and $altNode.InnerText.Trim()) {
                            $genres = @([System.Web.HttpUtility]::HtmlDecode($altNode.InnerText.Trim()))
                        }
                    }
                }
                catch {
                    Write-Verbose "Failed to fetch artist page for genres ($fullUrl): $_"
                    $genres = @()
                }
            
                # Ensure cache still a hashtable before writing
                if (-not ($script:QobuzArtistGenresCache -is [hashtable])) {
                    $script:QobuzArtistGenresCache = @{}
                }
                $script:QobuzArtistGenresCache[$cacheKey] = $genres
            }
            # Extract artist image from card
            $imgNode = $card.SelectSingleNode('./div[1]/div[1]/img')
            $artistImage = if ($imgNode) { $imgNode.GetAttributeValue('src', '') } else { '' }
 

            # Create the item object (similar to Spotify structure)
            # Extract artist id (numeric if possible) from href, fallback to last path segment
            $artistId = $null
            if ($hrefClean -match '/interpreter/[^/]+/(\d+)$') { $artistId = $matches[1] }
            else { 
                $parts = $hrefClean.TrimEnd('/').Split('/')
                $artistId = if ($parts.Count -gt 0) { $parts[-1] } else { $hrefClean }
            }

            $item = [PSCustomObject]@{
                name      = $title
                id        = $artistId
                url       = $fullUrl
                genres    = $genres
                cover_url = $artistImage
            }
            $items += $item
        }

        # Return the result object
        [PSCustomObject]@{
            artists = [PSCustomObject]@{
                items = $items
            }
        }
    }
    catch {
        Write-Warning "Qobuz search failed: $_"
        [PSCustomObject]@{
            artists = [PSCustomObject]@{
                items = @()
            }
        }
    }
}
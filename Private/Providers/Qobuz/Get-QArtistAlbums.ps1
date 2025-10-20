# Private/QGet-ArtistAlbums.ps1
function Get-QArtistAlbums {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Id,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Album')]
        [string]$Album = 'Album'  # For compatibility with Spotify API
    )

    begin {
        # Ensure PowerHTML is available
        if (-not (Get-Module -Name PowerHTML -ListAvailable)) {
            throw "PowerHTML module is required but not installed. Install it with: Install-Module PowerHTML"
        }
        Import-Module PowerHTML -ErrorAction Stop

        # Load System.Web for HTML decoding
        Add-Type -AssemblyName System.Web

        # Function to map culture code to Qobuz URL locale
        function Get-QobuzUrlLocale {
            param([string]$CultureCode)
            $localeMap = @{
                'fr-FR' = 'fr-fr'
                'en-US' = 'us-en'
                'en-GB' = 'gb-en'
                'de-DE' = 'de-de'
                'es-ES' = 'es-es'
                'it-IT' = 'it-it'
                'nl-BE' = 'be-nl'
                'nl-NL' = 'nl-nl'
                'pt-PT' = 'pt-pt'
                'pt-BR' = 'br-pt'
                'ja-JP' = 'jp-ja'
            }
            return $localeMap[$CultureCode] ?? 'us-en'  # Default to us-en
        }

        # Get configured Qobuz locale, default to 'en-US' -> 'us-en'
        $config = Get-OMConfig
        $configuredLocale = $config.Qobuz?.Locale ?? 'en-US'
        $urlLocale = Get-QobuzUrlLocale -CultureCode $configuredLocale

        # Normalize base URL: accept either the full URL or the relative interpreter path
        if ($Id -match '^https?://') {
            $baseUrl = $Id.TrimEnd('/')
        } elseif ($Id -match '^/be-fr/interpreter/') {
            $baseUrl = "https://www.qobuz.com$Id".TrimEnd('/')
        } else {
            throw "Id must be either a full Qobuz interpreter URL or a path starting with a locale-prefixed interpreter path (e.g., /us-en/interpreter/artist-slug/12345). Configured locale: $urlLocale"
        }

        # Replace any existing locale in the URL with the configured one
        $baseUrl = $baseUrl -replace '/[a-z]{2}-[a-z]{2}/interpreter/', "/$urlLocale/interpreter/"

        # Remove any trailing /page/N if the user supplied a paged URL
        $artistBase = $baseUrl -replace '/page/\d+$', ''
        $maxPagesCap = 50  # safety cap
    }

    process {
        $allAlbums = @()
        $seenIds = @{}
        $page = 1
        $pageUrl = $artistBase
        $maxPages = $null

        while ($true) {
            Write-Host ("Fetching Qobuz artist page: {0}" -f $pageUrl)

            try {
                $resp = Invoke-WebRequest -Uri $pageUrl -UseBasicParsing -ErrorAction Stop
                $html = $resp.Content
            }
            catch {
                Write-Warning ("Failed to download page {0}: {1}" -f $pageUrl, $_.Exception.Message)
                break
            }

            try {
                $doc = ConvertFrom-Html -Content $html
            }
            catch {
                Write-Warning ("Failed to parse HTML for page {0}: {1}" -f $pageUrl, $_.Exception.Message)
                break
            }

            # Attempt to discover total number of pages from paginator links (only once, on first page)
            if (-not $maxPages) {
                $pageNumbers = @()
                $pageAnchors = $doc.SelectNodes('//a[contains(@href,"/page/")]')
                if ($pageAnchors) {
                    foreach ($a in @($pageAnchors)) {
                        $href = $a.GetAttributeValue('href','')
                        if ($href -match '/page/(\d+)') { $pageNumbers += [int]$matches[1]; continue }
                        $inner = $a.InnerText
                        if ($inner -match '^\s*(\d+)\s*$') { $pageNumbers += [int]$matches[1]; continue }
                    }
                }

                # As an additional fallback, try any text-only paginator nodes (e.g. span or li)
                if (-not $pageNumbers -or $pageNumbers.Count -eq 0) {
                    $numNodes = $doc.SelectNodes('//span[contains(@class,"page") or contains(@class,"pagination")]')
                    if ($numNodes) {
                        foreach ($n in @($numNodes)) {
                            if ($n.InnerText -match '^\s*(\d+)\s*$') { $pageNumbers += [int]$matches[1] }
                        }
                    }
                }

                if ($pageNumbers -and $pageNumbers.Count -gt 0) {
                    $maxPages = ($pageNumbers | Measure-Object -Maximum).Maximum
                    if ($maxPages -gt $maxPagesCap) {
                        Write-Warning ("Detected {0} pages but capping to {1} to avoid excessive requests" -f $maxPages, $maxPagesCap)
                        $maxPages = $maxPagesCap
                    }
                    Write-Host ("Detected total pages: {0}" -f $maxPages)
                }
            }

            # Functionality to parse album nodes from a loaded $doc
            # Albums are found in xpath //*[@id="artist"]/section[2]/div[2]/ul/li/div
            $albumLis = $doc.SelectNodes('//*[@id="artist"]/section[2]/div[2]/ul/li')
            if (-not $albumLis) { Write-Verbose "No album li elements found on page $page"; }

            foreach ($li in @($albumLis)) {
                # Extract nodes using relative XPaths
                $artistNode = $li.SelectSingleNode('div/div[2]/p[1]/a')
                $albumNode = $li.SelectSingleNode('div/div[2]/a/h3')
                $genreNode = $li.SelectSingleNode('div/div[1]/a/div/p[1]')
                $dateNode = $li.SelectSingleNode('div/div[1]/a/div/p[2]')
                $urlNode = $li.SelectSingleNode('div/div[1]/a')

                if (-not $albumNode -or -not $urlNode) { continue }

                # Album name
                $albumName = $albumNode.InnerText.Trim()
                if ([string]::IsNullOrWhiteSpace($albumName)) { continue }

                # Decode HTML entities
                $albumName = [System.Web.HttpUtility]::HtmlDecode($albumName)

                # Album URL and ID extraction
                $href = $urlNode.GetAttributeValue('href', '')
                if (-not $href -or -not $href.Contains('/album/')) { continue }

                if ($href -match '^[^?#]+') { $hrefClean = $matches[0] } else { $hrefClean = $href }
                if ($hrefClean -match '/album/[^/]+/([^/?#]+)$') {
                    $albumId = $matches[1]
                } else {
                    $parts = $hrefClean.TrimEnd('/').Split('/')
                    $albumId = $parts[-1]
                    if (-not $albumId) { continue }
                }
                if ($hrefClean -match '^https?://') { $albumUrl = $hrefClean } else { $albumUrl = "https://www.qobuz.com$hrefClean" }

                # Genre
                $genre = if ($genreNode) { $genreNode.InnerText.Trim() } else { '' }

                # Date - extract year
                $releaseDateText = if ($dateNode) { $dateNode.InnerText.Trim() } else { '' }
                if ($releaseDateText -match '(\d{4})') {
                    $year = $matches[1]
                } else {
                    $year = ''
                }

                # Cover URL from data-src
                $coverDiv = $li.SelectSingleNode('div/div[1]')
                $coverUrl = if ($coverDiv) { $coverDiv.GetAttributeValue('data-src', '') } else { '' }

                # Skip duplicates
                if ($seenIds.ContainsKey($albumId)) { continue }
                $seenIds[$albumId] = $true

                $albumObj = [PSCustomObject]@{
                    name         = $albumName
                    id           = $albumId
                    release_date = $year
                    genre        = $genre
                    url          = $albumUrl
                    artist       = $artist
                    cover_url    = $coverUrl
                }

                $allAlbums += $albumObj
            }

            # If we discovered total pages, fetch remaining pages directly (we've already processed page 1)
            if ($maxPages -and $page -eq 1) {
                for ($p = 2; $p -le $maxPages; $p++) {
                    $nextPageUrl = ("{0}/page/{1}" -f $artistBase.TrimEnd('/'), $p)
                    Write-Host ("Fetching Qobuz artist page: {0}" -f $nextPageUrl)
                    try {
                        $resp2 = Invoke-WebRequest -Uri $nextPageUrl -UseBasicParsing -ErrorAction Stop
                        $doc2 = ConvertFrom-Html -Content $resp2.Content
                    }
                    catch {
                        Write-Warning ("Failed to download/parse page {0}: {1}" -f $nextPageUrl, $_.Exception.Message)
                        break
                    }

                    $albumLis2 = $doc2.SelectNodes('//*[@id="artist"]/section[2]/div[2]/ul/li')
                    foreach ($li in @($albumLis2)) {
                        # Extract nodes using relative XPaths
                        $artistNode = $li.SelectSingleNode('div/div[2]/p[1]/a')
                        $albumNode = $li.SelectSingleNode('div/div[2]/a/h3')
                        $genreNode = $li.SelectSingleNode('div/div[1]/a/div/p[1]')
                        $dateNode = $li.SelectSingleNode('div/div[1]/a/div/p[2]')
                        $urlNode = $li.SelectSingleNode('div/div[1]/a')

                        if (-not $albumNode -or -not $urlNode) { continue }

                        # Album name
                        $albumName = $albumNode.InnerText.Trim()
                        if ([string]::IsNullOrWhiteSpace($albumName)) { continue }

                        # Decode HTML entities
                        $albumName = [System.Web.HttpUtility]::HtmlDecode($albumName)

                        # Album URL and ID extraction
                        $href = $urlNode.GetAttributeValue('href', '')
                        if (-not $href -or -not $href.Contains('/album/')) { continue }

                        if ($href -match '^[^?#]+') { $hrefClean = $matches[0] } else { $hrefClean = $href }
                        if ($hrefClean -match '/album/[^/]+/([^/?#]+)$') {
                            $albumId = $matches[1]
                        } else {
                            $parts = $hrefClean.TrimEnd('/').Split('/')
                            $albumId = $parts[-1]
                            if (-not $albumId) { continue }
                        }
                        if ($hrefClean -match '^https?://') { $albumUrl = $hrefClean } else { $albumUrl = "https://www.qobuz.com$hrefClean" }

                        # Genre
                        $genre = if ($genreNode) { $genreNode.InnerText.Trim() } else { '' }

                        # Date - extract year
                        $releaseDateText = if ($dateNode) { $dateNode.InnerText.Trim() } else { '' }
                        if ($releaseDateText -match '(\d{4})') {
                            $year = $matches[1]
                        } else {
                            $year = ''
                        }

                        # Cover URL from data-src
                        $coverDiv = $li.SelectSingleNode('div/div[1]')
                        $coverUrl = if ($coverDiv) { $coverDiv.GetAttributeValue('data-src', '') } else { '' }

                        # Skip duplicates
                        if ($seenIds.ContainsKey($albumId)) { continue }
                        $seenIds[$albumId] = $true

                        $albumObj = [PSCustomObject]@{
                            name         = $albumName
                            id           = $albumId
                            release_date = $year
                            genre        = $genre
                            url          = $albumUrl
                            artist       = $artist
                            cover_url    = $coverUrl
                        }

                        $allAlbums += $albumObj
                    }

                    Start-Sleep -Milliseconds 250
                } # end for pages

                break  # we've handled all pages via page-count method
            }

            # If we didn't discover a page count, try rel="next" fallback navigation
            $nextNode = $doc.SelectSingleNode('//a[@rel="next"]')
            if (-not $nextNode) {
                # Try paginator link that looks like /interpreter/.../page/2
                $candidate = $doc.SelectSingleNode('//a[contains(@href,"/page/") and contains(@href, "/interpreter/")]')
                if ($candidate) { $nextNode = $candidate }
            }

            if ($nextNode) {
                $nextHref = $nextNode.GetAttributeValue('href','').Trim()
                if (-not $nextHref) { break }

                # Resolve relative to qobuz host if needed
                if ($nextHref -match '^https?://') {
                    $pageUrl = $nextHref
                } else {
                    $pageUrl = "https://www.qobuz.com$nextHref"
                }

                # Prevent accidental infinite loops: stop if page grows too large (safety cap)
                $page++
                if ($page -gt $maxPagesCap) { Write-Warning ("Stopping pagination after {0} pages (cap reached)" -f $maxPagesCap); break }
                Start-Sleep -Milliseconds 250  # small throttle
                continue
            }
            else {
                break
            }
        } # end while

        return $allAlbums
    } # end process
}
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

        # Normalize base URL: accept either the full URL or the relative interpreter path
        if ($Id -match '^https?://') {
            $baseUrl = $Id.TrimEnd('/')
        } elseif ($Id -match '^/be-fr/interpreter/') {
            $baseUrl = "https://www.qobuz.com$Id".TrimEnd('/')
        } else {
            throw "Id must be either a full Qobuz interpreter URL or a path starting with '/be-fr/interpreter/'. Example: /be-fr/interpreter/artist-slug/12345"
        }

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
            $albumNodes = $doc.SelectNodes('//h3[contains(concat(" ", normalize-space(@class), " "), " product__name ")]')
            if (-not $albumNodes) { Write-Verbose "No album name nodes found on page $page"; }

            foreach ($nameNode in @($albumNodes)) {
                # Album name
                $albumName = $nameNode.InnerText.Trim()
                if ([string]::IsNullOrWhiteSpace($albumName)) { continue }

                # Decode HTML entities in the album name
                $albumName = [System.Web.HttpUtility]::HtmlDecode($albumName)

                # The <h3> is inside <a href="..."> — get the ancestor <a> (parent)
                $linkNode = $nameNode.ParentNode
                if (-not $linkNode) { continue }
                $href = $linkNode.GetAttributeValue('href', '')
                if (-not $href -or -not $href.Contains('/album/')) { continue }

                # Clean href (remove query/fragment)
                if ($href -match '^[^?#]+') { $hrefClean = $matches[0] } else { $hrefClean = $href }

                # Extract last path segment (slug/id) after /album/whatever/<slug>
                if ($hrefClean -match '/album/[^/]+/([^/?#]+)$') {
                    $albumId = $matches[1]
                }
                else {
                    # fallback: try last segment of path
                    $parts = $hrefClean.TrimEnd('/').Split('/')
                    $albumId = $parts[-1]
                    if (-not $albumId) { continue }
                }

                # Build full album URL
                if ($hrefClean -match '^https?://') { $albumUrl = $hrefClean } else { $albumUrl = "https://www.qobuz.com$hrefClean" }

                # Navigate up to the product__item to find release/genre info (sibling area)
                $parent = $linkNode.ParentNode   # product__container
                $item = if ($parent) { $parent.ParentNode } else { $null }  # product__item

                $releaseNode = $null
                $genreNode = $null
                if ($item) {
                    $releaseNode = $item.SelectSingleNode('.//p[contains(concat(" ", normalize-space(@class), " "), " product__data--release ")]')
                    $genreNode = $item.SelectSingleNode('.//p[contains(concat(" ", normalize-space(@class), " "), " product__data--genre ")]')
                }

                $releaseDate = if ($releaseNode) { $releaseNode.InnerText.Trim() } else { '' }
                $genre = if ($genreNode) { $genreNode.InnerText.Trim() } else { '' }

                # Skip duplicates by id
                if ($seenIds.ContainsKey($albumId)) { continue }
                $seenIds[$albumId] = $true

                $albumObj = [PSCustomObject]@{
                    name         = $albumName
                    id           = $albumId
                    release_date = $releaseDate
                    genre        = $genre
                    url          = $albumUrl
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

                    $albumNodes2 = $doc2.SelectNodes('//h3[contains(concat(" ", normalize-space(@class), " "), " product__name ")]')
                    foreach ($nameNode in @($albumNodes2)) {
                        $albumName = $nameNode.InnerText.Trim()
                        if ([string]::IsNullOrWhiteSpace($albumName)) { continue }

                        # Decode HTML entities in the album name
                        $albumName = [System.Web.HttpUtility]::HtmlDecode($albumName)

                        $linkNode = $nameNode.ParentNode
                        if (-not $linkNode) { continue }
                        $href = $linkNode.GetAttributeValue('href', '')
                        if (-not $href -or -not $href.Contains('/album/')) { continue }
                        if ($href -match '^[^?#]+') { $hrefClean = $matches[0] } else { $hrefClean = $href }
                        if ($hrefClean -match '/album/[^/]+/([^/?#]+)$') { $albumId = $matches[1] }
                        else {
                            $parts = $hrefClean.TrimEnd('/').Split('/')
                            $albumId = $parts[-1]
                            if (-not $albumId) { continue }
                        }
                        if ($hrefClean -match '^https?://') { $albumUrl = $hrefClean } else { $albumUrl = "https://www.qobuz.com$hrefClean" }

                        $parent = $linkNode.ParentNode
                        $item = if ($parent) { $parent.ParentNode } else { $null }

                        $releaseNode = $null
                        $genreNode = $null
                        if ($item) {
                            $releaseNode = $item.SelectSingleNode('.//p[contains(concat(" ", normalize-space(@class), " "), " product__data--release ")]')
                            $genreNode = $item.SelectSingleNode('.//p[contains(concat(" ", normalize-space(@class), " "), " product__data--genre ")]')
                        }

                        $releaseDate = if ($releaseNode) { $releaseNode.InnerText.Trim() } else { '' }
                        $genre = if ($genreNode) { $genreNode.InnerText.Trim() } else { '' }

                        if ($seenIds.ContainsKey($albumId)) { continue }
                        $seenIds[$albumId] = $true

                        $albumObj = [PSCustomObject]@{
                            name         = $albumName
                            id           = $albumId
                            release_date = $releaseDate
                            genre        = $genre
                            url          = $albumUrl
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
# Private/QSearch-Item.ps1
function Search-QItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Query,

        [Parameter(Mandatory = $true)]
        [ValidateSet('artist')]
        [string]$Type
    )

    if ($Type -ne 'artist') {
        throw "Only 'artist' type is supported for Qobuz search."
    }

    # Ensure PowerHTML is available
    if (-not (Get-Module -Name PowerHTML -ListAvailable)) {
        throw "PowerHTML module is required but not installed. Install it with: Install-Module PowerHTML"
    }
    Import-Module PowerHTML

    # Load System.Web for HTML decoding
    Add-Type -AssemblyName System.Web

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
        if (-not $cards -or $cards.Count -eq 0) {
            $cards = $doc.SelectNodes('//div[@class="FollowingCard"]')
        }

        $items = @()
        foreach ($card in $cards) {
            $title = $card.GetAttributeValue('title', '')
            # fallback: some card variants embed the artist link in a child node
            if (-not $title) {
                $titleNode = $card.SelectSingleNode('./div[1]/p[1]/a')
                if ($titleNode) { $title = $titleNode.InnerText.Trim() }
            }
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
            $genres = @()
 

            # Create the item object (similar to Spotify structure)
            $item = [PSCustomObject]@{
                name   = $title
                id     = $hrefClean
                url    = $fullUrl
                genres = $genres
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
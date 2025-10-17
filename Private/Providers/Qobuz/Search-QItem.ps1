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

    # Construct the search URL (using be-fr as default locale; could be parameterized)
    $url = "https://www.qobuz.com/be-fr/search/artists/$([uri]::EscapeDataString($Query))"
   
    try {
        # Fetch the HTML
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing
        $html = $response.Content

        # Parse with PowerHTML
        $doc = ConvertFrom-Html -Content $html

        # Select all FollowingCard divs
        $cards = $doc.SelectNodes('//div[@class="FollowingCard"]')

        $items = @()
        foreach ($card in $cards) {
            $title = $card.GetAttributeValue('title', '')
            if (-not $title) { continue }

            # Decode HTML entities in the title
            $title = [System.Web.HttpUtility]::HtmlDecode($title)

            # Extract the link
            $link = $card.SelectSingleNode('.//a[@class="CoverModelOverlay"]')
            if (-not $link) { continue }

            $href = $link.GetAttributeValue('href', '')
            if (-not $href) { continue }

            # Parse the href to extract ID (e.g., /be-fr/interpreter/zz-top/56332 -> 56332)
            if ($href -match '/interpreter/[^/]+/(\d+)$') {
              #  $id = $matches[1]
            } else {
                continue  # Skip if no ID
            }
            $genres = @()
 

            # Create the item object (similar to Spotify structure)
            $item = [PSCustomObject]@{
                name   = $title
                id     = $href
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
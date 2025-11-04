function Parse-QobuzReleaseCard {
    <#
    .SYNOPSIS
        Parse a Qobuz ReleaseCard HTML node (PowerHTML node) and return a raw album object.
    .PARAMETER Card
        The PowerHTML node representing the release card div.
    .OUTPUTS PSCustomObject
        Raw album object with common fields used by Normalize-AlbumResult.
    #>
    param(
        [Parameter(Mandatory=$true)]
        $Card
    )

    Add-Type -AssemblyName System.Web

    try {
        $titleLink = $Card.SelectSingleNode("./div[1]/a")
        $name = if ($titleLink) { $titleLink.GetAttributeValue("data-title", "").Trim() } else { "" }
        if ($name) { $name = [System.Web.HttpUtility]::HtmlDecode($name).Trim() }

        $albumLink = $Card.SelectSingleNode("./a")
        $href = if ($albumLink) { $albumLink.GetAttributeValue("href", "") } else { "" }
        if ($href -match '^[^?#]+') { $hrefClean = $matches[0] } else { $hrefClean = $href }

        $artistLink = $Card.SelectSingleNode("./div[1]/p[1]/a")
        $artist = if ($artistLink) { $artistLink.InnerText.Trim() } else { "" }
        if ($artist) { $artist = [System.Web.HttpUtility]::HtmlDecode($artist).Trim() }

        $genreElement = $Card.SelectSingleNode("./a/div/p[1]")
        $genre = if ($genreElement) { [System.Web.HttpUtility]::HtmlDecode($genreElement.InnerText.Trim()) } else { "" }

        $dateNode = $Card.SelectSingleNode("./a/div/p[2]")
        $releaseDate = if ($dateNode) { [System.Web.HttpUtility]::HtmlDecode($dateNode.InnerText.Trim()) } else { "" }

        # Prefer a simple 4-digit year for quick-search results when possible
        if ($releaseDate -and $releaseDate -match '(\d{4})') {
            $releaseDate = $matches[1]
        }
        else {
            # Fallback: try to find a 4-digit year in the card HTML/text
            try {
                $cardHtml = if ($Card.OuterHtml) { $Card.OuterHtml } else { $Card.InnerText }
            } catch {
                $cardHtml = $Card.InnerText
            }
            $m = [regex]::Match($cardHtml, '([12]\d{3})')
            if ($m.Success) { $releaseDate = $m.Groups[1].Value }
        }

        $trackNode = $Card.SelectSingleNode("./a/div/p[3]")
        $trackCount = $null
        if ($trackNode) {
            if ($trackNode.InnerText -match '(\d{1,3})') { $trackCount = [int]$matches[1] }
        }

        $coverImg = $Card.SelectSingleNode("./img")
        $coverUrl = if ($coverImg) { $coverImg.GetAttributeValue("src", "") } else { "" }

        # Try to extract album id from href
        $albumId = $null
        if ($hrefClean -match '/album/[^/]+/([^/?#]+)$') { $albumId = $matches[1] }
        else {
            $parts = $hrefClean.TrimEnd('/').Split('/')
            if ($parts.Count -gt 0) { $albumId = $parts[-1] }
        }

        $raw = [PSCustomObject]@{
            id = $albumId
            url = if ($href) { "https://www.qobuz.com$href" } else { $null }
            name = $name
            artist = $artist
            genres = $genre
            cover_url = $coverUrl
            track_count = $trackCount
            release_date = $releaseDate
        }

        return $raw
    }
    catch {
        Write-Verbose "Parse-QobuzReleaseCard failed: $_"
        return $null
    }
}

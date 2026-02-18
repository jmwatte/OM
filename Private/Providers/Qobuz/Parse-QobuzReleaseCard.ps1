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
        # New Qobuz structure: card div has id="release-card-grid-{albumId}"
        # Contains: ./a (cover link with title attr), .//div[gap-2]/a[@title] (album title link),
        #           .//div[gap-2]//div[items-center]/a (artist link), .//img (cover),
        #           .//span[text-invert] (genre), .//div[text-secondary typo-main]/span (date, tracks)

        # Album title from the text link below the cover
        $titleLink = $Card.SelectSingleNode(".//div[contains(@class,'gap-2')]/a[@title]")
        $name = if ($titleLink) { $titleLink.GetAttributeValue("title", "").Trim() } else { "" }
        if (-not $name -and $titleLink) { $name = $titleLink.InnerText.Trim() }
        if ($name) { $name = [System.Web.HttpUtility]::HtmlDecode($name).Trim() }

        # Album URL from the cover link or title link
        $albumLink = $Card.SelectSingleNode("./a")
        $href = if ($albumLink) { $albumLink.GetAttributeValue("href", "") } else { "" }
        if (-not $href -and $titleLink) { $href = $titleLink.GetAttributeValue("href", "") }
        if ($href -match '^[^?#]+') { $hrefClean = $matches[0] } else { $hrefClean = $href }

        # Artist name from the interpreter link
        $artistLink = $Card.SelectSingleNode(".//div[contains(@class,'gap-2')]//div[contains(@class,'items-center')]/a")
        $artist = if ($artistLink) { $artistLink.InnerText.Trim() } else { "" }
        if ($artist) { $artist = [System.Web.HttpUtility]::HtmlDecode($artist).Trim() }

        # Genre from the overlay span
        $genreElement = $Card.SelectSingleNode(".//span[contains(@class,'text-invert')]")
        $genre = if ($genreElement) { [System.Web.HttpUtility]::HtmlDecode($genreElement.InnerText.Trim()) } else { "" }

        # Date and track count from overlay metadata
        $metaDiv = $Card.SelectSingleNode(".//div[contains(@class,'text-secondary') and contains(@class,'typo-main')]")
        $metaSpans = if ($metaDiv) { $metaDiv.SelectNodes("./span") } else { $null }
        $releaseDate = if ($metaSpans -and $metaSpans.Count -ge 1) { [System.Web.HttpUtility]::HtmlDecode($metaSpans[0].InnerText.Trim()) } else { "" }

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

        $trackCount = $null
        if ($metaSpans -and $metaSpans.Count -ge 2) {
            if ($metaSpans[1].InnerText -match '(\d{1,3})') { $trackCount = [int]$matches[1] }
        }

        # Cover image
        $coverImg = $Card.SelectSingleNode(".//img[contains(@class,'aspect-square')]")
        if (-not $coverImg) { $coverImg = $Card.SelectSingleNode(".//img") }
        $coverUrl = if ($coverImg) { $coverImg.GetAttributeValue("src", "") } else { "" }

        # Album ID from card id attribute or href
        $albumId = $null
        $cardIdAttr = $Card.GetAttributeValue('id', '')
        if ($cardIdAttr -match '^release-card-grid-(.+)$') {
            $albumId = $matches[1]
        }
        elseif ($hrefClean -match '/album/[^/]+/([^/?#]+)$') { $albumId = $matches[1] }
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

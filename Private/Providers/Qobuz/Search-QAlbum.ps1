function Search-QAlbum {
    <#
    .SYNOPSIS
        Search Qobuz for albums by artist and album name using the search page.
    
    .DESCRIPTION
        Constructs a search URL for Qobuz albums and scrapes the results from the search page.
        Extracts album information including title, artist, release date, track count, genre, and cover image.
    
    .PARAMETER ArtistName
        The artist name to search for.
    
    .PARAMETER AlbumName
        The album name to search for.
    
    .EXAMPLE
        Search-QAlbum -ArtistName "Paul Weller" -AlbumName "Heavy Soul"
        Searches for albums matching "Paul Weller Heavy Soul" and returns matching results.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ArtistName,

        [Parameter(Mandatory)]
        [string]$AlbumName
    )

    begin {
        if (-not (Get-Module -Name PowerHTML -ListAvailable)) {
            throw "PowerHTML module is required but not installed. Install it with: Install-Module PowerHTML"
        }
        Import-Module PowerHTML -ErrorAction Stop
        # Ensure OM module is loaded so helpers are available
        # try { Import-Module OM -Force -ErrorAction Stop } catch { Write-Verbose "Failed to import OM module: $_" }
        # Load System.Web for HTML decoding
        Add-Type -AssemblyName System.Web
    }

    process {
        $locale = Get-QobuzUrlLocale
        # Construct search query by combining artist and album name
        $searchQuery = "$ArtistName $AlbumName".Trim()
        # Use URI escaping so spaces become %20 instead of '+' (matches desired URL format)
        $encodedQuery = [System.Uri]::EscapeDataString($searchQuery)
        $url = "https://www.qobuz.com/$locale/search/albums/$encodedQuery"

        Write-Verbose "Searching Qobuz albums with query: $searchQuery"
        Write-Verbose "Search URL: $url"

        try {
            $resp = Invoke-WebRequest -Uri $url -UseBasicParsing -ErrorAction Stop
            $html = $resp.Content
        }
        catch {
            Write-Warning ("Failed to fetch search results: {0}" -f $_.Exception.Message)
            return @()
        }

        try {
            $doc = ConvertFrom-Html -Content $html
        }
        catch {
            Write-Warning ("Failed to parse HTML: {0}" -f $_.Exception.Message)
            return @()
        }

        # Find all ReleaseCard divs
        $releaseCards = $doc.SelectNodes("//*[@id='search']/section[2]/div/ul/li/div")
        
        if (-not $releaseCards -or $releaseCards.Count -eq 0) {
            Write-Verbose "No ReleaseCard elements found in search results"
            return @()
        }

        Write-Verbose "Found $($releaseCards.Count) album cards"

        $albums = @()

        foreach ($card in $releaseCards) {
            try {
                # Extract album title
                $titleLink = $card.SelectSingleNode("./div[1]/a")
                $QalbumName = if ($titleLink) { 
                    $titleLink.GetAttributeValue("data-title", "").Trim() 
                } else { 
                    "" 
                }
                # Decode HTML entities (e.g. &#039; -> ')
                if ($QalbumName) { $QalbumName = [System.Web.HttpUtility]::HtmlDecode($QalbumName).Trim() }

                if (-not $QalbumName) {
                    Write-Verbose "Skipping card without album title"
                    continue
                }

                # Extract album ID from href (last path segment)
                $albumLink = $card.SelectSingleNode("./a")
                $albumHref = if ($albumLink) { $albumLink.GetAttributeValue("href", "") } else { "" }
                # Clean href (remove query/fragment)
                if ($albumHref -match '^[^?#]+') { $hrefClean = $matches[0] } else { $hrefClean = $albumHref }
                if ($hrefClean -match '/album/[^/]+/([^/?#]+)$') { $albumId = $matches[1] } else {
                    # Fallback: use last segment of path
                    $parts = $hrefClean.TrimEnd('/').Split('/')
                    $albumId = if ($parts.Count -gt 0) { $parts[-1] } else { "" }
                }

                # Extract artist name
                $artistLink = $card.SelectSingleNode("./div[1]/p[1]/a")
                $QartistName = if ($artistLink) { $artistLink.InnerText.Trim() } else { "" }
                if ($QartistName) { $QartistName = [System.Web.HttpUtility]::HtmlDecode($QartistName).Trim() }

                # Extract genre (first paragraph inside the album anchor/cover block)
                $genreElement = $card.SelectSingleNode("./a/div/p[1]")
                $genre = if ($genreElement) { [System.Web.HttpUtility]::HtmlDecode($genreElement.InnerText.Trim()) } else { "" }

                # Extract release date and track count using specific XPath nodes when available
                $dateNode = $card.SelectSingleNode("./a/div/p[2]")
                $releaseDate = if ($dateNode) { [System.Web.HttpUtility]::HtmlDecode($dateNode.InnerText.Trim()) } else { "" }

                $trackNode = $card.SelectSingleNode("./a/div/p[3]")
                $trackCount = $null
                if ($trackNode) {
                    if ($trackNode.InnerText -match '(\d{1,3})') {
                        $trackCount = [int]$matches[1]
                    }
                }

                # Fallback: older class-based markup
                if (-not $releaseDate -or -not $trackCount) {
                    $dataElements = $card.SelectNodes(".//p[contains(concat(' ', normalize-space(@class), ' '), ' CoverModelDataDefault ') and contains(concat(' ', normalize-space(@class), ' '), ' ReleaseCardActionsText ')]")
                    if ($dataElements) {
                        foreach ($element in $dataElements) {
                            $text = [System.Web.HttpUtility]::HtmlDecode($element.InnerText.Trim())
                            if (-not $releaseDate -and ($text -match '\b(janv|févr|mars|avr|mai|juin|juil|août|sept|oct|nov|déc|jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec|\d{1,2}\s+\w+\s+\d{4}|\d{4})\b')) {
                                $releaseDate = $text
                            }
                            elseif (-not $trackCount -and ($text -match '(\d{1,3})')) {
                                # Avoid interpreting a 4-digit year as a track count
                                $candidate = [int]$matches[1]
                                if ($candidate -lt 1000) { $trackCount = $candidate }
                            }
                        }
                    }
                }

                # Extract cover image
                $coverImg = $card.SelectSingleNode("./img")
                $coverUrl = if ($coverImg) { $coverImg.GetAttributeValue("src", "") } else { "" }

                # Create album object
                $album = [PSCustomObject]@{
                    id           = $albumId
                    name         = $QalbumName
                    artist       = $QartistName
                    release_date = $releaseDate
                    track_count  = $trackCount
                    genre        = $genre
                    cover_url    = $coverUrl
                    url          = if ($albumHref) { "https://www.qobuz.com$albumHref" } else { "" }
                }

                $albums += $album
                Write-Verbose "Extracted album: $($album.name) by $($album.artist)"

            }
            catch {
                Write-Verbose "Failed to parse album card: $_"
                continue
            }
        }

        Write-Verbose "Successfully extracted $($albums.Count) albums from search results"
        # Precompute similarity scores in module scope (avoids scriptblock resolution issues)
        foreach ($a in $albums) {
            if (Get-Command -Name Get-StringSimilarity-Jaccard -ErrorAction SilentlyContinue) {
                $nameSim = Get-StringSimilarity-Jaccard -String1 $a.name -String2 $AlbumName
                $artistSim = Get-StringSimilarity-Jaccard -String1 $a.artist -String2 $ArtistName
                $a | Add-Member -MemberType NoteProperty -Name '__similarity' -Value (($nameSim * 0.7) + ($artistSim * 0.3)) -Force
            }
            else {
                $a | Add-Member -MemberType NoteProperty -Name '__similarity' -Value 0 -Force
            }
        }

        $albums = $albums | Sort-Object -Property '__similarity' -Descending
        #take the albums where the artist is similar to the artist provided
        $albums = $albums | Where-Object {
            if (Get-Command -Name Get-StringSimilarity-Jaccard -ErrorAction SilentlyContinue) {
                $artistSim = Get-StringSimilarity-Jaccard -String1 $_.artist -String2 $ArtistName
                return $artistSim -ge 0.3
            }
            else {
                return $true
            }
        }
        return $albums
    }
}
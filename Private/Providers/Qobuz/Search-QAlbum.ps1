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
        # Construct search query by combining artist and album name
        $searchQuery = "$ArtistName $AlbumName".Trim()
        # Use URI escaping so spaces become %20 instead of '+' (matches desired URL format)
        $encodedQuery = [System.Uri]::EscapeDataString($searchQuery)
        $url = "https://www.qobuz.com/be-fr/search/albums/$encodedQuery"

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
        $releaseCards = $doc.SelectNodes("//div[contains(concat(' ', normalize-space(@class), ' '), ' ReleaseCard ')]")
        
        if (-not $releaseCards -or $releaseCards.Count -eq 0) {
            Write-Verbose "No ReleaseCard elements found in search results"
            return @()
        }

        Write-Verbose "Found $($releaseCards.Count) album cards"

        $albums = @()

        foreach ($card in $releaseCards) {
            try {
                # Extract album title
                $titleLink = $card.SelectSingleNode(".//a[contains(concat(' ', normalize-space(@class), ' '), ' ReleaseCardInfosTitle ')]")
                $QalbumName = if ($titleLink) { 
                    $titleLink.GetAttributeValue("data-title", "").Trim() 
                } else { 
                    "" 
                }

                if (-not $QalbumName) {
                    Write-Verbose "Skipping card without album title"
                    continue
                }

                # Extract album ID from href (last path segment)
                $albumHref = if ($titleLink) { $titleLink.GetAttributeValue("href", "") } else { "" }
                # Clean href (remove query/fragment)
                if ($albumHref -match '^[^?#]+') { $hrefClean = $matches[0] } else { $hrefClean = $albumHref }
                if ($hrefClean -match '/album/[^/]+/([^/?#]+)$') { $albumId = $matches[1] } else {
                    # Fallback: use last segment of path
                    $parts = $hrefClean.TrimEnd('/').Split('/')
                    $albumId = if ($parts.Count -gt 0) { $parts[-1] } else { "" }
                }

                # Extract artist name
                $artistLink = $card.SelectSingleNode(".//p[contains(concat(' ', normalize-space(@class), ' '), ' ReleaseCardInfosSubtitle ')]//a")
                $QartistName = if ($artistLink) { $artistLink.InnerText.Trim() } else { "" }

                # Extract genre
                $genreElement = $card.SelectSingleNode(".//p[contains(concat(' ', normalize-space(@class), ' '), ' CoverModelDataBold ') and contains(concat(' ', normalize-space(@class), ' '), ' ReleaseCardInfosSubtitle ')]")
                $genre = if ($genreElement) { $genreElement.InnerText.Trim() } else { "" }

                # Extract release date and track count from CoverModelDataDefault elements
                $dataElements = $card.SelectNodes(".//p[contains(concat(' ', normalize-space(@class), ' '), ' CoverModelDataDefault ') and contains(concat(' ', normalize-space(@class), ' '), ' ReleaseCardActionsText ')]")
                
                $releaseDate = ""
                $trackCount = $null
                
                foreach ($element in $dataElements) {
                    $text = $element.InnerText.Trim()
                    
                    # Check if it's a date (contains month names or numbers)
                    if ($text -match '\b(janv|févr|mars|avr|mai|juin|juil|août|sept|oct|nov|déc|jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec|\d{1,2}\s+\w+\s+\d{4}|\d{4})\b') {
                        $releaseDate = $text
                    }
                    # Check if it's track count (contains "piste" or "track")
                    elseif ($text -match '(\d+)\s*(piste|pistes|track|tracks)') {
                        $trackCount = [int]$matches[1]
                    }
                }

                # Extract cover image
                $coverImg = $card.SelectSingleNode(".//img[contains(concat(' ', normalize-space(@class), ' '), ' CoverModel ')]")
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
                Write-Verbose "Extracted album: $($Qalbum.name) by $($Qartist.name)"

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
            } else {
                $a | Add-Member -MemberType NoteProperty -Name '__similarity' -Value 0 -Force
            }
        }

        $albums = $albums | Sort-Object -Property '__similarity' -Descending
        #take the albums where the artist is similar to the artist provided
$albums = $albums | Where-Object {
            if (Get-Command -Name Get-StringSimilarity-Jaccard -ErrorAction SilentlyContinue) {
                $artistSim = Get-StringSimilarity-Jaccard -String1 $_.artist -String2 $ArtistName
                return $artistSim -ge 0.3
            } else {
                return $true
            }
        }
        return $albums
    }
}
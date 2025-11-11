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

        # Helpers are loaded at module import time by OM.psm1
    }

    process {
        $locale = Get-QobuzUrlLocale
        
        # Construct Qobuz search URL with artist filter
        # Format: /search/albums/<album_query>?ssf[s]=main_catalog&ssf[f][an]=<artist_name>
        $encodedAlbum = [System.Uri]::EscapeDataString($AlbumName)
        $encodedArtist = [System.Uri]::EscapeDataString($ArtistName)
        $url = "https://www.qobuz.com/$locale/search/albums/$encodedAlbum`?ssf%5Bs%5D=main_catalog&ssf%5Bf%5D%5Ban%5D=$encodedArtist"

        Write-Verbose "Searching Qobuz albums: Artist='$ArtistName', Album='$AlbumName'"
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
            $raw = $null
            try {
                if (Get-Command -Name Parse-QobuzReleaseCard -ErrorAction SilentlyContinue) {
                    $raw = Parse-QobuzReleaseCard -Card $card
                }
                else {
                    # Fallback to minimal inline parsing
                    $titleLink = $card.SelectSingleNode("./div[1]/a")
                    $n = if ($titleLink) { [System.Web.HttpUtility]::HtmlDecode($titleLink.GetAttributeValue("data-title","")) } else { "" }
                    $raw = [PSCustomObject]@{ name = $n }
                }

                if (-not $raw) { continue }

                if (Get-Command -Name Normalize-AlbumResult -ErrorAction SilentlyContinue) {
                    $norm = Normalize-AlbumResult -Raw $raw
                    if ($norm) { $albums += $norm }
                } else {
                    $albums += $raw
                }
            }
            catch {
                Write-Verbose "Failed to parse/normalize album card: $_"
                continue
            }
        }

        Write-Verbose "Successfully extracted $($albums.Count) albums from search results"
        return $albums
    }
}
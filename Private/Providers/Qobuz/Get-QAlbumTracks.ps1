# Private/QGet-AlbumTracks.ps1
function Get-GtmProductField {
    param (
        [Parameter(Mandatory)]
        [string]$GtmRaw,

        [Parameter(Mandatory)]
        [string]$FieldName
    )

    try {
        # Decode HTML entities
        $decoded = [System.Net.WebUtility]::HtmlDecode($GtmRaw)

        # Convert to JSON
        $json = $decoded | ConvertFrom-Json

        # Extract the field from the product object
        if ($json.product.PSObject.Properties.Name -contains $FieldName) {
            return $json.product.$FieldName
        }
        else {
            Write-Warning "Field '$FieldName' not found in product data."
            return $null
        }
    }
    catch {
        Write-Error "Failed to parse data-gtm: $_"
        return $null
    }
}

function Get-TrackV2Field {
    param (
        [Parameter(Mandatory)]
        [string]$TrackV2Raw,

        [Parameter(Mandatory)]
        [string]$FieldName
    )

    try {
        # Decode HTML entities
        $decoded = [System.Net.WebUtility]::HtmlDecode($TrackV2Raw)

        # Convert to JSON
        $json = $decoded | ConvertFrom-Json

        # Extract the field directly from the root object
        if ($json.PSObject.Properties.Name -contains $FieldName) {
            return $json.$FieldName
        }
        else {
            return $null
        }
    }
    catch {
        Write-Verbose "Failed to parse data-track-v2 for field '$FieldName': $_"
        return $null
    }
}
# filepath: c:\Users\resto\Documents\PowerShell\Modules\MuFo\Private\Get-QAlbumTracks.ps1
function Get-QAlbumTracks {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Live')]
        [string]$Id,

        [Parameter(Mandatory = $true, ParameterSetName = 'Local')]
        [string]$HtmlFile   # optional: path to a saved HTML file for offline testing
    )

    begin {
        if (-not (Get-Module -Name PowerHTML -ListAvailable)) {
            throw "PowerHTML module is required but not installed. Install it with: Install-Module PowerHTML"
        }
        Import-Module PowerHTML -ErrorAction Stop
         # Load System.Web for HTML decoding
        Add-Type -AssemblyName System.Web
    }

    process {
        if ($HtmlFile) {
            if (-not (Test-Path $HtmlFile)) { throw "HtmlFile not found: $HtmlFile" }
            Write-Verbose ("Loaded HTML from file: {0}" -f $HtmlFile)

            # If HTML fixture is provided, prefer the stable helper parser implemented in Private\Get-TracksFromHtml.ps1
            try {
                . "$PSScriptRoot\..\Get-TracksFromHtml.ps1"
                $parsed = Get-TracksFromHtml -Path $HtmlFile
                if ($parsed) {
                    # Ensure provider-canonical shape for downstream consumers
                    $normalized = @()
                    foreach ($p in $parsed) {
                        $id = $p.id
                        $name = $p.name
                        if (-not $name -and $p.Title) { $name = $p.Title }
                        $disc = $null
                        if ($p.PSObject.Properties['DiscNumber']) { $disc = $p.DiscNumber }
                        elseif ($p.PSObject.Properties['disc_number']) { $disc = $p.disc_number }
                        elseif ($p.PSObject.Properties['disc']) { $disc = $p.disc }

                        $track = $null
                        if ($p.PSObject.Properties['TrackNumber']) { $track = $p.TrackNumber }
                        elseif ($p.PSObject.Properties['track_number']) { $track = $p.track_number }
                        elseif ($p.PSObject.Properties['track']) { $track = $p.track }

                        $duration = $null
                        if ($p.PSObject.Properties['duration_ms']) { $duration = $p.duration_ms }
                        elseif ($p.PSObject.Properties['duration']) { $duration = $p.duration }

                        $obj = [PSCustomObject]@{
                            id                 = $id
                            name               = $name
                            Title              = $name
                            disc_number        = $disc
                            DiscNumber         = $disc
                            track_number       = $track
                            TrackNumber        = $track
                            duration_ms        = $duration
                            duration           = if ($duration -and $duration -is [int]) { [math]::Round($duration / 1000) } else { $duration }
                            Artist             = ($(if ($p.PSObject.Properties['Artist']) { $p.Artist } elseif ($p.PSObject.Properties['artist']) { $p.artist } else { '' }))
                            artists            = @()
                            _RawProviderObject = $p
                        }

                        # try to populate artists array if an Artist string exists
                        if ($obj.Artist -and $obj.Artist -ne '') {
                            $obj.artists += [pscustomobject]@{ name = $obj.Artist }
                        }

                        $normalized += $obj
                    }

                    return $normalized
                }
            }
            catch {
                Write-Warning "Get-TracksFromHtml failed, falling back to inline parsing: $($_.Exception.Message)"
                $html = Get-Content -Raw -Path $HtmlFile
            }
        }
        else {
            # Use the URL as-is if it's already a full URL, otherwise construct it

            #TODO we should not construct a url with an ID because these are no constant over all locales so we should just take the html and use that
            if ($Id -match '^https?://') { $url = $Id }
            #if ($Id -match '^https?://') { $url = $Id.TrimEnd('/') }
            else {
                $locale = Get-QobuzUrlLocale
                if ($Id -match '^/[a-z]{2}-[a-z]{2}/album/') { $url = "https://www.qobuz.com$($Id.TrimEnd('/'))" }
                else { $url = "https://www.qobuz.com/$locale/album/$Id"; Write-Verbose "Best-effort album URL built: $url" }
            }

            Write-Verbose ("Fetching Qobuz album page: {0}" -f $url)
            try {
                $resp = Invoke-WebRequest -Uri $url -UseBasicParsing -ErrorAction Stop
                $html = $resp.Content
            }
            catch {
                Write-Warning ("Failed to download album page {0}: {1}" -f $url, $_.Exception.Message)
                return @()
            }

            # when verbose, write the HTML to a temp file so you can inspect it
            if ($PSBoundParameters.ContainsKey('Verbose')) {
                $tmp = Join-Path $env:TEMP ("qobuz_album_{0}.html" -f ([guid]::NewGuid().ToString()))
                $html | Out-File -FilePath $tmp -Encoding utf8
                Write-Verbose ("Saved fetched HTML to: {0}" -f $tmp)
            }
        }

        try {
            $doc = ConvertFrom-Html -Content $html
        }
        catch {
            Write-Warning ("Failed to parse HTML: {0}" -f $_.Exception.Message)
            return @()
        }
        
        # Extract album metadata from JSON-LD structured data
        $releaseDate = $null
        $albumName = $null
        $albumArtistName = $null
        
        try {
            # Look for script tags with type="application/ld+json"
            # Use -AllMatches to get both Product and MusicAlbum schemas
            $jsonLdMatches = [regex]::Matches($html, '<script type="application/ld\+json">\s*(\{[^<]+\})\s*</script>')
            
            foreach ($match in $jsonLdMatches) {
                $jsonLdText = $match.Groups[1].Value
                $jsonLd = $jsonLdText | ConvertFrom-Json
                
                # Extract from Product schema (primary source)
                if ($jsonLd.'@type' -eq 'Product') {
                    if ($jsonLd.releaseDate) {
                        $releaseDate = $jsonLd.releaseDate
                        Write-Verbose "Extracted release date from Product JSON-LD: $releaseDate"
                    }
                    if ($jsonLd.name) {
                        $albumName = $jsonLd.name
                        Write-Verbose "Extracted album name from Product JSON-LD: $albumName"
                    }
                    if ($jsonLd.brand -and $jsonLd.brand.name) {
                        $albumArtistName = $jsonLd.brand.name
                        Write-Verbose "Extracted album artist from Product JSON-LD brand: $albumArtistName"
                    }
                }
                # Also check MusicAlbum schema as fallback
                elseif ($jsonLd.'@type' -eq 'MusicAlbum') {
                    if (-not $releaseDate -and $jsonLd.datePublished) {
                        $releaseDate = $jsonLd.datePublished
                        Write-Verbose "Extracted release date from MusicAlbum JSON-LD: $releaseDate"
                    }
                    if (-not $albumName -and $jsonLd.name) {
                        $albumName = $jsonLd.name
                        Write-Verbose "Extracted album name from MusicAlbum JSON-LD: $albumName"
                    }
                }
            }
        }
        catch {
            Write-Verbose "Could not extract metadata from JSON-LD: $_"
        }

        #     # Primary candidate nodes
        #     $allTrackNodes = $doc.SelectNodes('//*[@data-track]') 
        #     if (-not $allTrackNodes -or $allTrackNodes.Count -eq 0) {
        #         Write-Verbose "Selector //*[@data-track] found 0 nodes; trying fallback selector by class 'track'."
        #         $allTrackNodes = $doc.SelectNodes('//div[contains(concat(" ", normalize-space(@class), " "), " track ")]')
        #     } else {
        #         Write-Verbose ("Found {0} nodes with @data-track" -f $allTrackNodes.Count)
        #     }

        #     if (-not $allTrackNodes -or $allTrackNodes.Count -eq 0) {
        #         Write-Warning "No track nodes matched selectors; either page is client-rendered or markup differs."
        #         return @()
        #     }

        #     # Prepare output and dedupe map
        #    $tracks = @()


        #$trackContainer = $doc.SelectSingleNode("//*[@id='playerTracks']")
        $children = $doc.SelectNodes("//div[contains(concat(' ', normalize-space(@class), ' '), ' player__item ')]")
        #$trackContainer.ChildNodes
        $tracks = @()
        $currentWorkTitle = ""
        $currentDisc = "01"
        function ParsePerformer($inputb) {
            Write-Verbose "ParsePerformer called with: [$inputb]"
            
            # Decode HTML entities and strip Production Credits blocks early
            try {
                $decodedInput = [System.Web.HttpUtility]::HtmlDecode($inputb)
            } catch {
                $decodedInput = $inputb
            }

            # Remove any trailing '--- Production Credits ---' section and everything after it
            $cleanInput = $decodedInput -replace '(?is)---\s*Production\s+Credits\s*---.*$',''
            # Collapse multiple whitespace to single spaces and trim
            $cleanInput = ($cleanInput -replace '\s{2,}',' ') -replace '^\s+|\s+$',''

            if (-not $cleanInput -or $cleanInput -eq "Unknown Performer") {
                Write-Verbose "  -> Empty or Unknown Performer, returning empty result"
                return @{ 
                    Composers = @()
                    Performers = @()
                    MainArtists = @()
                    FeaturedArtists = @()
                    Conductor = $null
                    Ensemble = $null
                    FullCredits = ""
                    DetailedRoles = @{}
                }
            }

            # Store cleaned full credits for Comment field
            $fullCredits = $cleanInput

            # Parse format: "Name, Role, Role - Name, Role - Name, Role"
            $entries = $cleanInput -split " - "
            Write-Verbose "  -> Split into $($entries.Count) entries: $($entries -join ' | ')"
            $composers = @()
            $performers = @()
            $mainArtists = @()
            $featuredArtists = @()
            $conductor = $null
            $ensemble = $null
            $detailedRoles = @{}  # For display in Show-Tracks
            
            foreach ($entry in $entries) {
                $parts = $entry -split ", "
                if ($parts.Length -lt 2) { continue }
                
                $name = $parts[0].Trim()
                $roles = $parts[1..($parts.Length - 1)]
                
                # Store all roles for this person (for detailed display)
                $detailedRoles[$name] = $roles -join ", "
                
                # Detect ensemble/orchestra by name pattern (e.g., "Royal Philharmonic Orchestra", "il Gardellino")
                if ($name -match '(Orchestra|Ensemble|Philharmonic|Symphony|Quartet|Quintet|Trio)' -or $roles -contains 'Ensemble') {
                    if (-not $ensemble) {
                        $ensemble = $name
                    }
                    if ($name -notin $performers) {
                        $performers += $name
                    }
                }
                
                foreach ($role in $roles) {
                    $role = $role.Trim()
                    
                    # Extract Composers (including ComposerLyricist)
                    if ($role -match '^Composer') {
                        if ($name -notin $composers) {
                            $composers += $name
                        }
                    }
                    
                    # Extract Conductor (including StringsConductor)
                    if ($role -match 'Conductor') {
                        $conductor = $name
                        if ($name -notin $performers) {
                            $performers += $name
                        }
                    }
                    
                    # Extract Ensemble (explicit role)
                    if ($role -match '^Ensemble') {
                        $ensemble = $name
                        if ($name -notin $performers) {
                            $performers += $name
                        }
                    }
                    
                    # Extract MainArtist
                    if ($role -eq 'MainArtist' -or $role -eq 'Main Artist') {
                        if ($name -notin $mainArtists) {
                            $mainArtists += $name
                        }
                        if ($name -notin $performers) {
                            $performers += $name
                        }
                    }
                    
                    # Extract FeaturedArtist
                    if ($role -eq 'FeaturedArtist') {
                        if ($name -notin $featuredArtists) {
                            $featuredArtists += $name
                        }
                        if ($name -notin $performers) {
                            $performers += $name
                        }
                    }
                    
                    # Extract Vocalists
                    if ($role -eq 'Vocalist') {
                        if ($name -notin $performers) {
                            $performers += $name
                        }
                    }
                    
                    # Add other performer roles (Artist, Soloist, etc.)
                    if ($role -in @('Artist', 'Performer', 'Soloist', 'Instrumentalist')) {
                        if ($name -notin $performers) {
                            $performers += $name
                        }
                    }
                }
            }
            
            return @{
                Composers = $composers
                Performers = $performers
                MainArtists = $mainArtists
                FeaturedArtists = $featuredArtists
                Conductor = $conductor
                Ensemble = $ensemble
                FullCredits = $fullCredits
                DetailedRoles = $detailedRoles
            }
        }
        foreach ($node in $children) {
            $r = $node.SelectSingleNode('.//div[contains(concat(" ", normalize-space(@class), " "), " player__tracks ")]//p[contains(concat(" ", normalize-space(@class), " "), " player__work ")]')
            if ($r) {
                $currentWorkTitle = [System.Web.HttpUtility]::HtmlDecode($r.InnerText.Split("   ")[0].Trim())
                # $diskAttr = $node.GetAttributeValue("data-disk", $null)
                # if ($diskAttr) {
                #     $currentDisc = "DISQUE $diskAttr"
                # }
            }
            #  $trackNodes = $doc.SelectNodes("//div[contains(@class,'track') and @data-track]")
            $diskP = $node.SelectSingleNode('.//p[contains(concat(" ", normalize-space(@class), " "), " player__work ")][@data-disk]')
            $dataTrack = $node.SelectSingleNode(".//div[contains(@class,'track')and @data-track]").GetAttributes('data-track').value  
            if ($diskP) {
                $currentDisc = "{0:D2}" -f [int]($diskP.InnerText.Split(" ")[1])
            }

            $dataGtm = $node.SelectSingleNode(".//div[contains(@class,'track')and @data-track]").GetAttributes('data-gtm').value  
           
           
           
            # Extract genres from about section using XPath (prioritize this as it respects locale)
            $categoryGenre = $null
            $subCategoryGenre = $null
            $genreContainer = $doc.SelectSingleNode('//*[@id="about"]/ul[2]/li[4]')
            if ($genreContainer -and $genreContainer.InnerText -match 'genre:') {
                $genreLinks = $genreContainer.SelectNodes('./a')
                if ($genreLinks) {
                    $htmlGenres = @($genreLinks | ForEach-Object { $_.InnerText.Trim() } | Where-Object { $_ })
                    if ($htmlGenres.Count -gt 0) {
                        $categoryGenre = $htmlGenres[0]
                        if ($htmlGenres.Count -gt 1) {
                            $subCategoryGenre = $htmlGenres[1]
                        }
                    }
                }
            }

            # Fallback: If no genres found in HTML, try GTM data (though it may be in French)
            if (-not $categoryGenre) {
                $categoryGenre = Get-GtmProductField -GtmRaw $dataGtm -FieldName 'category'
            }
            if (-not $subCategoryGenre) {
                $subCategoryGenre = Get-GtmProductField -GtmRaw $dataGtm -FieldName 'subCategory'
            }
            
            # Extract additional metadata from data-track-v2 (label, quality, etc.)
            $dataTrackV2 = $node.SelectSingleNode(".//div[contains(@class,'track')and @data-track]").GetAttributes('data-track-v2').value
            $label = Get-TrackV2Field -TrackV2Raw $dataTrackV2 -FieldName 'item_category2'
            $quality = Get-TrackV2Field -TrackV2Raw $dataTrackV2 -FieldName 'item_variant_max'

            if ($node.SelectSingleNode(".//div[contains(@class,'track__items')]")) {
                $trackNode = $node.SelectSingleNode(".//div[contains(@class,'track__items')]")
                $title = [System.Web.HttpUtility]::HtmlDecode($trackNode.GetAttributeValue("title", "Unknown Title"))
                $durationNode = $trackNode.SelectSingleNode(".//span[contains(@class,'track__item--duration')]")
                $duration = if ($durationNode) { $durationNode.InnerText.Trim() } else { "Unknown Duration" }
                #duration should be in ms if format is "00:04:07"
                if ($duration -match '(\d{2}):(\d{2}):(\d{2})') {
                    $duration = [int]$matches[1] * 3600000 + [int]$matches[2] * 60000 + [int]$matches[3] * 1000
                }
                $trackNumberNode = $trackNode.SelectSingleNode(".//div[contains(@class,'track__item--number')]/span")
                $trackNumber = if ($trackNumberNode) { "{0:D2}" -f [int]($trackNumberNode.InnerText.Trim()) } else { "Unknown Number" }
                #$trackNumber = if ($trackNumberNode) { $trackNumberNode.InnerText.Trim() } else { "Unknown Number" }
                $infoNode = $node.SelectSingleNode(".//div[@class='track__infos']/p[@class='track__info']")
                $performerInfo = if ($infoNode) { $infoNode.InnerText.Trim() } else { "" }
                
                # DEBUG: Track artist extraction
                Write-Debug "`n=== TRACK $trackNumber DEBUG ==="
                Write-Debug "Title: $title"
                Write-Debug "Raw performerInfo: [$performerInfo]"
                Write-Debug "performerInfo length: $($performerInfo.Length) chars"
                
                $parsed = ParsePerformer $performerInfo
                
                Write-Debug "Parsed results:"
                Write-Debug "  Performers: $($parsed.Performers.Count) - [$($parsed.Performers -join '; ')]"
                Write-Debug "  MainArtists: $($parsed.MainArtists.Count) - [$($parsed.MainArtists -join '; ')]"
                Write-Debug "  Composers: $($parsed.Composers.Count) - [$($parsed.Composers -join '; ')]"
                Write-Debug "  Conductor: [$($parsed.Conductor)]"
                Write-Debug "  Ensemble: [$($parsed.Ensemble)]"

                # Build artists array from parsed performers and main artists
                $artists = @()
                foreach ($performer in $parsed.Performers) {
                    $artistType = if ($performer -in $parsed.MainArtists) { "main" } else { "artist" }
                    $artists += [PSCustomObject]@{ name = $performer; type = $artistType }
                }
                
                Write-Debug "Built artists array: $($artists.Count) items"
                if ($artists.Count -gt 0) {
                    foreach ($a in $artists) {
                        Write-Debug "  - $($a.name) (type: $($a.type))"
                    }
                }
                
                # Fallback: If no artist found, try to extract from data-gtm "item_brand" field (album artist)
                if ($artists.Count -eq 0) {
                    Write-Debug "No artists found, trying GTM fallback..."
                    try {
                        $albumArtist = Get-GtmProductField -GtmRaw $dataGtm -FieldName 'item_brand'
                        Write-Debug "  GTM item_brand: [$albumArtist]"
                        if ($albumArtist -and $albumArtist -ne '') {
                            $artists += [PSCustomObject]@{ name = $albumArtist; type = "album_artist" }
                            Write-Debug "  ✓ Using album artist fallback: $albumArtist"
                        } else {
                            Write-Debug "  ✗ GTM item_brand is empty"
                        }
                    } catch {
                        Write-Debug "  ✗ Could not extract album artist from GTM data: $_"
                    }
                }

                # Combine all composers with semicolon separator
                $composerString = if ($parsed.Composers.Count -gt 0) { 
                    $parsed.Composers -join '; ' 
                } else { 
                    $null 
                }

                $out = [PSCustomObject]@{
                    id           = ($dataTrack -replace '^id:', '')
                    name         = if ($currentWorkTitle) { $currentWorkTitle + "," + $title } else { $title }
                    Title        = if ($currentWorkTitle) { $currentWorkTitle + " ," + $title } else { $title }
                    disc_number  = $currentDisc
                    DiscNumber   = $currentDisc
                    track_number = $trackNumber
                    TrackNumber  = $trackNumber
                    duration_ms  = $duration
                    duration     = $duration
                    composer     = $composerString
                    Composers    = $composerString
                    Conductor    = $parsed.Conductor
                    Ensemble     = $parsed.Ensemble
                    FeaturedArtist = if ($parsed.FeaturedArtists.Count -gt 0) { $parsed.FeaturedArtists -join '; ' } else { $null }
                    # Provider-normalized artist fields (Qobuz track entries often lack explicit performers)
                    artists      = $artists
                    Artist       = if ($artists.Count -gt 0) { ($artists | ForEach-Object { $_.name }) -join '; ' } else { 'Unknown Artist' }
                    # Genres: include both category and subCategory if available (deduplicated)
                    genres       = @($categoryGenre, $subCategoryGenre) | Where-Object { $_ -ne $null -and $_ -ne '' } | Select-Object -Unique
                    # Additional metadata from Qobuz (label, quality, release date)
                    label        = $label
                    quality      = $quality
                    release_date = $releaseDate
                    album_name   = $albumName
                    album_artist = $albumArtistName
                    # Full production credits for Comment field
                    Comment      = $parsed.FullCredits
                    # Detailed role breakdown for Show-Tracks display
                    DetailedRoles = $parsed.DetailedRoles
                }


                <#  [PSCustomObject]@{
            Work      = $currentWorkTitle
            Disc      = $currentDisc
            Number    = $trackNumber
            Title     = $title
            Duration  = $duration
            Performer = $performerInfo
             Composer  = $parsed.Composer
            Artist    = $parsed.Artist
            MainArtist = $parsed.MainArtist
        } #>
            }
            $tracks += $out
        }
        # $processed = @{}
        # $script:anon = 0
        # $script:trackNumberCounter = 1

        #        function New-TrackFromNode($node, [int]$discNumber) {
        #     # determine stable key to avoid duplicates
        #     $tid = $node.GetAttributeValue('data-track','')
        #     if (-not $tid) { $tid = $node.GetAttributeValue('data-track-id','') }
        #     if (-not $tid) { $script:anon++; $tid = "anon-$script:anon"; $key = $tid } else { $key = "id:$tid" }
        
        #     if ($processed.ContainsKey($key)) { return $null }
        
        #     # title
        #     $titleNode = $node.SelectSingleNode('.//*[contains(concat(" ", normalize-space(@class), " "), " track__item--name ")]')
        #     if (-not $titleNode) { $titleNode = $node.SelectSingleNode('.//a[contains(@class,"track-title") or contains(@class,"track-name")]') }
        #     $title = if ($titleNode) { $titleNode.InnerText.Trim() } else { $node.InnerText.Trim() }
        
        #     # duration
        #     $dur = $node.GetAttributeValue('data-duration','')
        #     $durationMs = 0
        #     if ($dur -and $dur -match '^\d+$') {
        #         $num = [int]$dur
        #         $durationMs = ($num -lt 10000) ? ($num * 1000) : $num
        #     }

        #     # If duration not present as data-duration, try to parse visible duration text e.g. 00:03:45
        #     if ($durationMs -eq 0) {
        #         try {
        #             $durNode = $node.SelectSingleNode('.//*[contains(concat(" ", normalize-space(@class), " "), " track__item--duration ")]')
        #             if ($durNode -and $durNode.InnerText.Trim() -match '^(\d{1,2}):(\d{2})(?::(\d{2}))?$') {
        #                 $mm = [int]$matches[1]; $ss = [int]$matches[2]; $hh = 0
        #                 if ($matches[3]) { $hh = [int]$matches[3] }
        #                 $durationMs = (($hh * 3600) + ($mm * 60) + $ss) * 1000
        #             }
        #         } catch {
        #             # ignore
        #         }
        #     }
        
        #     # composer extraction: look in the track__infos block for a "Composer" mention
        #     $composer = ''
        #     $infosNode = $node.SelectSingleNode('.//div[contains(concat(" ", normalize-space(@class), " "), " track__infos ")]')
        #     if (-not $infosNode) {
        #         # some pages have the infos as siblings of the track node; try parent
        #         $parent = $node.ParentNode
        #         if ($parent) { $infosNode = $parent.SelectSingleNode('.//div[contains(concat(" ", normalize-space(@class), " "), " track__infos ")]') }
        #     }
        #     if ($infosNode) {
        #         $pNodes = $infosNode.SelectNodes('.//p[contains(concat(" ", normalize-space(@class), " "), " track__info ")]')
        #         if ($pNodes) {
        #             foreach ($p in @($pNodes)) {
        #                 $txt = $p.InnerText.Trim()
        #                 if ($txt -match '(?i)\bComposer\b') {
        #                     # prefer "Name, Composer" patterns
        #                     if ($txt -match '^\s*([^,]+)\s*,\s*Composer\b') {
        #                         $composer = $matches[1].Trim()
        #                     } elseif ($txt -match '^(.*?)\s*-\s*.*Composer\b') {
        #                         $composer = $matches[1].Trim()
        #                     } else {
        #                         # fallback: take first name-like token before a dash or comma
        #                         $composer = ($txt -split '[,-]')[0].Trim()
        #                     }
        #                     break
        #                 }
        #                 # If the infos block mentions Artist/Performer roles, try to extract performer names
        #                 elseif ($txt -match '(?i)\b(Artist|Performer|MainArtist|Main Performer)\b') {
        #                     try {
        #                         # Split on dash to separate composer part from performers (common pattern: "Composer - Performer, Artist")
        #                         $parts = $txt -split '\\s-\\s', 2
        #                         $performerPart = if ($parts.Count -gt 1) { $parts[1] } else { $txt }

        #                         # Remove role labels and parenthetical notes
        #                         $clean = $performerPart -replace '(?i)\b(Artist|Performer|MainArtist|Composer|Main Performer)\b', ''
        #                         $clean = $clean -replace '\(.*?\)', ''

        #                         # Split on commas and semicolons and trim; keep tokens that look like person names
        #                         $candidates = @()
        #                         foreach ($tok in ($clean -split '[,;]')) {
        #                             $name = $tok.Trim()
        #                             if ($name -and $name -match '\w') {
        #                                 $candidates += $name
        #                             }
        #                         }
        #                         if ($candidates.Count -gt 0) {
        #                             foreach ($n in $candidates) { $out.artists += [pscustomobject]@{ name = $n } }
        #                             if ($out.Artist -eq '' -and $candidates.Count -gt 0) { $out.Artist = ($candidates -join '; ') }
        #                         }
        #                     } catch {
        #                         Write-Verbose "Artist heuristics failed on infos text: $($_.Exception.Message)"
        #                     }
        #                 }
        #             }
        #         }
        #     }
        
        #     # mark processed
        #     $processed[$key] = $true
        
        #     $out = [PSCustomObject]@{
        #         id = ($key -replace '^id:','')
        #         name = $title
        #         Title = $title
        #         disc_number = $discNumber
        #         DiscNumber = $discNumber
        #         track_number = $script:trackNumberCounter
        #         TrackNumber = $script:trackNumberCounter
        #         duration_ms = $durationMs
        #         duration = if ($durationMs -gt 0) { [math]::Round($durationMs/1000) } else { 0 }
        #         composer = $composer
        #         # Provider-normalized artist fields (Qobuz track entries often lack explicit performers)
        #         artists = @()
        #         Artist = ''
        #         # keep raw node and diagnostic hint
        #         _RawProviderObject = $node
        #     }

        #     # Try to extract performing artist(s) from the node if available
        #     try {
        #         $perfNodes = $node.SelectNodes('.//*[contains(concat(" ", normalize-space(@class), " "), " track__performer ")]')
        #         if (-not $perfNodes -or $perfNodes.Count -eq 0) {
        #             $perfNodes = $node.SelectNodes('.//a[contains(@href, "/artist/") or contains(@class,"artist")]')
        #         }
        #         if ($perfNodes -and $perfNodes.Count -gt 0) {
        #             $names = @()
        #             foreach ($p in @($perfNodes)) {
        #                 $n = $p.InnerText.Trim()
        #                 if ($n) { $names += $n; $out.artists += [pscustomobject]@{ name = $n } }
        #             }
        #             if ($names.Count -gt 0) { $out.Artist = ($names -join '; ') }
        #         }
        #         else {
        #             # fallback: try to extract artist info from the infosNode text if present and we didn't already populate
        #             if ($out.Artist -eq '' -and $infosNode) {
        #                 try {
        #                     $infos = $infosNode.InnerText -replace '\s{2,}',' '
        #                     # look for patterns like "- Name, Artist" or ", Artist - Name"
        #                     if ($infos -match '-\s*([^,\n]+)\s*,\s*Artist') {
        #                         $cand = $matches[1].Trim()
        #                         if ($cand) { $out.artists += [pscustomobject]@{ name = $cand }; $out.Artist = $cand }
        #                     }
        #                     else {
        #                         # attempt simple heuristic: take tokens labelled 'Artist' in the block
        #                         $m = ([regex]::Matches($infos, '([^,\n]+)\s*,\s*(?:Artist|Performer|MainArtist)'))
        #                         if ($m.Count -gt 0) {
        #                             $names = @()
        #                             foreach ($mm in $m) { $n = $mm.Groups[1].Value.Trim(); if ($n) { $names += $n; $out.artists += [pscustomobject]@{ name = $n } } }
        #                             if ($names.Count -gt 0 -and $out.Artist -eq '') { $out.Artist = ($names -join '; ') }
        #                         }
        #                     }
        #                 } catch {
        #                     # ignore
        #                 }
        #             }
        #         }
                
        #         # Another fallback: parse data-track-v2 JSON payload for item_brand or item_artist that may contain artist
        #         if ($out.Artist -eq '') {
        #             try {
        #                 $rawV2 = $node.GetAttributeValue('data-track-v2','')
        #                 if ($rawV2 -and $rawV2 -match '[\{\}\"]') {
        #                     $json = $rawV2 -replace '&quot;','"'
        #                     $json = $json -replace "'", '"'
        #                     $parsedV2 = $null
        #                     try { $parsedV2 = $json | ConvertFrom-Json -ErrorAction Stop } catch { $parsedV2 = $null }
        #                     if ($parsedV2) {
        #                         $maybe = $null
        #                         if ($parsedV2.PSObject.Properties.Match('item_brand')) { $maybe = $parsedV2.item_brand }
        #                         if (-not $maybe -and $parsedV2.PSObject.Properties.Match('item_artist')) { $maybe = $parsedV2.item_artist }
        #                         if ($maybe) { $out.artists += [pscustomobject]@{ name = $maybe }; $out.Artist = $maybe }
        #                     }
        #                 }
        #             } catch {
        #                 # non-fatal
        #             }
        #         }
        #     } catch {
        #         # non-fatal: leave artists empty
        #         Write-Verbose "Artist extraction failed for node: $($_.Exception.Message)"
        #     }
        
        #     $script:trackNumberCounter++
        #     return $out
        # }

        #         # 1) Process explicit disc containers first (elements with data-disk)
        # $discContainers = $doc.SelectNodes('//*[@data-disk]')
        # if ($discContainers) {
        #     foreach ($c in @($discContainers)) {
        #         $diskAttr = $c.GetAttributeValue('data-disk','')
        #         $discNum = 1
        #         if ($diskAttr -and $diskAttr -match '^\d+$') { $discNum = [int]$diskAttr }
        #         else { if ($c.InnerText -match '(\d+)') { $discNum = [int]$matches[1] } }
        
        #         # 1.a) Try tracks inside this element first (descendants)
        #         $nodes = $c.SelectNodes('.//*[@data-track]')
        #         if (-not $nodes -or $nodes.Count -eq 0) {
        #             $nodes = $c.SelectNodes('.//div[contains(concat(" ", normalize-space(@class), " "), " track ")]')
        #         }
        
        #         # 1.b) If none, walk up ancestors to find a parent container that holds tracks
        #         if (-not $nodes -or $nodes.Count -eq 0) {
        #             $ancestor = $c.ParentNode
        #             $attempt = 0
        #             while ($ancestor -and $attempt -lt 6) {
        #                 $attempt++
        #                 $nodes = $ancestor.SelectNodes('.//*[@data-track]')
        #                 if ($nodes -and $nodes.Count -gt 0) { break }
        #                 $nodes = $ancestor.SelectNodes('.//div[contains(concat(" ", normalize-space(@class), " "), " track ")]')
        #                 if ($nodes -and $nodes.Count -gt 0) { break }
        #                 $ancestor = $ancestor.ParentNode
        #             }
        #         }
        
        #         # 1.c) If still none, check enclosing player__item and subsequent player__item siblings
        #         # Many pages place the disc label inside one player__item and the tracks in that and following player__item blocks.
        #         if (-not $nodes -or $nodes.Count -eq 0) {
        #             # find a containing player__item (or similar container)
        #             $container = $c
        #             while ($container -and -not ($container.GetAttributeValue('class','') -match '\bplayer__item\b')) {
        #                 $container = $container.ParentNode
        #             }
        #             if (-not $container) { $container = $c }

        #             $collected = @()
        #             # collect from this container and following siblings until next disc label
        #             $sibList = $container.SelectNodes('following-sibling::*')
        #             # include the container itself first
        #             $targets = @($container)
        #             if ($sibList) { foreach ($s in @($sibList)) { $targets += $s } }

        #             foreach ($t in @($targets)) {
        #                 if ($t.InnerText -match '(?i)\b(disque|disk|disc|cd)\b') { break }
        #                 $cand = $t.SelectNodes('.//*[@data-track]')
        #                 if (-not $cand -or $cand.Count -eq 0) {
        #                     $cand = $t.SelectNodes('.//div[contains(concat(" ", normalize-space(@class), " "), " track ")]')
        #                 }
        #                 if ($cand -and $cand.Count -gt 0) { foreach ($n in @($cand)) { $collected += $n } }
        #             }
        #             if ($collected.Count -gt 0) { $nodes = $collected }
        #         }
        
        #         # 1.d) Process found track nodes (if any)
        #         if ($nodes) {
        #             foreach ($n in @($nodes)) {
        #                 $t = New-TrackFromNode $n $discNum
        #                 if ($t) { $tracks += $t }
        #             }
        #         }
        #     }
        # }

        # # 2) Next: labels like "DISQUE 2" / "DISK 2" — assign disc to tracks near the label
        # $labelNodes = $doc.SelectNodes('//*[contains(translate(normalize-space(.),"abcdefghijklmnopqrstuvwxyz","ABCDEFGHIJKLMNOPQRSTUVWXYZ"), "DISQUE") or contains(translate(normalize-space(.),"abcdefghijklmnopqrstuvwxyz","ABCDEFGHIJKLMNOPQRSTUVWXYZ"), "DISK")]')
        # if ($labelNodes) {
        #     foreach ($lbl in @($labelNodes)) {
        #         if ($lbl.InnerText -match '(\d+)') {
        #             $discNum = [int]$matches[1]

        #             # Try multiple strategies in order of reliability:
        #             # A) tracks that are descendants of the label node itself
        #             $nodes = $lbl.SelectNodes('.//*[@data-track]')
        #             if (-not $nodes -or $nodes.Count -eq 0) {
        #                 $nodes = $lbl.SelectNodes('.//div[contains(concat(" ", normalize-space(@class), " "), " track ")]')
        #             }

        #             # B) tracks in following siblings of the label node (common pattern: label then track list)
        #             if (-not $nodes -or $nodes.Count -eq 0) {
        #                 $following = $lbl.SelectNodes('following-sibling::*')
        #                 if ($following) {
        #                     foreach ($sib in @($following)) {
        #                         # stop scanning when we hit another disc label
        #                         if ($sib.InnerText -match '(?i)\b(disque|disk|disc|cd)\b') { break }
        #                         $nodes = $sib.SelectNodes('.//*[@data-track]')
        #                         if (-not $nodes -or $nodes.Count -eq 0) {
        #                             $nodes = $sib.SelectNodes('.//div[contains(concat(" ", normalize-space(@class), " "), " track ")]')
        #                         }
        #                         if ($nodes -and $nodes.Count -gt 0) { break }
        #                     }
        #                 }
        #             }

        #             # C) fallback: tracks in the label's parent container (existing behavior)
        #             if (-not $nodes -or $nodes.Count -eq 0) {
        #                 $parent = $lbl.ParentNode
        #                 if ($parent) {
        #                     $nodes = $parent.SelectNodes('.//*[@data-track]')
        #                     if (-not $nodes -or $nodes.Count -eq 0) {
        #                         $nodes = $parent.SelectNodes('.//div[contains(concat(" ", normalize-space(@class), " "), " track ")]')
        #                     }
        #                 }
        #             }

        #             if ($nodes) {
        #                 foreach ($n in @($nodes)) {
        #                     $t = New-TrackFromNode $n $discNum
        #                     if ($t) { $tracks += $t }
        #                 }
        #             }
        #         }
        #     }
        # }

        # # 3) Finally: any remaining tracks not yet processed — use per-track data-disk or default 1
        # foreach ($node in @($allTrackNodes)) {
        #     # determine key
        #     $idCandidate = $node.GetAttributeValue('data-track','')
        #     if (-not $idCandidate) { $idCandidate = $node.GetAttributeValue('data-track-id','') }
        #     $checkKey = if ($idCandidate) { "id:$idCandidate" } else {
        #         $Script:anon++; "anon-$Script:anon"
        #     }
        #     if ($processed.ContainsKey($checkKey)) { continue }

        #     $discNum = 1
        #     $diskAttr = $node.GetAttributeValue('data-disk','')
        #     if ($diskAttr -and $diskAttr -match '^\d+$') {
        #         $discNum = [int]$diskAttr
        #     }
        #     else {
        #         # try parent/ancestor label (existing behavior)
        #         $parent = $node.ParentNode
        #         while ($parent -and $parent.NodeType -ne 'Document') {
        #             if ($parent.InnerText -match '(DISQUE|DISK)\s*(\d+)' ) { $discNum = [int]$matches[2]; break }
        #             $parent = $parent.ParentNode
        #         }

        #         # If still not found, try scanning preceding siblings of the node and its ancestors
        #         if ($discNum -eq 1) {
        #             $current = $node
        #             $found = $false
        #             $attempt = 0
        #             while (-not $found -and $current -and $attempt -lt 8) {
        #                 $attempt++
        #                 $prevSibs = $current.SelectNodes('preceding-sibling::*')
        #                 if ($prevSibs) {
        #                     # iterate from nearest previous sibling backwards
        #                     foreach ($ps in @($prevSibs)) {
        #                         # check if the sibling itself carries a data-disk attr
        #                         $pDisk = $ps.GetAttributeValue('data-disk','')
        #                         if ($pDisk -and $pDisk -match '^\d+$') { $discNum = [int]$pDisk; $found = $true; break }
        #                         # or contains a visible label like 'DISQUE 2'
        #                         if ($ps.InnerText -match '(?i)\b(DISQUE|DISK)\s*(\d+)') { $discNum = [int]$matches[2]; $found = $true; break }
        #                         # or contains descendants with data-disk
        #                         $inner = $ps.SelectNodes('.//*[@data-disk]')
        #                         if ($inner -and $inner.Count -gt 0) {
        #                             $pDisk = $inner[0].GetAttributeValue('data-disk','')
        #                             if ($pDisk -and $pDisk -match '^\d+$') { $discNum = [int]$pDisk; $found = $true; break }
        #                         }
        #                     }
        #                 }
        #                 if (-not $found) { $current = $current.ParentNode }
        #             }
        #         }
        #     }

        #     $t = New-TrackFromNode $node $discNum
        #     if ($t) { $tracks += $t }
        # }

        return $tracks
    }
}

function Get-QAlbumTrackCount {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Id
    )

    begin {
        if (-not (Get-Module -Name PowerHTML -ListAvailable)) {
            throw "PowerHTML module is required but not installed. Install it with: Install-Module PowerHTML"
        }
        Import-Module PowerHTML -ErrorAction Stop
    }

    process {
        # Use the URL as-is if it's already a full URL, otherwise construct it
        if ($Id -match '^https?://') { $url = $Id.TrimEnd('/') }
        else {
            $locale = Get-QobuzUrlLocale
            if ($Id -match '^/[a-z]{2}-[a-z]{2}/album/') { $url = "https://www.qobuz.com$($Id.TrimEnd('/'))" }
            else { $url = "https://www.qobuz.com/$locale/album/$Id"; Write-Verbose "Best-effort album URL built: $url" }
        }

        Write-Verbose ("Fetching Qobuz album page for track count: {0}" -f $url)
        try {
            $resp = Invoke-WebRequest -Uri $url -UseBasicParsing -ErrorAction Stop
            $html = $resp.Content
        }
        catch {
            Write-Warning ("Failed to download album page {0}: {1}" -f $url, $_.Exception.Message)
            return $null
        }

        try {
            $doc = ConvertFrom-Html -Content $html
        }
        catch {
            Write-Warning ("Failed to parse HTML: {0}" -f $_.Exception.Message)
            return $null
        }

        # Extract track count from data-nbtracks attribute on playerTracks div
        $playerTracksDiv = $doc.SelectSingleNode("//div[@id='playerTracks']")
        if ($playerTracksDiv) {
            $nbtracks = $playerTracksDiv.GetAttributeValue("data-nbtracks", $null)
            if ($nbtracks -and $nbtracks -match '^\d+$') {
                return [int]$nbtracks
            }
        }

        Write-Warning "Could not extract track count from data-nbtracks attribute"
        return $null
    }
}
# ...existing code...
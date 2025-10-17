function Get-TracksFromHtml {
    param (
        [string]$Path
    )

    if (-not $Path) {
        $Path = Join-Path -Path $PSScriptRoot -ChildPath '..\Private\QTracksForAlbum - Copy.txt'
        $Path = (Resolve-Path $Path).ProviderPath
    }

    $html = Get-Content -Path $Path -Raw | ConvertFrom-Html

    # label nodes (explicit data-disk) and textual labels (DISQUE/DISK)
    $labelNodes = $html.SelectNodes("//p[@data-disk]")
    $textLabelNodes = $html.SelectNodes("//p[contains(translate(normalize-space(.), 'abcdefghijklmnopqrstuvwxyz', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'),'DISQUE') or contains(translate(normalize-space(.), 'abcdefghijklmnopqrstuvwxyz', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'),'DISK')]")

    # De-duplicate label nodes by a stable key (line + trimmed text)
    $allLabelNodes = @{}
    foreach ($n in @($labelNodes, $textLabelNodes) | Where-Object { $_ }) {
        foreach ($ln in $n) {
            $lineNum = 0
            try { if ($ln.PSObject.Properties.Match('Line')) { $lineNum = [int]$ln.Line } } catch { }
            $key = "{0}-{1}" -f $lineNum, ($ln.InnerText.Trim() -replace '\s+',' ')
            $allLabelNodes[$key] = $ln
        }
    }
    $allLabelNodes = $allLabelNodes.Values

    $trackNodes = $html.SelectNodes("//*[@data-track]")
    if (-not $trackNodes -or $trackNodes.Count -eq 0) { $trackNodes = $html.SelectNodes("//div[contains(@class,'track')]") }

    $results = @()
    $currentDisc = 1
    $currentDiscTrackCounter = 0

    # Container-first pass: assign disc numbers to tracks contained inside player__item containers
    $processed = @{}
    $containers = $html.SelectNodes("//div[contains(concat(' ', normalize-space(@class), ' '), ' player__item ')]")
    if ($containers) {
        foreach ($c in @($containers)) {
            # find a player__work label inside the container
            $lbl = $c.SelectSingleNode('.//p[contains(concat(" ", normalize-space(@class), " "), " player__work ") and (@data-disk)]')
            if (-not $lbl) { $lbl = $c.SelectSingleNode('.//p[contains(concat(" ", normalize-space(@class), " "), " player__work ")]') }
            $discNum = $null
            if ($lbl) {
                $a = $lbl.GetAttributeValue('data-disk','')
                if ($a -and $a -match '^\d+$') { $discNum = [int]$a }
                else {
                    $lt = $lbl.InnerText.Trim()
                    if ($lt -match '(?i)\bDISQUE\b\s*(\d+)') { $discNum = [int]$Matches[1] }
                    elseif ($lt -match '(?i)\bDISK\b\s*(\d+)') { $discNum = [int]$Matches[1] }
                }
            }
            if (-not $discNum) { continue }

            $nodes = $c.SelectNodes('.//*[@data-track]')
            if (-not $nodes -or $nodes.Count -eq 0) { $nodes = $c.SelectNodes('.//div[contains(concat(" ", normalize-space(@class), " "), " track ")]') }
            if ($nodes) {
                # per-container counter
                $containerCounter = 0
                foreach ($n in @($nodes)) {
                    $id = $n.GetAttributeValue('data-track','')
                    if (-not $id) { $id = $n.GetAttributeValue('data-track-id','') }
                    $key = if ($id) { "id:$id" } else { $n.GetHashCode().ToString() }
                    if ($processed.ContainsKey($key)) { continue }
                    $containerCounter++
                    # extract basic fields
                    $trackNumNode = $n.SelectSingleNode('.//div[contains(@class,"track__item--number")]//span')
                    $explicitTn = $null
                    if ($trackNumNode) { $raw = $trackNumNode.InnerText -replace '[^0-9]',''; if ($raw -match '^\d+$') { $explicitTn = [int]$raw } }
                    if ($explicitTn) { $tn = $explicitTn } else { $tn = $containerCounter }
                    $nameNode = $n.SelectSingleNode('.//div[contains(@class,"track__item--name")]//span')
                    $title = if ($nameNode) { $nameNode.InnerText.Trim() } else { $n.InnerText.Trim() }
                    # duration
                    $dur = $null
                    $durAttr = $n.GetAttributeValue('data-duration','')
                    if ($durAttr -and $durAttr -match '^\d+$') { $num = [int]$durAttr; $dur = ($num -lt 10000) ? ($num * 1000) : $num }
                    else {
                        $durNode = $n.SelectSingleNode('.//*[contains(concat(" ", normalize-space(@class), " "), " track__item--duration ")]')
                        if ($durNode -and $durNode.InnerText.Trim() -match '^(\d{1,2}):(\d{2})(?::(\d{2}))?$') { $mm=[int]$matches[1]; $ss=[int]$matches[2]; $hh=0; if ($matches[3]) {$hh=[int]$matches[3]}; $dur = (($hh*3600)+($mm*60)+$ss)*1000 }
                    }
                    # simple artist extraction
                    $artistStr = ''
                    $artistsArr = @()
                    try {
                        $infos = $n.SelectSingleNode('.//div[contains(concat(" ", normalize-space(@class), " "), " track__infos ")]')
                        if ($infos) { $p = $infos.SelectSingleNode('.//p'); if ($p) { $txt = $p.InnerText; if ($txt -match '-') { $parts = $txt -split '-',2; foreach ($tok in ($parts[1] -split '[,;]')) { $nm = $tok.Trim() -replace '\(.*?\)',''; if ($nm) { $artistsArr += $nm } } } } }
                    } catch { }
                    if ($artistsArr.Count -gt 0) { $artistStr = ($artistsArr -join '; ') }

                    $results += [pscustomobject]@{ id=$id; name=$title; disc_number=$discNum; track_number=$tn; duration_ms=$dur; duration = if ($dur) { [math]::Round($dur/1000) } else { $null }; Artist = $artistStr; artists = ($artistsArr | ForEach-Object { [pscustomobject]@{ name = $_ } }); _RawProviderObject = $n }
                    $processed[$key] = $true
                }
            }
        }
    }

    function Get-NodeLine($n) {
        try {
            if ($n.PSObject.Properties.Match('Line')) { return [int]$n.Line }
            if ($n.ParentNode -and $n.ParentNode.PSObject.Properties.Match('Line')) { return [int]$n.ParentNode.Line }
        } catch { }
        return 0
    }

    # Build combined list of labels and tracks with line info, then sort by line to preserve document order
    $combined = @()
    if ($allLabelNodes) { foreach ($ln in @($allLabelNodes)) { $combined += [pscustomobject]@{ Type='label'; Node=$ln; Line = Get-NodeLine $ln } } }
    if ($trackNodes) { foreach ($tn in @($trackNodes)) { $combined += [pscustomobject]@{ Type='track'; Node=$tn; Line = Get-NodeLine $tn } } }
    $combined = $combined | Sort-Object Line

    foreach ($entry in $combined) {
        if ($entry.Type -eq 'label') {
            $node = $entry.Node
            $discAttr = $node.GetAttributeValue('data-disk','') -as [string]
            $num = 0
            if ($discAttr -and [int]::TryParse($discAttr, [ref]$num)) { $currentDisc = $num }
            else {
                $discText = $node.InnerText.Trim()
                if ($discText -match '(?i)\bDISQUE\b\s*(\d+)') { $currentDisc = [int]$Matches[1] }
                elseif ($discText -match '(?i)\bDISK\b\s*(\d+)') { $currentDisc = [int]$Matches[1] }
            }
            $currentDiscTrackCounter = 0
            continue
        }

        $track = $entry.Node
        $idVal = $track.GetAttributeValue('data-track','')
        if (-not $idVal) { $idVal = $track.GetAttributeValue('data-track-id','') }
        $checkKey = if ($idVal) { "id:$idVal" } else { $track.GetHashCode().ToString() }
        if ($processed.ContainsKey($checkKey)) { continue }

        # duration: prefer data-duration then visible duration text
        $durationMs = $null
        $durAttr = $track.GetAttributeValue('data-duration','')
        if ($durAttr -and $durAttr -match '^\d+$') { $num = [int]$durAttr; $durationMs = ($num -lt 10000) ? ($num * 1000) : $num }
        else {
            $durNode = $track.SelectSingleNode('.//*[contains(concat(" ", normalize-space(@class), " "), " track__item--duration ")]')
            if ($durNode -and $durNode.InnerText.Trim() -match '^(\d{1,2}):(\d{2})(?::(\d{2}))?$') {
                $mm = [int]$matches[1]; $ss = [int]$matches[2]; $hh = 0
                if ($matches[3]) { $hh = [int]$matches[3] }
                $durationMs = (($hh * 3600) + ($mm * 60) + $ss) * 1000
            }
        }

        # artist heuristics (infos block or data-track-v2)
        $artistStr = ''
        $artistsArr = @()
        try {
            $infosNode = $track.SelectSingleNode('.//div[contains(concat(" ", normalize-space(@class), " "), " track__infos ")]')
            if (-not $infosNode) {
                $parent = $track.ParentNode
                if ($parent) { $infosNode = $parent.SelectSingleNode('.//div[contains(concat(" ", normalize-space(@class), " "), " track__infos ")]') }
            }
            if ($infosNode) {
                $pNodes = $infosNode.SelectNodes('.//p[contains(concat(" ", normalize-space(@class), " "), " track__info ")]')
                if ($pNodes) {
                    foreach ($p in @($pNodes)) {
                        $txt = $p.InnerText.Trim()
                        if ($txt -match '-') {
                            $parts = $txt -split '-' ,2; $right = $parts[1].Trim()
                            foreach ($tok in ($right -split '[,;]')) { $n = $tok.Trim() -replace '\(.*?\)',''; if ($n) { $artistsArr += $n } }
                        }
                        else {
                            $m = ([regex]::Matches($txt, '([^,\n]+)\s*,\s*(?:Artist|Performer|MainArtist)'))
                            if ($m.Count -gt 0) { foreach ($mm in $m) { $n = $mm.Groups[1].Value.Trim(); if ($n) { $artistsArr += $n } } }
                        }
                    }
                }
            }
        } catch { }
        if ($artistsArr.Count -eq 0) {
            $rawv2 = $track.GetAttributeValue('data-track-v2','')
            if ($rawv2) {
                $j = $rawv2 -replace '&quot;','"'
                try { $pv = $j | ConvertFrom-Json -ErrorAction Stop } catch { $pv = $null }
                if ($pv) {
                    if ($pv.PSObject.Properties.Match('item_brand')) { $artistsArr += $pv.item_brand }
                    elseif ($pv.PSObject.Properties.Match('item_artist')) { $artistsArr += $pv.item_artist }
                }
            }
        }
        if ($artistsArr.Count -gt 0) { $artistStr = ($artistsArr -join '; ') }

        # Prefer explicit track number when available, otherwise use per-disc counter
        $trackNumNode = $track.SelectSingleNode('.//div[contains(@class,"track__item--number")]//span')
        $explicitTn = $null
        if ($trackNumNode) {
            $tnRaw = $trackNumNode.InnerText.Trim(); $tnClean = ($tnRaw -replace '[^0-9]','')
            if ($tnClean -match '^\d+$') { $explicitTn = [int]$tnClean }
        }

        $discToUse = if ($track.GetAttributeValue('data-disk','') -match '^\d+$') { [int]$track.GetAttributeValue('data-disk','') } else { $currentDisc }

        if ($explicitTn) { $tn = $explicitTn; $currentDiscTrackCounter = $tn }
        else { $currentDiscTrackCounter++; $tn = $currentDiscTrackCounter }

        $nameNode = $track.SelectSingleNode('.//div[contains(@class,"track__item--name")]//span')
        $nameVal = if ($nameNode) { $nameNode.InnerText.Trim() } else { $track.InnerText.Trim() }

        $results += [pscustomobject]@{ id = $idVal; name = $nameVal; disc_number = $discToUse; track_number = $tn; duration_ms = $durationMs; duration = if ($durationMs) { [math]::Round($durationMs/1000) } else { $null }; Artist = $artistStr; artists = ($artistsArr | ForEach-Object { [pscustomobject]@{ name = $_ } }); _RawProviderObject = $track }
        $processed[$checkKey] = $true
    }

    return $results
}
function Convert-OMPlaylist {
    <#
    .SYNOPSIS
        Match Spotify playlist tracks against a local Foobar2000 library and generate M3U8 playlists.

    .DESCRIPTION
        Takes a Spotify playlist CSV (from Export-OMPlaylists) and matches each track against
        the Foobar2000 SQLite database. Produces an M3U8 playlist of matched tracks and a
        detailed match report showing found/missing tracks at both album and track level.

        Uses a two-tier matching approach:
        1. Exact normalized match on artist + title
        2. Fuzzy match using word-index candidate filtering and Levenshtein similarity

        Requires the PSSQLite module (Install-Module PSSQLite -Scope CurrentUser).

    .PARAMETER CsvPath
        Path to one or more Spotify playlist CSV files (from Export-OMPlaylists).
        Accepts pipeline input. If omitted, opens an interactive file picker.

    .PARAMETER OutputPath
        Directory for output files (M3U8 + reports). Defaults to ~/.OM/playlists/.

    .PARAMETER FoobarDbPath
        Path to the Foobar2000 SQLite database.
        Defaults to the standard Foobar2000 v2 location.

    .PARAMETER MatchThreshold
        Minimum similarity score (0.0–1.0) to consider a match. Default: 0.7.
        Lower values find more matches but may include false positives.

    .PARAMETER ReportOnly
        Generate only the match report, skip M3U8 playlist creation.

    .EXAMPLE
        Convert-OMPlaylist
        # Opens an interactive file picker to select CSV files, then matches and generates playlists.

    .EXAMPLE
        Convert-OMPlaylist -CsvPath "~/.OM/playlists/Jazz Favorites.csv"
        # Converts a single playlist CSV to an M3U8 playlist + match report.

    .EXAMPLE
        Get-ChildItem ~/.OM/playlists/*.csv | Convert-OMPlaylist
        # Batch convert all exported playlists via pipeline.

    .EXAMPLE
        Convert-OMPlaylist -CsvPath "playlist.csv" -MatchThreshold 0.6
        # Use a lower threshold for more lenient matching (default is 0.7).

    .EXAMPLE
        Convert-OMPlaylist -CsvPath "playlist.csv" -ReportOnly
        # Generate only the match report without creating an M3U8 playlist.

    .EXAMPLE
        Export-OMPlaylists -Name "Rock*" -All; Get-ChildItem ~/.OM/playlists/Rock*.csv | Convert-OMPlaylist
        # Export and convert in one pipeline — export all Rock playlists, then match them.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName', 'Path')]
        [string[]]$CsvPath,

        [Parameter()]
        [string]$OutputPath,

        [Parameter()]
        [string]$FoobarDbPath = (Join-Path $env:APPDATA 'foobar2000-v2\configuration\foo_sqlite.materialize.db'),

        [Parameter()]
        [ValidateRange(0.0, 1.0)]
        [double]$MatchThreshold = 0.7,

        [Parameter()]
        [switch]$ReportOnly
    )

    begin {
        # Resolve output directory
        if (-not $OutputPath) {
            $OutputPath = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.OM' 'playlists'
        }
        if (-not (Test-Path $OutputPath)) {
            New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
        }

        # Validate Foobar DB
        if (-not (Test-Path $FoobarDbPath)) {
            Write-Error "Foobar2000 database not found: $FoobarDbPath"
            return
        }

        # Load PSSQLite
        if (-not (Get-Module PSSQLite -ListAvailable)) {
            Write-Error "PSSQLite module required. Install with: Install-Module PSSQLite -Scope CurrentUser"
            return
        }
        Import-Module PSSQLite -ErrorAction Stop

        # Load local library into memory (the DB uses custom collation that breaks WHERE clauses)
        Write-Host "Loading Foobar2000 library..." -ForegroundColor Cyan
        $script:localLibrary = Invoke-SqliteQuery -DataSource $FoobarDbPath -Query "SELECT * FROM Foo_test"
        Write-Host "  Loaded $($script:localLibrary.Count) tracks from local library." -ForegroundColor DarkCyan

        # Build lookup indexes for fast matching
        # Normalize function for consistent comparison
        $script:Normalize = {
            param([string]$s)
            if (-not $s) { return '' }
            $s.ToLower().Trim() -replace '[^a-z0-9\s]', '' -replace '\s+', ' '
        }

        Write-Host "  Building search indexes..." -ForegroundColor DarkCyan

        # Index by normalized "artist|title" for exact-match fast path
        $script:exactIndex = @{}
        # Index by artist words for fast fuzzy-match candidate filtering
        $script:artistWordIndex = @{}
        # Index by title words
        $script:titleWordIndex = @{}

        foreach ($track in $script:localLibrary) {
            $artist = & $script:Normalize $track.'%artist%'
            $albumArtist = & $script:Normalize $track.'%album artist%'
            $title = & $script:Normalize $track.'%title%'

            # Exact index — index by both %artist% and %album artist%
            $key = "$artist|$title"
            if (-not $script:exactIndex.ContainsKey($key)) {
                $script:exactIndex[$key] = [System.Collections.Generic.List[object]]::new()
            }
            $script:exactIndex[$key].Add($track)

            if ($albumArtist -and $albumArtist -ne $artist) {
                $key2 = "$albumArtist|$title"
                if (-not $script:exactIndex.ContainsKey($key2)) {
                    $script:exactIndex[$key2] = [System.Collections.Generic.List[object]]::new()
                }
                $script:exactIndex[$key2].Add($track)
            }

            # Artist word index — each significant word maps to tracks
            $allArtistText = "$artist $albumArtist"
            $seenWords = @{}
            foreach ($word in $allArtistText.Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries)) {
                if ($word.Length -ge 4 -and -not $seenWords.ContainsKey($word)) {
                    $seenWords[$word] = $true
                    if (-not $script:artistWordIndex.ContainsKey($word)) {
                        $script:artistWordIndex[$word] = [System.Collections.Generic.List[object]]::new()
                    }
                    $script:artistWordIndex[$word].Add($track)
                }
            }

            # Title word index — each significant word maps to tracks
            $seenWords = @{}
            foreach ($word in $title.Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries)) {
                if ($word.Length -ge 4 -and -not $seenWords.ContainsKey($word)) {
                    $seenWords[$word] = $true
                    if (-not $script:titleWordIndex.ContainsKey($word)) {
                        $script:titleWordIndex[$word] = [System.Collections.Generic.List[object]]::new()
                    }
                    $script:titleWordIndex[$word].Add($track)
                }
            }
        }

        $ec = $script:exactIndex.Count
        $aw = $script:artistWordIndex.Count
        $tw = $script:titleWordIndex.Count
        Write-Host "  Indexes ready ($ec exact, $aw artist words, $tw title words)." -ForegroundColor DarkCyan

        # Store threshold in script scope for Find-LocalMatch
        $script:MatchThreshold = $MatchThreshold

        # Collect all CSV paths from pipeline
        $script:allCsvPaths = [System.Collections.Generic.List[string]]::new()
    }

    process {
        if ($CsvPath) {
            foreach ($p in $CsvPath) {
                $resolved = Resolve-Path $p -ErrorAction SilentlyContinue
                if ($resolved) { $script:allCsvPaths.Add($resolved.Path) }
                else { Write-Warning "File not found: $p" }
            }
        }
    }

    end {
        # If no CSVs provided, open file picker
        if ($script:allCsvPaths.Count -eq 0) {
            $defaultDir = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.OM' 'playlists'
            if (Test-Path $defaultDir) {
                $csvFiles = Get-ChildItem $defaultDir -Filter '*.csv' |
                    Select-Object @{N='Name';E={$_.BaseName}}, @{N='Tracks';E={(Import-Csv $_.FullName).Count}}, @{N='FullName';E={$_.FullName}} |
                    Out-GridView -Title 'Select playlist CSV(s) to convert' -PassThru
                if (-not $csvFiles) {
                    Write-Host "No files selected." -ForegroundColor Yellow
                    return
                }
                foreach ($f in $csvFiles) { $script:allCsvPaths.Add($f.FullName) }
            }
            else {
                Write-Error "No CSV files provided and default playlist directory not found. Run Export-OMPlaylists first."
                return
            }
        }

        # Process each CSV
        foreach ($csv in $script:allCsvPaths) {
            Write-Host "`n━━━ Processing: $(Split-Path $csv -Leaf) ━━━" -ForegroundColor Cyan
            $spotifyTracks = Import-Csv -LiteralPath $csv
            if (-not $spotifyTracks) {
                Write-Warning "  Empty or invalid CSV: $csv"
                continue
            }

            $playlistName = $spotifyTracks[0].PlaylistName
            if (-not $playlistName) { $playlistName = [System.IO.Path]::GetFileNameWithoutExtension($csv) }

            $matched = @()
            $unmatched = @()
            $trackNum = 0
            $totalTracks = $spotifyTracks.Count

            foreach ($st in $spotifyTracks) {
                $trackNum++
                Write-Host "`r  Matching track $trackNum / $totalTracks..." -NoNewline -ForegroundColor DarkGray
                $result = Find-LocalMatch -SpotifyTrack $st
                if ($result.Match) {
                    $matched += [PSCustomObject]@{
                        SpotifyArtist = $st.Artists
                        SpotifyTitle  = $st.TrackName
                        SpotifyAlbum  = $st.AlbumName
                        LocalPath     = $result.Match.path
                        LocalArtist   = $result.Match.'%artist%'
                        LocalTitle    = $result.Match.'%title%'
                        LocalAlbum    = $result.Match.album
                        Confidence    = $result.Score
                        MatchType     = $result.Type
                    }
                }
                else {
                    $unmatched += [PSCustomObject]@{
                        Artists   = $st.Artists
                        TrackName = $st.TrackName
                        AlbumName = $st.AlbumName
                        ReleaseDate = $st.ReleaseDate
                    }
                }
            }

            $total = $spotifyTracks.Count
            $foundCount = $matched.Count
            $missCount = $unmatched.Count
            $pct = if ($total -gt 0) { [math]::Round(($foundCount / $total) * 100, 1) } else { 0 }

            Write-Host ""
            Write-Host "  Matched: $foundCount / $total ($pct%)" -ForegroundColor $(if ($pct -ge 80) { 'Green' } elseif ($pct -ge 50) { 'Yellow' } else { 'Red' })

            # Generate M3U8 playlist
            $safeName = ($playlistName -replace '[\\/:*?"<>|\[\]]', '_').Trim()
            if (-not $ReportOnly -and $matched.Count -gt 0) {
                $m3uPath = Join-Path $OutputPath "$safeName.m3u8"
                $m3uLines = @('#EXTM3U', "#PLAYLIST:$playlistName")
                foreach ($m in $matched) {
                    $m3uLines += "#EXTINF:-1,$($m.LocalArtist) - $($m.LocalTitle)"
                    $m3uLines += $m.LocalPath
                }
                $m3uLines | Set-Content -LiteralPath $m3uPath -Encoding UTF8
                Write-Host "  Playlist: $m3uPath" -ForegroundColor DarkGreen
            }

            # Generate match report
            $reportPath = Join-Path $OutputPath "$safeName - Match Report.txt"
            $report = [System.Collections.Generic.List[string]]::new()

            $report.Add("╔══════════════════════════════════════════════════════════════╗")
            $report.Add("║  MATCH REPORT: $playlistName")
            $report.Add("║  $foundCount / $total tracks matched ($pct%)")
            $report.Add("║  Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm')")
            $report.Add("╚══════════════════════════════════════════════════════════════╝")
            $report.Add("")

            # --- MISSING ALBUMS summary ---
            if ($unmatched.Count -gt 0) {
                $report.Add("═══ MISSING ALBUMS ═══")
                $report.Add("")

                $albumGroups = $unmatched | Group-Object AlbumName | Sort-Object Name
                foreach ($ag in $albumGroups) {
                    $firstTrack = $ag.Group[0]
                    $albumArtist = ($ag.Group | ForEach-Object { $_.Artists } | Select-Object -First 1)
                    $year = if ($firstTrack.ReleaseDate) { $firstTrack.ReleaseDate.Substring(0, [math]::Min(4, $firstTrack.ReleaseDate.Length)) } else { '????' }
                    $trackCount = $ag.Count
                    $report.Add("  ✗ $albumArtist - $($ag.Name) ($year) [$trackCount track(s) missing]")
                }
                $report.Add("")

                # --- MISSING TRACKS detail ---
                $report.Add("═══ MISSING TRACKS (by album) ═══")
                $report.Add("")

                foreach ($ag in $albumGroups) {
                    $firstTrack = $ag.Group[0]
                    $albumArtist = ($ag.Group | ForEach-Object { $_.Artists } | Select-Object -First 1)
                    $year = if ($firstTrack.ReleaseDate) { $firstTrack.ReleaseDate.Substring(0, [math]::Min(4, $firstTrack.ReleaseDate.Length)) } else { '????' }
                    $report.Add("  ── $albumArtist - $($ag.Name) ($year) ──")
                    foreach ($t in $ag.Group) {
                        $report.Add("     ✗ $($t.Artists) - $($t.TrackName)")
                    }
                    $report.Add("")
                }
            }

            # --- MATCHED TRACKS ---
            if ($matched.Count -gt 0) {
                $report.Add("═══ MATCHED TRACKS ═══")
                $report.Add("")
                $matchGroups = $matched | Group-Object SpotifyAlbum | Sort-Object Name
                foreach ($mg in $matchGroups) {
                    $report.Add("  ── $($mg.Group[0].SpotifyArtist) - $($mg.Name) ──")
                    foreach ($t in $mg.Group) {
                        $conf = [math]::Round($t.Confidence * 100)
                        $report.Add("     ✓ $($t.SpotifyTitle) → $($t.LocalTitle) [$($t.MatchType) ${conf}%]")
                    }
                    $report.Add("")
                }
            }

            $report | Set-Content -LiteralPath $reportPath -Encoding UTF8
            Write-Host "  Report:   $reportPath" -ForegroundColor DarkGreen

            # Console summary of missing albums
            if ($unmatched.Count -gt 0) {
                Write-Host "`n  Missing albums:" -ForegroundColor Yellow
                $albumGroups = $unmatched | Group-Object AlbumName | Sort-Object Name
                foreach ($ag in $albumGroups) {
                    $albumArtist = ($ag.Group | ForEach-Object { $_.Artists } | Select-Object -First 1)
                    Write-Host "    ✗ $albumArtist - $($ag.Name) ($($ag.Count) tracks)" -ForegroundColor DarkYellow
                }
            }
        }

        Write-Host "`nDone. Output in: $OutputPath" -ForegroundColor Cyan
    }
}

function Find-LocalMatch {
    <#
    .SYNOPSIS
        Find the best matching local track for a Spotify track.
    #>
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$SpotifyTrack
    )

    $spArtist = & $script:Normalize $SpotifyTrack.Artists
    $spTitle = & $script:Normalize $SpotifyTrack.TrackName
    $spAlbum = & $script:Normalize $SpotifyTrack.AlbumName

    # Fast path: exact normalized match
    $key = "$spArtist|$spTitle"
    if ($script:exactIndex.ContainsKey($key)) {
        $candidates = $script:exactIndex[$key]
        # If multiple, prefer album match
        if ($candidates.Count -gt 1 -and $spAlbum) {
            foreach ($c in $candidates) {
                $localAlbum = & $script:Normalize $c.album
                if ($localAlbum -eq $spAlbum) {
                    return @{ Match = $c; Score = 1.0; Type = 'Exact' }
                }
            }
        }
        return @{ Match = $candidates[0]; Score = 1.0; Type = 'Exact' }
    }

    # Fuzzy matching: use word indexes to find candidates by hit-count scoring
    $spArtistWords = [System.Collections.Generic.List[string]]::new()
    foreach ($w in $spArtist.Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries)) {
        if ($w.Length -ge 4 -and -not $spArtistWords.Contains($w)) { $spArtistWords.Add($w) }
    }
    $spTitleWords = [System.Collections.Generic.List[string]]::new()
    foreach ($w in $spTitle.Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries)) {
        if ($w.Length -ge 4 -and -not $spTitleWords.Contains($w)) { $spTitleWords.Add($w) }
    }

    # Score candidates: each matching word = 1 point. Skip overly common words (>5000 tracks).
    $candidateScores = @{}
    foreach ($word in $spArtistWords) {
        if ($script:artistWordIndex.ContainsKey($word)) {
            $entries = $script:artistWordIndex[$word]
            if ($entries.Count -gt 5000) { continue }
            foreach ($t in $entries) {
                $p = $t.path
                if (-not $candidateScores.ContainsKey($p)) {
                    $candidateScores[$p] = @{ Track = $t; ArtistHits = 0; TitleHits = 0 }
                }
                $candidateScores[$p].ArtistHits++
            }
        }
    }
    foreach ($word in $spTitleWords) {
        if ($script:titleWordIndex.ContainsKey($word)) {
            $entries = $script:titleWordIndex[$word]
            if ($entries.Count -gt 5000) { continue }
            foreach ($t in $entries) {
                $p = $t.path
                if (-not $candidateScores.ContainsKey($p)) {
                    $candidateScores[$p] = @{ Track = $t; ArtistHits = 0; TitleHits = 0 }
                }
                $candidateScores[$p].TitleHits++
            }
        }
    }

    if ($candidateScores.Count -eq 0) {
        return @{ Match = $null; Score = 0; Type = 'None' }
    }

    # Require at least 1 artist hit AND 1 title hit, or 2+ hits in either
    # Then take top 50 by total hits for Levenshtein scoring
    $filtered = [System.Collections.Generic.List[object]]::new()
    foreach ($entry in $candidateScores.Values) {
        if (($entry.ArtistHits -gt 0 -and $entry.TitleHits -gt 0) -or $entry.ArtistHits -ge 2 -or $entry.TitleHits -ge 2) {
            $filtered.Add($entry)
        }
    }

    if ($filtered.Count -eq 0) {
        return @{ Match = $null; Score = 0; Type = 'None' }
    }

    # Sort by total hits descending and take top 50
    $candidates = $filtered | Sort-Object { $_.ArtistHits + $_.TitleHits } -Descending | Select-Object -First 50

    if ($candidates.Count -eq 0) {
        return @{ Match = $null; Score = 0; Type = 'None' }
    }

    $bestMatch = $null
    $bestScore = 0

    # Fast token-overlap prescreening: skip expensive Levenshtein for most candidates
    $prescored = [System.Collections.Generic.List[object]]::new()
    foreach ($entry in $candidates) {
        $local = $entry.Track
        $localArtist = & $script:Normalize $local.'%artist%'
        $localAlbumArtist = & $script:Normalize $local.'%album artist%'
        $localTitle = & $script:Normalize $local.'%title%'

        # Token overlap score: count shared words / max words
        # Try both %artist% and %album artist%, use whichever scores better
        $localArtistWords = $localArtist.Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries)
        $localAlbumArtistWords = $localAlbumArtist.Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries)
        $localTitleWords = $localTitle.Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries)

        $artistShared = 0
        foreach ($w in $spArtistWords) {
            foreach ($lw in $localArtistWords) {
                if ($w -eq $lw) { $artistShared++; break }
            }
        }
        $albumArtistShared = 0
        foreach ($w in $spArtistWords) {
            foreach ($lw in $localAlbumArtistWords) {
                if ($w -eq $lw) { $albumArtistShared++; break }
            }
        }
        $titleShared = 0
        foreach ($w in $spTitleWords) {
            foreach ($lw in $localTitleWords) {
                if ($w -eq $lw) { $titleShared++; break }
            }
        }

        # Use whichever artist field gives a better overlap
        $bestArtistShared = [math]::Max($artistShared, $albumArtistShared)
        $bestArtistWords = if ($albumArtistShared -gt $artistShared) { $localAlbumArtistWords } else { $localArtistWords }
        $bestArtistNorm = if ($albumArtistShared -gt $artistShared) { $localAlbumArtist } else { $localArtist }

        $maxArtist = [math]::Max($spArtistWords.Count, $bestArtistWords.Count)
        $maxTitle = [math]::Max($spTitleWords.Count, $localTitleWords.Count)
        $artistOverlap = if ($maxArtist -gt 0) { $bestArtistShared / $maxArtist } else { 0 }
        $titleOverlap = if ($maxTitle -gt 0) { $titleShared / $maxTitle } else { 0 }
        $quickScore = ($artistOverlap * 0.4) + ($titleOverlap * 0.6)

        if ($quickScore -gt 0.2) {
            $prescored.Add(@{ Track = $local; QuickScore = $quickScore; LocalArtist = $bestArtistNorm; LocalTitle = $localTitle })
        }
    }

    if ($prescored.Count -eq 0) {
        return @{ Match = $null; Score = 0; Type = 'None' }
    }

    # Take top 5 by quick score for full Levenshtein comparison
    $topCandidates = $prescored | Sort-Object { $_.QuickScore } -Descending | Select-Object -First 5

    foreach ($entry in $topCandidates) {
        $local = $entry.Track
        $localArtist = $entry.LocalArtist
        $localTitle = $entry.LocalTitle

        # Also try %album artist% for Levenshtein — use whichever scores better
        $artistScore = Get-StringSimilarity -String1 $spArtist -String2 $localArtist
        $localAlbumArtist2 = & $script:Normalize $local.'%album artist%'
        if ($localAlbumArtist2 -and $localAlbumArtist2 -ne $localArtist) {
            $albumArtistScore = Get-StringSimilarity -String1 $spArtist -String2 $localAlbumArtist2
            if ($albumArtistScore -gt $artistScore) { $artistScore = $albumArtistScore }
        }
        $titleScore = Get-StringSimilarity -String1 $spTitle -String2 $localTitle

        # Weight title more heavily — artist names vary a lot
        $combinedScore = ($artistScore * 0.4) + ($titleScore * 0.6)

        # Album match bonus
        if ($spAlbum) {
            $localAlbum = & $script:Normalize $local.album
            $albumScore = Get-StringSimilarity -String1 $spAlbum -String2 $localAlbum
            if ($albumScore -gt 0.8) {
                $combinedScore = [math]::Min(1.0, $combinedScore + 0.05)
            }
        }

        if ($combinedScore -gt $bestScore) {
            $bestScore = $combinedScore
            $bestMatch = $local
        }
    }

    if ($bestScore -ge $script:MatchThreshold) {
        $type = if ($bestScore -ge 0.95) { 'Near-Exact' } elseif ($bestScore -ge 0.85) { 'Strong' } else { 'Fuzzy' }
        return @{ Match = $bestMatch; Score = $bestScore; Type = $type }
    }

    return @{ Match = $null; Score = $bestScore; Type = 'None' }
}

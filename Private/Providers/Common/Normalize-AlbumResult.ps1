function Normalize-AlbumResult {
    <#
    .SYNOPSIS
        Normalize various provider album result shapes to a canonical album object.
    .PARAMETER Raw
        Raw album object as returned from a provider-specific parser.
    .OUTPUTS PSCustomObject
        Canonical album object with fields: id, url, name, artists (array of objects {name}), genres (array), cover_url, track_count, disc_count, release_date
    #>
    param(
        [Parameter(Mandatory = $true)]
        $Raw
    )

    # Helper to ensure array of simple artist objects
    $artists = @()
    # Prefer explicit helper Get-IfExists to avoid property-not-found errors
    $rawArtists = Get-IfExists -target $Raw -path 'artists'
    $rawArtist = Get-IfExists -target $Raw -path 'artist'

    if ($rawArtists) {
        if ($rawArtists -is [array]) {
            foreach ($a in $rawArtists) {
                if ($a -is [string]) { $artists += [PSCustomObject]@{ name = $a } }
                elseif ($a -is [PSCustomObject] -or $a -is [hashtable]) {
                    $n = Get-IfExists -target $a -path 'name'
                    if (-not $n) { $n = Get-IfExists -target $a -path 'artist' }
                    $artists += [PSCustomObject]@{ name = if ($n) { $n } else { $a.ToString() } }
                } else {
                    $artists += [PSCustomObject]@{ name = $a.ToString() }
                }
            }
        } else {
            # single artist string/object
            if ($rawArtists -is [string]) { $artists = @([PSCustomObject]@{ name = $rawArtists }) }
            else {
                $n = Get-IfExists -target $rawArtists -path 'name'
                if (-not $n) { $n = Get-IfExists -target $rawArtists -path 'artist' }
                $artists = @([PSCustomObject]@{ name = if ($n) { $n } else { $rawArtists.ToString() } })
            }
        }
    } elseif ($rawArtist) {
        $artists = @([PSCustomObject]@{ name = $rawArtist })
    }

    # Genres - normalize to array
    $genres = @()
    $rawGenres = Get-IfExists -target $Raw -path 'genres'
    if ($rawGenres) {
        if ($rawGenres -is [array]) { $genres = $rawGenres } else { $genres = @($rawGenres) }
    }

    # Helper: decode HTML entities and clean whitespace
    $decodeString = {
        param($s)
        if ($null -eq $s) { return $null }
        try {
            # Use .NET HtmlDecode which handles &amp; etc.
            $out = [System.Net.WebUtility]::HtmlDecode([string]$s)
        }
        catch {
            $out = [string]$s
        }
        # Collapse whitespace and trim
        $out = $out -replace '\s+', ' '
        return $out.Trim()
    }

    # Determine id/url
    $id = Get-IfExists -target $Raw -path 'id'
    $url = Get-IfExists -target $Raw -path 'url'
    if (-not $url -and $id -and $id -match '^https?://') { $url = $id }

    # Track/disc counts
    $track_count = $null
    $rawTrackCount = Get-IfExists -target $Raw -path 'track_count'
    if ($rawTrackCount) { try { $track_count = [int]$rawTrackCount } catch { $track_count = $rawTrackCount } }
    $disc_count = $null
    $rawDiscCount = Get-IfExists -target $Raw -path 'disc_count'
    if ($rawDiscCount) { try { $disc_count = [int]$rawDiscCount } catch { $disc_count = $rawDiscCount } }

    # Use explicit fallback logic rather than -or (logical operator returns boolean)
    $nameVal = Get-IfExists -target $Raw -path 'name'
    if (-not $nameVal) { $nameVal = Get-IfExists -target $Raw -path 'title' }

    $coverVal = Get-IfExists -target $Raw -path 'cover_url'
    if (-not $coverVal) { $coverVal = Get-IfExists -target $Raw -path 'cover' }

    $releaseVal = Get-IfExists -target $Raw -path 'release_date'
    if (-not $releaseVal) { $releaseVal = Get-IfExists -target $Raw -path 'date' }

    # Clean up textual fields (decode HTML entities like &amp;)
    $nameVal = & $decodeString $nameVal
    $releaseVal = & $decodeString $releaseVal

    foreach ($a in $artists) {
        if ($a -and $a.name) { $a.name = & $decodeString $a.name }
    }

    # Normalize genres: split comma-separated strings, decode and dedupe
    $cleanGenres = @()
    foreach ($g in $genres) {
        if ($null -eq $g) { continue }
        if ($g -is [string]) {
            $parts = $g -split ','
            foreach ($p in $parts) {
                $val = & $decodeString $p
                if ($val -and -not ($cleanGenres -contains $val)) { $cleanGenres += $val }
            }
        }
        else {
            $val = & $decodeString $g.ToString()
            if ($val -and -not ($cleanGenres -contains $val)) { $cleanGenres += $val }
        }
    }

    # Composer(s) and comment cleanup: strip any trailing "--- Production Credits ---" section
    $rawComposer = Get-IfExists -target $Raw -path 'composer'
    $rawComposers = Get-IfExists -target $Raw -path 'composers'
    $composers = @()
    if ($rawComposers) {
        if ($rawComposers -is [array]) {
            foreach ($c in $rawComposers) {
                if ($c) {
                    $text = & $decodeString $c
                    $text = ($text -split '(?m)---\s*Production Credits\s*---',2)[0].Trim()
                    if ($text -and -not ($composers -contains $text)) { $composers += $text }
                }
            }
        }
        else {
            $text = & $decodeString $rawComposers
            $text = ($text -split '(?m)---\s*Production Credits\s*---',2)[0].Trim()
            if ($text) { $composers += $text }
        }
    }
    elseif ($rawComposer) {
        $text = & $decodeString $rawComposer
        $text = ($text -split '(?m)---\s*Production Credits\s*---',2)[0].Trim()
        if ($text) { $composers += $text }
    }

    # Comment cleanup
    $rawComment = Get-IfExists -target $Raw -path 'comment'
    if ($rawComment) {
        $comment = & $decodeString $rawComment
        $comment = ($comment -split '(?m)---\s*Production Credits\s*---',2)[0].Trim()
    }
    else { $comment = $null }

    $res = [PSCustomObject]@{
        id = $id
        url = $url
        name = $nameVal
        artists = $artists
        genres = $cleanGenres
        cover_url = $coverVal
        track_count = $track_count
        disc_count = $disc_count
        release_date = $releaseVal
        composers = $composers
        comment = $comment
    }

    return $res
}

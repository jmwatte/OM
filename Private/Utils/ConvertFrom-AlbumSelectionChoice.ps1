function ConvertFrom-AlbumSelectionChoice {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Choice,
        [Parameter(Mandatory=$false)][int]$MaxIndex
    )

    $res = [PSCustomObject]@{
        Command = 'None'
        Number = $null
        RangeText = $null
        Provider = $null
        Error = $null
    }

    if (-not $Choice) { $Choice = '' }
    $lc = $Choice.ToLower()

    switch -Wildcard ($lc) {
        'p' { $res.Command = 'Provider'; return $res }
        'ps' { $res.Command = 'SwitchProvider'; $res.Provider = 'Spotify'; return $res }
        'pq' { $res.Command = 'SwitchProvider'; $res.Provider = 'Qobuz'; return $res }
        'pd' { $res.Command = 'SwitchProvider'; $res.Provider = 'Discogs'; return $res }
        'pm' { $res.Command = 'SwitchProvider'; $res.Provider = 'MusicBrainz'; return $res }
        'f'  { $res.Command = 'FindMode'; return $res }
        'ni' { $res.Command = 'NewItem'; return $res }
    }

    if ($lc -match '^cvo(.*)$') {
        $range = $matches[1]
        if (-not $range) { $range = '1' }
        $res.Command = 'CoverOriginal'
        $res.RangeText = $range
        return $res
    }
    if ($lc -match '^cv(.*)$') {
        $range = $matches[1]
        if (-not $range) { $range = '1' }
        $res.Command = 'Cover'
        $res.RangeText = $range
        return $res
    }
    if ($lc -match '^cs(.*)$') {
        $range = $matches[1]
        if (-not $range) { $range = '1' }
        $res.Command = 'SaveToFolder'
        $res.RangeText = $range
        return $res
    }
    if ($lc -match '^ct(.*)$') {
        $range = $matches[1]
        if (-not $range) { $range = '1' }
        $res.Command = 'EmbedInTags'
        $res.RangeText = $range
        return $res
    }

    if ($lc -match '^[0-9]+$') {
        $n = [int]$lc
        if ($MaxIndex -and ($n -lt 1 -or $n -gt $MaxIndex)) {
            $res.Command = 'Invalid'
            $res.Error = "Number out of range: $n"
            return $res
        }
        $res.Command = 'Number'
        $res.Number = $n
        return $res
    }

    # default: return as Text for potential search/new queries
    $res.Command = 'Text'
    $res.RangeText = $Choice
    return $res
}
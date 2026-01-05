function Show-AlbumCandidates {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][array]$AlbumCandidates,
        [Parameter(Mandatory=$false)][string]$Provider
    )

    $lines = New-Object System.Collections.ArrayList
    for ($i = 0; $i -lt $AlbumCandidates.Count; $i++) {
        $album = $AlbumCandidates[$i]
        $artistDisplay = if ($album.artists -and $album.artists[0].name) { $album.artists[0].name } else { 'Unknown Artist' }

        $year = Get-IfExists $album 'release_date'
        $trackCount = Get-IfExists $album 'total_tracks'
        if (-not $trackCount) { $trackCount = Get-IfExists $album 'track_count' }
        if (-not $trackCount) { $trackCount = Get-IfExists $album 'tracks_count' }
        $trackInfo = if ($trackCount) { " ($trackCount tracks)" } else { "" }

        $line = "[$($i+1)] $($album.name) - $artistDisplay (id: $($album.id)) (year: $year)$trackInfo"
        Write-Host $line
        $lines.Add($line) | Out-Null
    }

    return $lines.ToArray()
}
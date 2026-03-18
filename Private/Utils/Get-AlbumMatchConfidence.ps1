function Get-AlbumMatchConfidence {
    param(
        $Candidate,
        [string]$LocalArtist,
        [string]$LocalAlbum,
        [int]$LocalTrackCount
    )
    
    $score = 0.0
    $weights = @{
        Artist = 0.30
        Album = 0.40
        TrackCount = 0.30
    }
    
    # Artist similarity
    $remoteArtist = ''
    $value = Get-IfExists $Candidate 'artists'
    if ($value) {
        $arr = @($value)  # Force array — pipeline unwraps single-element arrays from Get-IfExists
        if ($arr.Count -gt 0) {
            $remoteArtist = if ($arr[0].name) { $arr[0].name } else { $arr[0].ToString() }
        }
    }
    if (-not $remoteArtist) {
        $value = Get-IfExists $Candidate 'artist'
        if ($value) { $remoteArtist = $value }
    }
    
    if ($remoteArtist) {
        $artistSim = Get-StringSimilarity -String1 $LocalArtist -String2 $remoteArtist
        if ($artistSim -is [array]) { $artistSim = [double]$artistSim[0] }
        $score += ([double]$artistSim * $weights.Artist)
    }
    
    # Album similarity
    $remoteAlbum = Get-IfExists $Candidate 'name'
    if ($remoteAlbum) {
        $albumSim = Get-StringSimilarity -String1 $LocalAlbum -String2 $remoteAlbum
        if ($albumSim -is [array]) { $albumSim = [double]$albumSim[0] }
        $score += ([double]$albumSim * $weights.Album)
    }
    
    # Track count match
    $remoteTrackCount = Get-IfExists $Candidate 'total_tracks'
    if (-not $remoteTrackCount) { $remoteTrackCount = Get-IfExists $Candidate 'track_count' }
    if (-not $remoteTrackCount) { $remoteTrackCount = Get-IfExists $Candidate 'tracks_count' }
    
    # Ensure track count is a scalar integer
    if ($remoteTrackCount -is [array]) { $remoteTrackCount = $remoteTrackCount[0] }
    if ($remoteTrackCount) { 
        try { $remoteTrackCount = [int]$remoteTrackCount } 
        catch { $remoteTrackCount = $null }
    }
    
    if ($remoteTrackCount -and $LocalTrackCount -gt 0) {
        $trackDiff = [Math]::Abs($remoteTrackCount - $LocalTrackCount)
        $trackScore = if ($trackDiff -eq 0) { 1.0 }
                     elseif ($trackDiff -le 2) { 0.8 }
                     elseif ($trackDiff -le 5) { 0.5 }
                     else { 0.0 }
        $score += $trackScore * $weights.TrackCount
    }
    
    return $score
}
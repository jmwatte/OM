function Get-BestAutoMatch {
    param(
        $Candidates,
        [string]$LocalArtist,
        [string]$LocalAlbum,
        [int]$LocalTrackCount,
        [double]$Threshold
    )
    
    $bestMatch = $null
    $bestScore = 0.0
    $bestIndex = -1
    
    for ($i = 0; $i -lt $Candidates.Count; $i++) {
        $score = Get-AlbumMatchConfidence -Candidate $Candidates[$i] `
            -LocalArtist $LocalArtist -LocalAlbum $LocalAlbum `
            -LocalTrackCount $LocalTrackCount
        
        if ($score -gt $bestScore) {
            $bestScore = $score
            $bestMatch = $Candidates[$i]
            $bestIndex = $i
        }
    }
    
    if ($bestScore -ge $Threshold) {
        return @{
            Album = $bestMatch
            Index = $bestIndex + 1
            Confidence = [Math]::Round($bestScore * 100, 0)
        }
    }
    
    return $null
}
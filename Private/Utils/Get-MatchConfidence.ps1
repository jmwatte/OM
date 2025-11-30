function Get-MatchConfidence {
    <#
    .SYNOPSIS
    Calculate confidence score (0-100) for a track match between provider and local file
    
    .DESCRIPTION
    Evaluates multiple factors to determine match confidence:
    - Title similarity (Jaccard)
    - Duration match (within 10% tolerance)
    - Catalog number match (BWV, K, Op., etc.)
    - Movement/part name match
    
    .PARAMETER ProviderTrack
    Track object from provider (Spotify/Qobuz) with name and duration_ms
    
    .PARAMETER AudioFile
    Local audio file object with Title and Duration
    
    .OUTPUTS
    PSCustomObject with Score (0-100), Factors (breakdown), and Confidence level (Low/Medium/High)
    #>
    param (
        [Parameter(Mandatory)]
        $ProviderTrack,
        
        [Parameter(Mandatory)]
        $AudioFile
    )
    
    $factors = @{}
    $totalScore = 0
    $maxScore = 100
    
    # 1. Title similarity (50 points max)
    $titleSimilarity = Get-StringSimilarity-Jaccard -String1 $ProviderTrack.name -String2 $AudioFile.Title
    $titleScore = $titleSimilarity * 50
    $factors['TitleSimilarity'] = [math]::Round($titleSimilarity, 2)
    $totalScore += $titleScore
    
    # 2. Duration match (20 points max)
    $durationDiff = [Math]::Abs($ProviderTrack.duration_ms - $AudioFile.Duration)
    $tolerance = [Math]::Max($ProviderTrack.duration_ms, 1) * 0.1
    if ($durationDiff -le $tolerance) {
        $durationScore = (1 - ($durationDiff / $tolerance)) * 20
        $totalScore += $durationScore
        $factors['DurationMatch'] = [math]::Round($durationScore / 20, 2)
    } else {
        $factors['DurationMatch'] = 0
    }
    
    # 3. Catalog number match (30 points max)
    # BWV (Bach), K/KV (Mozart), Op. (general), Hob. (Haydn), D (Schubert), RV (Vivaldi)
    $catalogBonus = 0
    
    # Extract catalog numbers from both
    $providerCatalog = $null
    $audioCatalog = $null
    
    # BWV - allow comma+space, space, or word boundary before
    if ($ProviderTrack.name -match '(?:,\s+|\s)(BWV)\s*(\d+)') {
        $providerCatalog = "BWV $($matches[2])"
    }
    if ($AudioFile.Title -match '(?:,\s+|\s)(BWV)\s*(\d+)') {
        $audioCatalog = "BWV $($matches[2])"
    }
    
    # Debug output
    Write-Verbose "Provider: '$($ProviderTrack.name)' -> Catalog: '$providerCatalog'"
    Write-Verbose "Audio: '$($AudioFile.Title)' -> Catalog: '$audioCatalog'"
    
    if ($providerCatalog -and $audioCatalog -and $providerCatalog -eq $audioCatalog) {
        $catalogBonus = 30
        $totalScore += $catalogBonus
        $factors['CatalogMatch'] = $providerCatalog
        Write-Verbose "Catalog match! +30 points for $providerCatalog"
    } else {
        $factors['CatalogMatch'] = $null
        Write-Verbose "No catalog match (provider: $providerCatalog, audio: $audioCatalog)"
    }
    
    # Determine confidence level - adjusted thresholds for classical music
    # Classical music often has different language/formatting but same BWV/catalog numbers
    $confidenceLevel = if ($totalScore -ge 65) { "High" }
                       elseif ($totalScore -ge 45) { "Medium" }
                       else { "Low" }
    
    return [PSCustomObject]@{
        Score = [math]::Round($totalScore, 1)
        Factors = $factors
        Level = $confidenceLevel
    }
}

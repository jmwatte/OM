function Get-BestSortMethod {
    <#
    .SYNOPSIS
    Tests all sort methods and returns the one with highest average confidence
    
    .DESCRIPTION
    Runs Set-Tracks with each available sort method, calculates average confidence
    for paired tracks, and returns the method with the best overall confidence.
    This helps automatically select the best matching strategy for an album.
    
    .PARAMETER AudioFiles
    Array of audio file objects with tags
    
    .PARAMETER ProviderTracks
    Array of provider track objects (Spotify/Qobuz/etc)
    
    .PARAMETER Reverse
    If set, iterate over audio files instead of provider tracks
    
    .OUTPUTS
    String - name of the best sort method (e.g., "byTitle", "byTrackNumber")
    #>
    param (
        [Parameter(Mandatory)]
        [array]$AudioFiles,
        
        [Parameter(Mandatory)]
        [array]$ProviderTracks,
        
        [switch]$Reverse
    )
    
    # Methods to test (exclude manual and hybrid for auto-selection)
    $methodsToTest = @('byTitle', 'byTrackNumber', 'byDuration', 'byName', 'byFilesystem', 'byOrder')
    
    $results = @{}
    
    Write-Verbose "🔍 Auto-selecting best sort method..."
    Write-Verbose "   Testing $($methodsToTest.Count) methods against $($AudioFiles.Count) audio files and $($ProviderTracks.Count) provider tracks"
    
    foreach ($method in $methodsToTest) {
        Write-Verbose "   → Testing $method..."
        
        # Run Set-Tracks with this method
        $pairedTracks = Set-Tracks -SortMethod $method -AudioFiles $AudioFiles -SpotifyTracks $ProviderTracks -Reverse:$Reverse
        
        # Calculate average confidence for successfully paired tracks (ignore unpaired)
        $pairedWithBoth = @($pairedTracks | Where-Object { $_.SpotifyTrack -and $_.AudioFile })
        
        if ($pairedWithBoth.Count -gt 0) {
            $avgConfidence = ($pairedWithBoth | Measure-Object -Property Confidence -Average).Average
            $highCount = @($pairedWithBoth | Where-Object { $_.ConfidenceLevel -eq 'High' }).Count
            $mediumCount = @($pairedWithBoth | Where-Object { $_.ConfidenceLevel -eq 'Medium' }).Count
            $lowCount = @($pairedWithBoth | Where-Object { $_.ConfidenceLevel -eq 'Low' }).Count
            $pairedCount = $pairedWithBoth.Count
        } else {
            $avgConfidence = 0
            $highCount = 0
            $mediumCount = 0
            $lowCount = 0
            $pairedCount = 0
        }
        
        $results[$method] = [PSCustomObject]@{
            Method = $method
            AvgConfidence = $avgConfidence
            HighCount = $highCount
            MediumCount = $mediumCount
            LowCount = $lowCount
            PairedCount = $pairedCount
        }
        
        Write-Verbose "      Paired: $pairedCount, Avg: $([math]::Round($avgConfidence, 1))%, H:$highCount M:$mediumCount L:$lowCount"
    }
    
    # Pick method with highest average confidence
    # Use Sort-Object with multiple properties to handle tiebreakers properly
    $bestMethod = $results.Values | Sort-Object @(
        @{Expression = 'AvgConfidence'; Descending = $true},
        @{Expression = 'HighCount'; Descending = $true},
        @{Expression = 'LowCount'; Descending = $false}
    ) | Select-Object -First 1
    
    Write-Verbose "   ✓ Selected: $($bestMethod.Method) (Avg: $([math]::Round($bestMethod.AvgConfidence, 1))%, High: $($bestMethod.HighCount), Medium: $($bestMethod.MediumCount), Low: $($bestMethod.LowCount))"
    
    return $bestMethod.Method
}

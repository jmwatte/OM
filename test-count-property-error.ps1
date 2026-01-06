# Test to reproduce "Count property cannot be found" error
Set-StrictMode -Version Latest

# Simulate the problematic scope scenario
$script:pairedTracks = @(
    [PSCustomObject]@{ AudioFile = @{ FilePath = "track1.mp3" }; SpotifyTrack = @{ name = "Track 1" }; Confidence = 95 }
    [PSCustomObject]@{ AudioFile = @{ FilePath = "track2.mp3" }; SpotifyTrack = @{ name = "Track 2" }; Confidence = 85 }
    [PSCustomObject]@{ AudioFile = @{ FilePath = "track3.mp3" }; SpotifyTrack = @{ name = "Track 3" }; Confidence = 75 }
)

# Ensure Show-Message helper available when running standalone
if (-not (Get-Command -Name Show-Message -ErrorAction SilentlyContinue)) {
    $p = Join-Path $PSScriptRoot 'Private\Utils\Show-Message.ps1'
    if (Test-Path $p) { . $p }
}

Show-Message -Message "Initial script:pairedTracks.Count: $($script:pairedTracks.Count)" -ForegroundColor Green -Context $null

# Simulate the doTracks loop with confidence sorting (lines 1719-1721)
try {
    Show-Message -Message "`nTesting mixed scope reference (line 1719 pattern)..." -ForegroundColor Cyan -Context $null
    
    # This is what line 1719 does - mixed scopes
    if ($script:pairedTracks -and $script:pairedTracks.Count -gt 0 -and $pairedTracks[0].PSObject.Properties['Confidence']) {
        Show-Message -Message "ERROR: This should have failed but didn't!" -ForegroundColor Red -Context $null
    }
}
catch {
    Show-Message -Message "✓ Caught expected error: $($_.Exception.Message)" -ForegroundColor Yellow -Context $null
} 

# Test the fix
try {
    Show-Message -Message "`nTesting fixed version (all script: prefix)..." -ForegroundColor Cyan -Context $null
    
    if ($script:pairedTracks -and $script:pairedTracks.Count -gt 0 -and $script:pairedTracks[0].PSObject.Properties['Confidence']) {
        $script:pairedTracks = $script:pairedTracks | Sort-Object Confidence -Descending
        Show-Message -Message "✓ Sorted $($script:pairedTracks.Count) tracks by confidence" -ForegroundColor Green -Context $null
    }
}
catch {
    Show-Message -Message "ERROR: Fixed version failed: $($_.Exception.Message)" -ForegroundColor Red -Context $null
} 

# Test Show-Tracks parameter (line 1773)
try {
    Write-Host "`nTesting Show-Tracks parameter (line 1773 pattern)..." -ForegroundColor Cyan
    
    $paramshow = @{
        PairedTracks = $pairedTracks  # ← This references undefined local variable
    }
    
    Write-Host "ERROR: This should have failed but didn't!" -ForegroundColor Red
}
catch {
    Write-Host "✓ Caught expected error: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "`n✓ Test complete" -ForegroundColor Green


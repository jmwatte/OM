# Test intelligent variation matching with Goldberg Variations
# This simulates the byTrackNumber sort with smart variation matching

$ErrorActionPreference = 'Stop'
Import-Module "C:\Users\jmw\Documents\PowerShell\Modules\OM\OM.psd1" -Force

# Dot-source Set-Tracks and its dependencies
. "C:\Users\jmw\Documents\PowerShell\Modules\OM\Private\Utils\Get-StringSimilarity-Jaccard.ps1"
. "C:\Users\jmw\Documents\PowerShell\Modules\OM\Private\Utils\Get-MatchConfidence.ps1"
. "C:\Users\jmw\Documents\PowerShell\Modules\OM\Private\Workflow\Set-Tracks.ps1"

Write-Host "`n=== Testing Intelligent Variation Matching ===" -ForegroundColor Cyan
Write-Host "Album: Scott Ross - Goldberg Variations (32 tracks)`n" -ForegroundColor Gray

# Load audio files
$albumPath = "C:\Users\jmw\Documents\PowerShell\Modules\OM\testfiles\Scott Ross\0 - Bach - Goldberg Variations"
$audioFiles = Get-ChildItem -LiteralPath $albumPath -File | 
    Where-Object { $_.Extension -match '\.(mp3|flac|wav|m4a|aac|ogg|ape)' } |
    Sort-Object { [regex]::Replace($_.Name, '(\d+)', { $args[0].Value.PadLeft(10, '0') }) }

$audioFiles = foreach ($f in $audioFiles) {
    $tagFile = [TagLib.File]::Create($f.FullName)
    [PSCustomObject]@{
        FilePath    = $f.FullName
        DiscNumber  = $tagFile.Tag.Disc
        TrackNumber = $tagFile.Tag.Track
        Title       = $tagFile.Tag.Title
        Duration    = $tagFile.Properties.Duration.TotalSeconds
        TagFile     = $tagFile
        Name        = $f.Name
    }
}

Write-Host "Loaded $($audioFiles.Count) audio files" -ForegroundColor Green

# Create mock provider tracks (simulating Discogs/Spotify Goldberg Variations)
$providerTracks = @(
    [PSCustomObject]@{ name = "Aria"; disc_number = 1; track_number = 1; duration_ms = 180000 }
    [PSCustomObject]@{ name = "Variato 1 A 1 Clav."; disc_number = 1; track_number = 2; duration_ms = 120000 }
    [PSCustomObject]@{ name = "Variato 2 A 1 Clav."; disc_number = 1; track_number = 3; duration_ms = 90000 }
    [PSCustomObject]@{ name = "Variato 3 A 1 Clav. Canone All'unisono"; disc_number = 1; track_number = 4; duration_ms = 110000 }
    [PSCustomObject]@{ name = "Variato 4 A 1 Clav."; disc_number = 1; track_number = 5; duration_ms = 65000 }
    [PSCustomObject]@{ name = "Variato 5 A 1 O Vero 2 Clav."; disc_number = 1; track_number = 6; duration_ms = 95000 }
    [PSCustomObject]@{ name = "Variato 6 A 1 Clav. Canone Alla Seconda"; disc_number = 1; track_number = 7; duration_ms = 85000 }
    [PSCustomObject]@{ name = "Variato 7 A 1 O Vero 2 Clav. Al Tempo Di Giga"; disc_number = 1; track_number = 8; duration_ms = 110000 }
    [PSCustomObject]@{ name = "Variato 8 A 2 Clav."; disc_number = 1; track_number = 9; duration_ms = 95000 }
    [PSCustomObject]@{ name = "Variato 9 A 1 Clav. Canone Alla Terza"; disc_number = 1; track_number = 10; duration_ms = 100000 }
    [PSCustomObject]@{ name = "Variato 10 A 1 Clav. Fughetta"; disc_number = 1; track_number = 11; duration_ms = 75000 }
    [PSCustomObject]@{ name = "Variato 11 A 2 Clav."; disc_number = 1; track_number = 12; duration_ms = 105000 }
    [PSCustomObject]@{ name = "Variato 12 A 1 Clav. Canone Alla Quarta"; disc_number = 1; track_number = 13; duration_ms = 125000 }
    [PSCustomObject]@{ name = "Variato 13 A 2 Clav."; disc_number = 1; track_number = 14; duration_ms = 145000 }
    [PSCustomObject]@{ name = "Variato 14 A 2 Clav."; disc_number = 1; track_number = 15; duration_ms = 95000 }
    [PSCustomObject]@{ name = "Variato 15 A 1 Clav. Canone Alla Quinta. Andante"; disc_number = 1; track_number = 16; duration_ms = 185000 }
    [PSCustomObject]@{ name = "Variato 16 A 1 Clav. Ouverture"; disc_number = 1; track_number = 17; duration_ms = 145000 }
    [PSCustomObject]@{ name = "Variato 17 A 2 Clav."; disc_number = 1; track_number = 18; duration_ms = 95000 }
    [PSCustomObject]@{ name = "Variato 18 A 1 Clav. Canone Alla Sesta"; disc_number = 1; track_number = 19; duration_ms = 75000 }
    [PSCustomObject]@{ name = "Variato 19 A 1 Clav."; disc_number = 1; track_number = 20; duration_ms = 70000 }
    [PSCustomObject]@{ name = "Variato 20 A 2 Clav."; disc_number = 1; track_number = 21; duration_ms = 105000 }
    [PSCustomObject]@{ name = "Variato 21 A 1 Clav. Canone Alla Settima"; disc_number = 1; track_number = 22; duration_ms = 125000 }
    [PSCustomObject]@{ name = "Variato 22 A 1 Clav. Alla Breve"; disc_number = 1; track_number = 23; duration_ms = 55000 }
    [PSCustomObject]@{ name = "Variato 23 A 2 Clav."; disc_number = 1; track_number = 24; duration_ms = 100000 }
    [PSCustomObject]@{ name = "Variato 24 A 1 Clav. Canone All'ottava"; disc_number = 1; track_number = 25; duration_ms = 120000 }
    [PSCustomObject]@{ name = "Variato 25 A 2 Clav. Adagio"; disc_number = 1; track_number = 26; duration_ms = 320000 }
    [PSCustomObject]@{ name = "Variato 26 A 2 Clav."; disc_number = 1; track_number = 27; duration_ms = 95000 }
    [PSCustomObject]@{ name = "Variato 27 A 2 Clav. Canone Alla Nona"; disc_number = 1; track_number = 28; duration_ms = 95000 }
    [PSCustomObject]@{ name = "Variato 28 A 2 Clav."; disc_number = 1; track_number = 29; duration_ms = 115000 }
    [PSCustomObject]@{ name = "Variato 29 A 1 O Vero 2 Clav."; disc_number = 1; track_number = 30; duration_ms = 100000 }
    [PSCustomObject]@{ name = "Variato 30 A 1 Clav. Quodlibet"; disc_number = 1; track_number = 31; duration_ms = 95000 }
    [PSCustomObject]@{ name = "Aria Da Capo"; disc_number = 1; track_number = 32; duration_ms = 180000 }
)

Write-Host "Created $($providerTracks.Count) mock provider tracks`n" -ForegroundColor Green

# Test Set-Tracks with byTrackNumber method (which includes smart matching)
Write-Host "Testing Set-Tracks with byTrackNumber (should trigger smart matching)..." -ForegroundColor Yellow
Write-Host "Looking for: 'Using smart variation/movement matching (X matched)'" -ForegroundColor Gray
Write-Host ""

$result = Set-Tracks -AudioFiles $audioFiles -SpotifyTracks $providerTracks -SortMethod byTrackNumber -Reverse:$false -Verbose 4>&1

# Extract verbose messages about smart matching
$smartMatchMsg = $result | Where-Object { $_ -match "smart.*variation|Using smart" }
if ($smartMatchMsg) {
    Write-Host "`n✅ SMART MATCHING ACTIVATED:" -ForegroundColor Green
    $smartMatchMsg | ForEach-Object { Write-Host "   $_" -ForegroundColor Cyan }
} else {
    Write-Host "`n⚠️  Smart matching message not found in verbose output" -ForegroundColor Yellow
}

# Get the actual paired tracks result
$pairedTracks = $result | Where-Object { $_.PSObject.TypeNames[0] -eq 'System.Management.Automation.PSCustomObject' }

Write-Host "`n=== Pairing Results ===" -ForegroundColor Cyan
Write-Host "Total pairs: $($pairedTracks.Count)" -ForegroundColor White

# Count successful matches
$successfulMatches = @($pairedTracks | Where-Object { $_.AudioFile -and $_.SpotifyTrack }).Count
$highConfidence = @($pairedTracks | Where-Object { $_.ConfidenceLevel -eq 'High' }).Count
$mediumConfidence = @($pairedTracks | Where-Object { $_.ConfidenceLevel -eq 'Medium' }).Count
$lowConfidence = @($pairedTracks | Where-Object { $_.ConfidenceLevel -eq 'Low' }).Count

Write-Host "Successful matches: $successfulMatches / 32" -ForegroundColor $(if ($successfulMatches -ge 30) { 'Green' } else { 'Red' })
Write-Host "  High confidence: $highConfidence" -ForegroundColor Green
Write-Host "  Medium confidence: $mediumConfidence" -ForegroundColor Yellow
Write-Host "  Low confidence: $lowConfidence" -ForegroundColor Red

# Show first 10 pairings
Write-Host "`n=== First 10 Pairings ===" -ForegroundColor Cyan
$pairedTracks | Select-Object -First 10 | ForEach-Object {
    $audioName = if ($_.AudioFile) { [System.IO.Path]::GetFileNameWithoutExtension($_.AudioFile.FilePath) } else { "[UNPAIRED]" }
    $providerName = if ($_.SpotifyTrack) { $_.SpotifyTrack.name } else { "[UNPAIRED]" }
    $color = switch ($_.ConfidenceLevel) {
        'High' { 'Green' }
        'Medium' { 'Yellow' }
        'Low' { 'Red' }
        default { 'Gray' }
    }
    Write-Host "  $($audioName.PadRight(50)) ↔ $providerName" -ForegroundColor $color
}

# Cleanup
foreach ($af in $audioFiles) {
    if ($af.TagFile) {
        $af.TagFile.Dispose()
    }
}

Write-Host "`n=== Test Complete ===" -ForegroundColor Cyan
if ($successfulMatches -ge 30) {
    Write-Host "✅ SUCCESS: Smart matching working! ($successfulMatches/32 tracks matched)" -ForegroundColor Green
} else {
    Write-Host "❌ FAILURE: Only $successfulMatches/32 tracks matched" -ForegroundColor Red
}

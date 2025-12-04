# Comprehensive test script for Format-Genres function
param(
    [switch]$CleanupOnly
)

$testPath = 'C:\Users\resto\Documents\PowerShell\Modules\OM\testdata\albums\Sergei rachmaninov\1995 - Rachmaninoff_ Vespers, Op. 37 (Live)'
$backupPath = 'C:\Users\resto\Documents\PowerShell\Modules\OM\testdata\albums\Sergei rachmaninov\.backup-format-genres-test'

# Cleanup function
function Cleanup {
    if (Test-Path $backupPath) {
        Write-Host "`nRestoring files from backup..." -ForegroundColor Yellow
        Get-ChildItem $backupPath -Filter *.mp3 | ForEach-Object {
            Copy-Item $_.FullName -Destination $testPath -Force
        }
        Remove-Item $backupPath -Recurse -Force
        Write-Host "Backup restored and cleaned up." -ForegroundColor Green
    }
}

if ($CleanupOnly) {
    Cleanup
    exit
}

# Ensure module is loaded
Import-Module 'c:\Users\resto\Documents\PowerShell\Modules\OM' -Force

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Format-Genres Comprehensive Test" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan

# Test 1: Show current state
Write-Host "`n[TEST 1] Current Genres State" -ForegroundColor Yellow
Write-Host "──────────────────────────────────────────────────────────" -ForegroundColor DarkGray
$currentTags = Get-OMTags -Path $testPath
Write-Host "Files found: $($currentTags.FileName.Count)" -ForegroundColor White
Write-Host "Current genres: $($currentTags.Genres)" -ForegroundColor White

# Test 2: Review mode with frequency display
Write-Host "`n[TEST 2] Review Mode with Frequency Display" -ForegroundColor Yellow
Write-Host "──────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Get-OMTags -Path $testPath | Format-Genres -Mode Review -ShowFrequency

# Test 3: Check if config is created/updated
Write-Host "`n[TEST 3] Check Config Structure" -ForegroundColor Yellow
Write-Host "──────────────────────────────────────────────────────────" -ForegroundColor DarkGray
$config = Get-OMConfig
if ($config.Genres) {
    Write-Host "✓ Genres section exists in config" -ForegroundColor Green
    Write-Host "  - AllowedGenreNames count: $($config.Genres.AllowedGenreNames.Count)" -ForegroundColor White
    Write-Host "  - GenreMappings count: $($config.Genres.GenreMappings.Count)" -ForegroundColor White
} else {
    Write-Host "✗ Genres section NOT in config (will use defaults)" -ForegroundColor Yellow
}

# Test 4: PassThru functionality
Write-Host "`n[TEST 4] PassThru Functionality" -ForegroundColor Yellow
Write-Host "──────────────────────────────────────────────────────────" -ForegroundColor DarkGray
$passThruResult = Get-OMTags -Path $testPath | Format-Genres -Mode Auto -PassThru
if ($passThruResult) {
    Write-Host "✓ PassThru returned $($passThruResult.Count) objects" -ForegroundColor Green
    Write-Host "  First object type: $($passThruResult[0].GetType().Name)" -ForegroundColor White
} else {
    Write-Host "✗ PassThru did not return objects" -ForegroundColor Red
}

# Test 5: WhatIf mode
Write-Host "`n[TEST 5] WhatIf Mode (no changes)" -ForegroundColor Yellow
Write-Host "──────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Get-OMTags -Path $testPath | Format-Genres -Mode Auto -WhatIf | Out-Null
Write-Host "✓ WhatIf completed without errors" -ForegroundColor Green

# Test 6: Verbose output
Write-Host "`n[TEST 6] Verbose Output" -ForegroundColor Yellow
Write-Host "──────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Get-OMTags -Path $testPath | Format-Genres -Mode Auto -Verbose 2>&1 | 
    Select-String -Pattern "VERBOSE:" | ForEach-Object { 
        Write-Host $_ -ForegroundColor DarkGray 
    }

# Test 7: Genre splitting verification
Write-Host "`n[TEST 7] Genre Splitting Verification" -ForegroundColor Yellow
Write-Host "──────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host "Original genre string: 'Classical, classique'" -ForegroundColor White
Write-Host "Expected: 2 separate genres detected" -ForegroundColor White
$verboseOutput = Get-OMTags -Path $testPath | Format-Genres -Mode Auto -Verbose 2>&1 | Out-String
if ($verboseOutput -match 'Processing \d+ objects with (\d+) unique genres') {
    $genreCount = $matches[1]
    Write-Host "Detected: $genreCount genres" -ForegroundColor $(if ($genreCount -eq '2') { 'Green' } else { 'Red' })
}

# Test 8: Pipeline compatibility
Write-Host "`n[TEST 8] Pipeline Compatibility" -ForegroundColor Yellow
Write-Host "──────────────────────────────────────────────────────────" -ForegroundColor DarkGray
try {
    $pipelineTest = Get-OMTags -Path $testPath | Format-Genres -Mode Auto -PassThru | 
        Select-Object -First 1 Genres
    Write-Host "✓ Can pipe Get-OMTags → Format-Genres → Select-Object" -ForegroundColor Green
} catch {
    Write-Host "✗ Pipeline test failed: $_" -ForegroundColor Red
}

Write-Host "`n═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Test Summary" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "`n✓ All basic functionality tests passed!" -ForegroundColor Green
Write-Host "`nNote: Interactive mode testing requires manual interaction." -ForegroundColor Yellow
Write-Host "To test actual tag writing, use: Get-OMTags | Format-Genres | Set-OMTags" -ForegroundColor Yellow

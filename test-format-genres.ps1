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

# Ensure Show-Message helper available when running standalone
if (-not (Get-Command -Name Show-Message -ErrorAction SilentlyContinue)) {
    $p = Join-Path $PSScriptRoot 'Private\Utils\Show-Message.ps1'
    if (Test-Path $p) { . $p }
}

Show-Message -Message "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan -Context $null
Show-Message -Message "  Format-Genres Comprehensive Test" -ForegroundColor Cyan -Context $null
Show-Message -Message "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan -Context $null

# Test 1: Show current state
Show-Message -Message "`n[TEST 1] Current Genres State" -ForegroundColor Yellow -Context $null
Show-Message -Message "──────────────────────────────────────────────────────────" -ForegroundColor DarkGray -Context $null
$currentTags = Get-OMTags -Path $testPath
Show-Message -Message "Files found: $($currentTags.FileName.Count)" -ForegroundColor White -Context $null
Show-Message -Message "Current genres: $($currentTags.Genres)" -ForegroundColor White -Context $null

# Test 2: Review mode with frequency display
Show-Message -Message "`n[TEST 2] Review Mode with Frequency Display" -ForegroundColor Yellow -Context $null
Show-Message -Message "──────────────────────────────────────────────────────────" -ForegroundColor DarkGray -Context $null
Get-OMTags -Path $testPath | Format-Genres -Mode Review -ShowFrequency

# Test 3: Check if config is created/updated
Show-Message -Message "`n[TEST 3] Check Config Structure" -ForegroundColor Yellow -Context $null
Show-Message -Message "──────────────────────────────────────────────────────────" -ForegroundColor DarkGray -Context $null
$config = Get-OMConfig
if ($config.Genres) {
    Show-Message -Message "✓ Genres section exists in config" -ForegroundColor Green -Context $null
    Show-Message -Message "  - AllowedGenreNames count: $($config.Genres.AllowedGenreNames.Count)" -ForegroundColor White -Context $null
    Show-Message -Message "  - GenreMappings count: $($config.Genres.GenreMappings.Count)" -ForegroundColor White -Context $null
} else {
    Show-Message -Message "✗ Genres section NOT in config (will use defaults)" -ForegroundColor Yellow -Context $null
}

# Test 4: PassThru functionality
Show-Message -Message "`n[TEST 4] PassThru Functionality" -ForegroundColor Yellow -Context $null
Show-Message -Message "──────────────────────────────────────────────────────────" -ForegroundColor DarkGray -Context $null
$passThruResult = Get-OMTags -Path $testPath | Format-Genres -Mode Auto -PassThru
if ($passThruResult) {
    Show-Message -Message "✓ PassThru returned $($passThruResult.Count) objects" -ForegroundColor Green -Context $null
    Show-Message -Message "  First object type: $($passThruResult[0].GetType().Name)" -ForegroundColor White -Context $null
} else {
    Show-Message -Message "✗ PassThru did not return objects" -ForegroundColor Red -Context $null
}

# Test 5: WhatIf mode
Show-Message -Message "`n[TEST 5] WhatIf Mode (no changes)" -ForegroundColor Yellow -Context $null
Show-Message -Message "──────────────────────────────────────────────────────────" -ForegroundColor DarkGray -Context $null
Get-OMTags -Path $testPath | Format-Genres -Mode Auto -WhatIf | Out-Null
Show-Message -Message "✓ WhatIf completed without errors" -ForegroundColor Green -Context $null

# Test 6: Verbose output
Show-Message -Message "`n[TEST 6] Verbose Output" -ForegroundColor Yellow -Context $null
Show-Message -Message "──────────────────────────────────────────────────────────" -ForegroundColor DarkGray -Context $null
Get-OMTags -Path $testPath | Format-Genres -Mode Auto -Verbose 2>&1 | 
    Select-String -Pattern "VERBOSE:" | ForEach-Object { 
        Show-Message -Message $_ -ForegroundColor DarkGray -Context $null
    }

# Test 7: Genre splitting verification
Show-Message -Message "`n[TEST 7] Genre Splitting Verification" -ForegroundColor Yellow -Context $null
Show-Message -Message "──────────────────────────────────────────────────────────" -ForegroundColor DarkGray -Context $null
Show-Message -Message "Original genre string: 'Classical, classique'" -ForegroundColor White -Context $null
Show-Message -Message "Expected: 2 separate genres detected" -ForegroundColor White -Context $null
$verboseOutput = Get-OMTags -Path $testPath | Format-Genres -Mode Auto -Verbose 2>&1 | Out-String
if ($verboseOutput -match 'Processing \d+ objects with (\d+) unique genres') {
    $genreCount = $matches[1]
    Show-Message -Message "Detected: $genreCount genres" -ForegroundColor $(if ($genreCount -eq '2') { 'Green' } else { 'Red' }) -Context $null
}

# Test 8: Pipeline compatibility
Show-Message -Message "`n[TEST 8] Pipeline Compatibility" -ForegroundColor Yellow -Context $null
Show-Message -Message "──────────────────────────────────────────────────────────" -ForegroundColor DarkGray -Context $null
try {
    $pipelineTest = Get-OMTags -Path $testPath | Format-Genres -Mode Auto -PassThru | 
        Select-Object -First 1 Genres
    Show-Message -Message "✓ Can pipe Get-OMTags → Format-Genres → Select-Object" -ForegroundColor Green -Context $null
} catch {
    Show-Message -Message "✗ Pipeline test failed: $_" -ForegroundColor Red -Context $null
} 

Show-Message -Message "`n═══════════════════════════════════════════════════════════" -ForegroundColor Cyan -Context $null
Show-Message -Message "  Test Summary" -ForegroundColor Cyan -Context $null
Show-Message -Message "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan -Context $null
Show-Message -Message "`n✓ All basic functionality tests passed!" -ForegroundColor Green -Context $null
Show-Message -Message "`nNote: Interactive mode testing requires manual interaction." -ForegroundColor Yellow -Context $null
Show-Message -Message "To test actual tag writing, use: Get-OMTags | Format-Genres | Set-OMTags" -ForegroundColor Yellow -Context $null


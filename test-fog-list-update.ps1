# Test that [A]ddTo list updates after [N]ew adds a genre
cd 'c:\Users\resto\Documents\PowerShell\Modules\OM'
Import-Module ./OM.psd1 -Force

$testPath = "C:\Users\resto\Documents\PowerShell\Modules\OM\testdata\albums\Sergei rachmaninov\1995 - Rachmaninoff_ Vespers, Op. 37 (Live)"

Write-Host "=== Testing Genre List Updates ===" -ForegroundColor Cyan
Write-Host ""

# Setup
Write-Host "1. Creating test data with two unknown genres..." -ForegroundColor Yellow
got $testPath -Details | ForEach-Object { 
    $_.Genres = @('test-genre-alpha', 'test-genre-beta'); 
    $_ 
} | sot | Out-Null
Write-Host "   ✓ Test data ready" -ForegroundColor Green

Write-Host "`n2. Check initial genre count..." -ForegroundColor Yellow
$configBefore = Get-OMConfig
$countBefore = $configBefore.Genres.AllowedGenreNames.Count
Write-Host "   Genres before: $countBefore" -ForegroundColor Gray

Write-Host "`n3. Instructions for MANUAL TEST:" -ForegroundColor Yellow
Write-Host "   Run: got '$testPath' -Details | fog" -ForegroundColor White
Write-Host ""
Write-Host "   When prompted for 'test-genre-alpha':" -ForegroundColor Cyan
Write-Host "   - Choose: n" -ForegroundColor White
Write-Host "   - Type: Test Alpha" -ForegroundColor White
Write-Host "   - Press Enter" -ForegroundColor White
Write-Host ""
Write-Host "   When prompted for 'test-genre-beta':" -ForegroundColor Cyan
Write-Host "   - Choose: a" -ForegroundColor White
Write-Host "   - Look for 'Test Alpha' in the list (should be there!)" -ForegroundColor Green
Write-Host "   - If you see it at position X, type X and press Enter" -ForegroundColor White
Write-Host ""
Write-Host "   Expected: 'Test Alpha' appears in the [A]ddTo list" -ForegroundColor Green
Write-Host "   This proves the list updates dynamically!" -ForegroundColor Green
Write-Host ""

# Test semicolon splitting in genres
cd 'c:\Users\resto\Documents\PowerShell\Modules\OM'
Import-Module ./OM.psd1 -Force

$testPath = "C:\Users\resto\Documents\PowerShell\Modules\OM\testdata\albums\Sergei rachmaninov\1995 - Rachmaninoff_ Vespers, Op. 37 (Live)"

Write-Host "=== Testing Semicolon Genre Splitting ===" -ForegroundColor Cyan
Write-Host ""

# Test 1: Write semicolon-separated genres
Write-Host "1. Writing 'Classic Rock;Hard Rock;70s' to first file..." -ForegroundColor Yellow
$firstFile = got $testPath -Details | Select-Object -First 1
$firstFile.Genres = @('Classic Rock;Hard Rock;70s')
$firstFile | sot | Out-Null
Write-Host "   ✓ Written" -ForegroundColor Green

# Test 2: Read back and verify splitting
Write-Host "`n2. Reading back genres..." -ForegroundColor Yellow
$result = got $testPath -Details | Select-Object -First 1
Write-Host "   Genres as array:" -ForegroundColor Gray
$result.Genres | ForEach-Object { Write-Host "     - '$_'" -ForegroundColor White }

# Test 3: Verify count
Write-Host "`n3. Verification:" -ForegroundColor Yellow
$expectedCount = 3
$actualCount = $result.Genres.Count
if ($actualCount -eq $expectedCount) {
    Write-Host "   ✓ SUCCESS: Got $actualCount genres (expected $expectedCount)" -ForegroundColor Green
} else {
    Write-Host "   ✗ FAILED: Got $actualCount genres (expected $expectedCount)" -ForegroundColor Red
}

# Test 4: Mixed separators
Write-Host "`n4. Testing mixed comma and semicolon..." -ForegroundColor Yellow
$firstFile = got $testPath -Details | Select-Object -First 1
$firstFile.Genres = @('Rock, Pop; Jazz')
$firstFile | sot | Out-Null
$result = got $testPath -Details | Select-Object -First 1
Write-Host "   Input: 'Rock, Pop; Jazz'" -ForegroundColor Gray
Write-Host "   Output:" -ForegroundColor Gray
$result.Genres | ForEach-Object { Write-Host "     - '$_'" -ForegroundColor White }
if ($result.Genres.Count -eq 3) {
    Write-Host "   ✓ SUCCESS: Split on both separators" -ForegroundColor Green
} else {
    Write-Host "   ✗ FAILED: Got $($result.Genres.Count) genres (expected 3)" -ForegroundColor Red
}

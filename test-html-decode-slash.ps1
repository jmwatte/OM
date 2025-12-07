# Test HTML decoding and slash splitting
cd 'c:\Users\resto\Documents\PowerShell\Modules\OM'
Import-Module ./OM.psd1 -Force

$testPath = "C:\Users\resto\Documents\PowerShell\Modules\OM\testdata\albums\Sergei rachmaninov\1995 - Rachmaninoff_ Vespers, Op. 37 (Live)"

Write-Host "=== Testing HTML Decode & Slash Splitting ===" -ForegroundColor Cyan
Write-Host ""

# Test 1: HTML entity decoding
Write-Host "1. Testing HTML entity '&amp;' decoding..." -ForegroundColor Yellow
$firstFile = got $testPath -Details | Select-Object -First 1
$firstFile.Genres = @('R&amp;B', 'Soul')
$firstFile | sot | Out-Null
$result = got $testPath -Details | Select-Object -First 1
Write-Host "   Input: 'R&amp;B', 'Soul'" -ForegroundColor Gray
Write-Host "   Output:" -ForegroundColor Gray
$result.Genres | ForEach-Object { Write-Host "     - '$_'" -ForegroundColor White }
$hasRnB = $result.Genres -contains 'R&B'
if ($hasRnB) {
    Write-Host "   ✓ SUCCESS: HTML decoded to 'R&B'" -ForegroundColor Green
} else {
    Write-Host "   ✗ FAILED: Did not decode properly" -ForegroundColor Red
}

# Test 2: Slash splitting
Write-Host "`n2. Testing slash splitting..." -ForegroundColor Yellow
$firstFile = got $testPath -Details | Select-Object -First 1
$firstFile.Genres = @('Soul/Funk/R&B')
$firstFile | sot | Out-Null
$result = got $testPath -Details | Select-Object -First 1
Write-Host "   Input: 'Soul/Funk/R&B'" -ForegroundColor Gray
Write-Host "   Output:" -ForegroundColor Gray
$result.Genres | ForEach-Object { Write-Host "     - '$_'" -ForegroundColor White }
$expectedCount = 3
$actualCount = $result.Genres.Count
if ($actualCount -eq $expectedCount) {
    Write-Host "   ✓ SUCCESS: Split into $actualCount genres" -ForegroundColor Green
} else {
    Write-Host "   ✗ FAILED: Got $actualCount genres (expected $expectedCount)" -ForegroundColor Red
}

# Test 3: Complex case (your Funkadelic example)
Write-Host "`n3. Testing complex case: 'Soul/Funk/R&amp;B'..." -ForegroundColor Yellow
$firstFile = got $testPath -Details | Select-Object -First 1
$firstFile.Genres = @('Soul/Funk/R&amp;B')
$firstFile | sot | Out-Null
$result = got $testPath -Details | Select-Object -First 1
Write-Host "   Input: 'Soul/Funk/R&amp;B'" -ForegroundColor Gray
Write-Host "   Output:" -ForegroundColor Gray
$result.Genres | ForEach-Object { Write-Host "     - '$_'" -ForegroundColor White }

# Check results
$hasSoul = $result.Genres -contains 'Soul'
$hasFunk = $result.Genres -contains 'Funk'
$hasRnB = $result.Genres -contains 'R&B'
$hasNoB = $result.Genres -notcontains 'B'
$hasNoRampAmp = $result.Genres -notcontains 'R&Amp'

if ($hasSoul -and $hasFunk -and $hasRnB -and $hasNoB -and $hasNoRampAmp) {
    Write-Host "   ✓ SUCCESS: Correctly split and decoded!" -ForegroundColor Green
    Write-Host "     - Has 'Soul': $hasSoul" -ForegroundColor Green
    Write-Host "     - Has 'Funk': $hasFunk" -ForegroundColor Green
    Write-Host "     - Has 'R&B': $hasRnB" -ForegroundColor Green
    Write-Host "     - No 'B' artifact: $hasNoB" -ForegroundColor Green
    Write-Host "     - No 'R&Amp' artifact: $hasNoRampAmp" -ForegroundColor Green
} else {
    Write-Host "   ✗ FAILED:" -ForegroundColor Red
    Write-Host "     - Has 'Soul': $hasSoul" -ForegroundColor $(if ($hasSoul) {'Green'} else {'Red'})
    Write-Host "     - Has 'Funk': $hasFunk" -ForegroundColor $(if ($hasFunk) {'Green'} else {'Red'})
    Write-Host "     - Has 'R&B': $hasRnB" -ForegroundColor $(if ($hasRnB) {'Green'} else {'Red'})
    Write-Host "     - No 'B': $hasNoB" -ForegroundColor $(if ($hasNoB) {'Green'} else {'Red'})
    Write-Host "     - No 'R&Amp': $hasNoRampAmp" -ForegroundColor $(if ($hasNoRampAmp) {'Green'} else {'Red'})
}

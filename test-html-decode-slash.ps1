# Test HTML decoding and slash splitting
cd 'c:\Users\resto\Documents\PowerShell\Modules\OM'
Import-Module ./OM.psd1 -Force

# Ensure Show-Message helper available when running standalone
if (-not (Get-Command -Name Show-Message -ErrorAction SilentlyContinue)) {
    $p = Join-Path $PSScriptRoot 'Private\Utils\Show-Message.ps1'
    if (Test-Path $p) { . $p }
}

$testPath = "C:\Users\resto\Documents\PowerShell\Modules\OM\testdata\albums\Sergei rachmaninov\1995 - Rachmaninoff_ Vespers, Op. 37 (Live)"

Show-Message -Message "=== Testing HTML Decode & Slash Splitting ===" -ForegroundColor Cyan -Context $null
Show-Message -Message "" -Context $null

# Test 1: HTML entity decoding
Show-Message -Message "1. Testing HTML entity '&amp;' decoding..." -ForegroundColor Yellow -Context $null
$firstFile = got $testPath -Details | Select-Object -First 1
$firstFile.Genres = @('R&amp;B', 'Soul')
$firstFile | sot | Out-Null
$result = got $testPath -Details | Select-Object -First 1
Show-Message -Message "   Input: 'R&amp;B', 'Soul'" -ForegroundColor Gray -Context $null
Show-Message -Message "   Output:" -ForegroundColor Gray -Context $null
$result.Genres | ForEach-Object { Show-Message -Message "     - '$_'" -ForegroundColor White -Context $null }
$hasRnB = $result.Genres -contains 'R&B'
if ($hasRnB) {
    Show-Message -Message "   ✓ SUCCESS: HTML decoded to 'R&B'" -ForegroundColor Green -Context $null
} else {
    Show-Message -Message "   ✗ FAILED: Did not decode properly" -ForegroundColor Red -Context $null
}

# Test 2: Slash splitting
Show-Message -Message "`n2. Testing slash splitting..." -ForegroundColor Yellow -Context $null
$firstFile = got $testPath -Details | Select-Object -First 1
$firstFile.Genres = @('Soul/Funk/R&B')
$firstFile | sot | Out-Null
$result = got $testPath -Details | Select-Object -First 1
Show-Message -Message "   Input: 'Soul/Funk/R&B'" -ForegroundColor Gray -Context $null
Show-Message -Message "   Output:" -ForegroundColor Gray -Context $null
$result.Genres | ForEach-Object { Show-Message -Message "     - '$_'" -ForegroundColor White -Context $null }
$expectedCount = 3
$actualCount = $result.Genres.Count
if ($actualCount -eq $expectedCount) {
    Show-Message -Message "   ✓ SUCCESS: Split into $actualCount genres" -ForegroundColor Green -Context $null
} else {
    Show-Message -Message "   ✗ FAILED: Got $actualCount genres (expected $expectedCount)" -ForegroundColor Red -Context $null
}

# Test 3: Complex case (your Funkadelic example)
Show-Message -Message "`n3. Testing complex case: 'Soul/Funk/R&amp;B'..." -ForegroundColor Yellow -Context $null
$firstFile = got $testPath -Details | Select-Object -First 1
$firstFile.Genres = @('Soul/Funk/R&amp;B')
$firstFile | sot | Out-Null
$result = got $testPath -Details | Select-Object -First 1
Show-Message -Message "   Input: 'Soul/Funk/R&amp;B'" -ForegroundColor Gray -Context $null
Show-Message -Message "   Output:" -ForegroundColor Gray -Context $null
$result.Genres | ForEach-Object { Show-Message -Message "     - '$_'" -ForegroundColor White -Context $null }

# Check results
$hasSoul = $result.Genres -contains 'Soul'
$hasFunk = $result.Genres -contains 'Funk'
$hasRnB = $result.Genres -contains 'R&B'
$hasNoB = $result.Genres -notcontains 'B'
$hasNoRampAmp = $result.Genres -notcontains 'R&Amp'

if ($hasSoul -and $hasFunk -and $hasRnB -and $hasNoB -and $hasNoRampAmp) {
    Show-Message -Message "   ✓ SUCCESS: Correctly split and decoded!" -ForegroundColor Green -Context $null
    Show-Message -Message "     - Has 'Soul': $hasSoul" -ForegroundColor Green -Context $null
    Show-Message -Message "     - Has 'Funk': $hasFunk" -ForegroundColor Green -Context $null
    Show-Message -Message "     - Has 'R&B': $hasRnB" -ForegroundColor Green -Context $null
    Show-Message -Message "     - No 'B' artifact: $hasNoB" -ForegroundColor Green -Context $null
    Show-Message -Message "     - No 'R&Amp' artifact: $hasNoRampAmp" -ForegroundColor Green -Context $null
} else {
    Show-Message -Message "   ✗ FAILED:" -ForegroundColor Red -Context $null
    Show-Message -Message "     - Has 'Soul': $hasSoul" -ForegroundColor $(if ($hasSoul) {'Green'} else {'Red'}) -Context $null
    Show-Message -Message "     - Has 'Funk': $hasFunk" -ForegroundColor $(if ($hasFunk) {'Green'} else {'Red'}) -Context $null
    Show-Message -Message "     - Has 'R&B': $hasRnB" -ForegroundColor $(if ($hasRnB) {'Green'} else {'Red'}) -Context $null
    Show-Message -Message "     - No 'B': $hasNoB" -ForegroundColor $(if ($hasNoB) {'Green'} else {'Red'}) -Context $null
    Show-Message -Message "     - No 'R&Amp': $hasNoRampAmp" -ForegroundColor $(if ($hasNoRampAmp) {'Green'} else {'Red'}) -Context $null
}


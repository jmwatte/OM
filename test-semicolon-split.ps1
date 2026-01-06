# Test semicolon splitting in genres
# Ensure Show-Message helper available when running standalone
if (-not (Get-Command -Name Show-Message -ErrorAction SilentlyContinue)) {
    $p = Join-Path $PSScriptRoot 'Private\Utils\Show-Message.ps1'
    if (Test-Path $p) { . $p }
}
cd 'c:\Users\resto\Documents\PowerShell\Modules\OM'
Import-Module ./OM.psd1 -Force

$testPath = "C:\Users\resto\Documents\PowerShell\Modules\OM\testdata\albums\Sergei rachmaninov\1995 - Rachmaninoff_ Vespers, Op. 37 (Live)"

Show-Message -Message "=== Testing Semicolon Genre Splitting ===" -ForegroundColor Cyan -Context $null
Show-Message -Message "" -Context $null

# Test 1: Write semicolon-separated genres
Show-Message -Message "1. Writing 'Classic Rock;Hard Rock;70s' to first file..." -ForegroundColor Yellow -Context $null
$firstFile = got $testPath -Details | Select-Object -First 1
$firstFile.Genres = @('Classic Rock;Hard Rock;70s')
$firstFile | sot | Out-Null
Show-Message -Message "   ✓ Written" -ForegroundColor Green -Context $null

# Test 2: Read back and verify splitting
Show-Message -Message "`n2. Reading back genres..." -ForegroundColor Yellow -Context $null
$result = got $testPath -Details | Select-Object -First 1
Show-Message -Message "   Genres as array:" -ForegroundColor Gray -Context $null
$result.Genres | ForEach-Object { Show-Message -Message "     - '$_'" -ForegroundColor White -Context $null }

# Test 3: Verify count
Show-Message -Message "`n3. Verification:" -ForegroundColor Yellow -Context $null
$expectedCount = 3
$actualCount = $result.Genres.Count
if ($actualCount -eq $expectedCount) {
    Show-Message -Message "   ✓ SUCCESS: Got $actualCount genres (expected $expectedCount)" -ForegroundColor Green -Context $null
} else {
    Show-Message -Message "   ✗ FAILED: Got $actualCount genres (expected $expectedCount)" -ForegroundColor Red -Context $null
}

# Test 4: Mixed separators
Show-Message -Message "`n4. Testing mixed comma and semicolon..." -ForegroundColor Yellow -Context $null
$firstFile = got $testPath -Details | Select-Object -First 1
$firstFile.Genres = @('Rock, Pop; Jazz')
$firstFile | sot | Out-Null
$result = got $testPath -Details | Select-Object -First 1
Show-Message -Message "   Input: 'Rock, Pop; Jazz'" -ForegroundColor Gray -Context $null
Show-Message -Message "   Output:" -ForegroundColor Gray -Context $null
$result.Genres | ForEach-Object { Show-Message -Message "     - '$_'" -ForegroundColor White -Context $null }
if ($result.Genres.Count -eq 3) {
    Show-Message -Message "   ✓ SUCCESS: Split on both separators" -ForegroundColor Green -Context $null
} else {
    Show-Message -Message "   ✗ FAILED: Got $($result.Genres.Count) genres (expected 3)" -ForegroundColor Red -Context $null
}


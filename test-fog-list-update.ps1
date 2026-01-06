# Test that [A]ddTo list updates after [N]ew adds a genre
cd 'c:\Users\resto\Documents\PowerShell\Modules\OM'
Import-Module ./OM.psd1 -Force

# Ensure Show-Message helper available when running standalone
if (-not (Get-Command -Name Show-Message -ErrorAction SilentlyContinue)) {
    $p = Join-Path $PSScriptRoot 'Private\Utils\Show-Message.ps1'
    if (Test-Path $p) { . $p }
}

$testPath = "C:\Users\resto\Documents\PowerShell\Modules\OM\testdata\albums\Sergei rachmaninov\1995 - Rachmaninoff_ Vespers, Op. 37 (Live)"

Show-Message -Message "=== Testing Genre List Updates ===" -ForegroundColor Cyan -Context $null
Show-Message -Message "" -Context $null

# Setup
Show-Message -Message "1. Creating test data with two unknown genres..." -ForegroundColor Yellow -Context $null
got $testPath -Details | ForEach-Object { 
    $_.Genres = @('test-genre-alpha', 'test-genre-beta'); 
    $_ 
} | sot | Out-Null
Show-Message -Message "   ✓ Test data ready" -ForegroundColor Green -Context $null

Show-Message -Message "`n2. Check initial genre count..." -ForegroundColor Yellow -Context $null
$configBefore = Get-OMConfig
$countBefore = $configBefore.Genres.AllowedGenreNames.Count
Show-Message -Message "   Genres before: $countBefore" -ForegroundColor Gray -Context $null

Show-Message -Message "`n3. Instructions for MANUAL TEST:" -ForegroundColor Yellow -Context $null
Show-Message -Message "   Run: got '$testPath' -Details | fog" -ForegroundColor White -Context $null
Show-Message -Message "" -Context $null
Show-Message -Message "   When prompted for 'test-genre-alpha':" -ForegroundColor Cyan -Context $null
Show-Message -Message "   - Choose: n" -ForegroundColor White -Context $null
Show-Message -Message "   - Type: Test Alpha" -ForegroundColor White -Context $null
Show-Message -Message "   - Press Enter" -ForegroundColor White -Context $null
Show-Message -Message "" -Context $null
Show-Message -Message "   When prompted for 'test-genre-beta':" -ForegroundColor Cyan -Context $null
Show-Message -Message "   - Choose: a" -ForegroundColor White -Context $null
Show-Message -Message "   - Look for 'Test Alpha' in the list (should be there!)" -ForegroundColor Green -Context $null
Show-Message -Message "   - If you see it at position X, type X and press Enter" -ForegroundColor White -Context $null
Show-Message -Message "" -Context $null
Show-Message -Message "   Expected: 'Test Alpha' appears in the [A]ddTo list" -ForegroundColor Green -Context $null
Show-Message -Message "   This proves the list updates dynamically!" -ForegroundColor Green -Context $null
Show-Message -Message "" -Context $null


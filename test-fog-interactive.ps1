# Test Format-Genres [N]ew option with World genre
cd 'c:\Users\resto\Documents\PowerShell\Modules\OM'
Import-Module ./OM.psd1 -Force

$testPath = "C:\Users\resto\Documents\PowerShell\Modules\OM\testdata\albums\Sergei rachmaninov\1995 - Rachmaninoff_ Vespers, Op. 37 (Live)"

# Ensure Show-Message helper available when running standalone
if (-not (Get-Command -Name Show-Message -ErrorAction SilentlyContinue)) {
    $p = Join-Path $PSScriptRoot 'Private\Utils\Show-Message.ps1'
    if (Test-Path $p) { . $p }
}

Show-Message -Message "=== Test: Format-Genres [N]ew option ===" -ForegroundColor Cyan -Context $null
Show-Message -Message "" -Context $null

# Set up test data with a genre that needs mapping
Show-Message -Message "1. Setting up test data with 'musiques-du-monde' genre..." -ForegroundColor Yellow -Context $null
got $testPath -Details | ForEach-Object { $_.Genres = @('musiques-du-monde'); $_ } | sot | Out-Null
Show-Message -Message "   ✓ Test data ready" -ForegroundColor Green -Context $null

# Check config before
Show-Message -Message "`n2. Checking config BEFORE..." -ForegroundColor Yellow -Context $null
$configBefore = Get-OMConfig
$genresCountBefore = $configBefore.Genres.AllowedGenreNames.Count
$worldBeforeCount = ($configBefore.Genres.AllowedGenreNames | Where-Object { $_ -eq "World" }).Count
Show-Message -Message "   Total allowed genres: $genresCountBefore" -ForegroundColor Gray -Context $null
Show-Message -Message "   'World' in list: $($worldBeforeCount -gt 0)" -ForegroundColor Gray -Context $null

# Remove World from config if it exists (to test adding it fresh)
if ($worldBeforeCount -gt 0) {
    Show-Message -Message "   Removing existing 'World' for clean test..." -ForegroundColor Gray -Context $null
    $configBefore.Genres.AllowedGenreNames = @($configBefore.Genres.AllowedGenreNames | Where-Object { $_ -ne "World" })
    $configPath = Join-Path $env:USERPROFILE '.OM' 'config.json'
    $configBefore | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath -Force
    Show-Message -Message "   ✓ Removed 'World' for testing" -ForegroundColor Green -Context $null
}

# Instructions for manual test
Show-Message -Message "`n3. Now run Format-Genres manually:" -ForegroundColor Yellow -Context $null
Show-Message -Message "   PS> got '$testPath' -Details | fog" -ForegroundColor White -Context $null
Show-Message -Message "" -Context $null
Write-Host "   When prompted for 'musiques-du-monde':" -ForegroundColor Cyan
Write-Host "   - Choose: n" -ForegroundColor White
Write-Host "   - Type: world" -ForegroundColor White
Write-Host "   - Press Enter" -ForegroundColor White
Write-Host ""
Write-Host "   Then run this to verify:" -ForegroundColor Cyan
Write-Host "   PS> (Get-OMConfig).Genres.AllowedGenreNames.Count" -ForegroundColor White
Write-Host "   PS> (Get-OMConfig).Genres.AllowedGenreNames | Where-Object { `$_ -eq 'World' }" -ForegroundColor White
Write-Host ""


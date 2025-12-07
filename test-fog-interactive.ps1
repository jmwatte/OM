# Test Format-Genres [N]ew option with World genre
cd 'c:\Users\resto\Documents\PowerShell\Modules\OM'
Import-Module ./OM.psd1 -Force

$testPath = "C:\Users\resto\Documents\PowerShell\Modules\OM\testdata\albums\Sergei rachmaninov\1995 - Rachmaninoff_ Vespers, Op. 37 (Live)"

Write-Host "=== Test: Format-Genres [N]ew option ===" -ForegroundColor Cyan
Write-Host ""

# Set up test data with a genre that needs mapping
Write-Host "1. Setting up test data with 'musiques-du-monde' genre..." -ForegroundColor Yellow
got $testPath -Details | ForEach-Object { $_.Genres = @('musiques-du-monde'); $_ } | sot | Out-Null
Write-Host "   ✓ Test data ready" -ForegroundColor Green

# Check config before
Write-Host "`n2. Checking config BEFORE..." -ForegroundColor Yellow
$configBefore = Get-OMConfig
$genresCountBefore = $configBefore.Genres.AllowedGenreNames.Count
$worldBeforeCount = ($configBefore.Genres.AllowedGenreNames | Where-Object { $_ -eq "World" }).Count
Write-Host "   Total allowed genres: $genresCountBefore" -ForegroundColor Gray
Write-Host "   'World' in list: $($worldBeforeCount -gt 0)" -ForegroundColor Gray

# Remove World from config if it exists (to test adding it fresh)
if ($worldBeforeCount -gt 0) {
    Write-Host "   Removing existing 'World' for clean test..." -ForegroundColor Gray
    $configBefore.Genres.AllowedGenreNames = @($configBefore.Genres.AllowedGenreNames | Where-Object { $_ -ne "World" })
    $configPath = Join-Path $env:USERPROFILE '.OM' 'config.json'
    $configBefore | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath -Force
    Write-Host "   ✓ Removed 'World' for testing" -ForegroundColor Green
}

# Instructions for manual test
Write-Host "`n3. Now run Format-Genres manually:" -ForegroundColor Yellow
Write-Host "   PS> got '$testPath' -Details | fog" -ForegroundColor White
Write-Host ""
Write-Host "   When prompted for 'musiques-du-monde':" -ForegroundColor Cyan
Write-Host "   - Choose: n" -ForegroundColor White
Write-Host "   - Type: world" -ForegroundColor White
Write-Host "   - Press Enter" -ForegroundColor White
Write-Host ""
Write-Host "   Then run this to verify:" -ForegroundColor Cyan
Write-Host "   PS> (Get-OMConfig).Genres.AllowedGenreNames.Count" -ForegroundColor White
Write-Host "   PS> (Get-OMConfig).Genres.AllowedGenreNames | Where-Object { `$_ -eq 'World' }" -ForegroundColor White
Write-Host ""

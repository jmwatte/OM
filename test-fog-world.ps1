# Test Format-Genres adding "World" genre
cd 'c:\Users\resto\Documents\PowerShell\Modules\OM'
Import-Module ./OM.psd1 -Force

$testPath = "C:\Users\resto\Documents\PowerShell\Modules\OM\testdata\albums\Sergei rachmaninov\1995 - Rachmaninoff_ Vespers, Op. 37 (Live)"

Write-Host "=== Test: Adding 'World' genre ===" -ForegroundColor Cyan
Write-Host ""

# Set up test data
Write-Host "1. Setting test genre..." -ForegroundColor Yellow
got $testPath -Details | ForEach-Object { $_.Genres = @('test-world-genre'); $_ } | sot | Out-Null
Write-Host "   ✓ Test data ready" -ForegroundColor Green

# Check config before
Write-Host "`n2. Checking allowed genres BEFORE adding World..." -ForegroundColor Yellow
$configBefore = Get-OMConfig
$worldBeforeCount = ($configBefore.Genres.AllowedGenreNames | Where-Object { $_ -like "*World*" }).Count
Write-Host "   Genres with 'World': $worldBeforeCount" -ForegroundColor Gray

# Manually add World to test the process
Write-Host "`n3. Manually calling Format-Genres internals to add World..." -ForegroundColor Yellow

# Get the data
$details = got $testPath -Details

# Simulate what happens in [N]ew handler
$textInfo = (Get-Culture).TextInfo
$newGenre = $textInfo.ToTitleCase("world".ToLower())
Write-Host "   Input: 'world' → Capitalized: '$newGenre'" -ForegroundColor Gray

# Load config and add to it
$config = Get-OMConfig
if (-not $config.Genres.AllowedGenreNames) {
    $config.Genres | Add-Member -NotePropertyName AllowedGenreNames -NotePropertyValue @() -Force
}

# Check if World already exists
$worldExists = $config.Genres.AllowedGenreNames -contains $newGenre
Write-Host "   'World' already in config: $worldExists" -ForegroundColor Gray

if (-not $worldExists) {
    # Add World to the config
    $config.Genres.AllowedGenreNames += $newGenre
    
    # Save config
    $configPath = Join-Path $env:USERPROFILE '.OM' 'config.json'
    $config | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath -Force
    Write-Host "   ✓ Added 'World' to config" -ForegroundColor Green
} else {
    Write-Host "   ! 'World' already exists in config" -ForegroundColor Yellow
}

# Check config after
Write-Host "`n4. Checking allowed genres AFTER adding World..." -ForegroundColor Yellow
$configAfter = Get-OMConfig
$worldAfterCount = ($configAfter.Genres.AllowedGenreNames | Where-Object { $_ -eq "World" }).Count
$totalGenres = $configAfter.Genres.AllowedGenreNames.Count
Write-Host "   Total allowed genres: $totalGenres" -ForegroundColor Gray
Write-Host "   Genres matching 'World': $worldAfterCount" -ForegroundColor Gray

if ($worldAfterCount -gt 0) {
    Write-Host "`n✓ SUCCESS: 'World' is now in the allowed genres list!" -ForegroundColor Green
    Write-Host "   You should now see 112 genres (111 + World)" -ForegroundColor Gray
} else {
    Write-Host "`n✗ FAILED: 'World' was not added to the allowed genres list" -ForegroundColor Red
}

Write-Host "`n5. Showing genres containing 'World':" -ForegroundColor Yellow
$configAfter.Genres.AllowedGenreNames | Where-Object { $_ -like "*World*" } | ForEach-Object {
    Write-Host "   - $_" -ForegroundColor White
}

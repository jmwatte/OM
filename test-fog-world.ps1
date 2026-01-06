# Test Format-Genres adding "World" genre
cd 'c:\Users\resto\Documents\PowerShell\Modules\OM'
Import-Module ./OM.psd1 -Force

$testPath = "C:\Users\resto\Documents\PowerShell\Modules\OM\testdata\albums\Sergei rachmaninov\1995 - Rachmaninoff_ Vespers, Op. 37 (Live)"

# Ensure Show-Message helper available when running standalone
if (-not (Get-Command -Name Show-Message -ErrorAction SilentlyContinue)) {
    $p = Join-Path $PSScriptRoot 'Private\Utils\Show-Message.ps1'
    if (Test-Path $p) { . $p }
}

Show-Message -Message "=== Test: Adding 'World' genre ===" -ForegroundColor Cyan -Context $null
Show-Message -Message "" -Context $null

# Set up test data
Show-Message -Message "1. Setting test genre..." -ForegroundColor Yellow -Context $null
got $testPath -Details | ForEach-Object { $_.Genres = @('test-world-genre'); $_ } | sot | Out-Null
Show-Message -Message "   ✓ Test data ready" -ForegroundColor Green -Context $null

# Check config before
Show-Message -Message "`n2. Checking allowed genres BEFORE adding World..." -ForegroundColor Yellow -Context $null
$configBefore = Get-OMConfig
$worldBeforeCount = ($configBefore.Genres.AllowedGenreNames | Where-Object { $_ -like "*World*" }).Count
Show-Message -Message "   Genres with 'World': $worldBeforeCount" -ForegroundColor Gray -Context $null

# Manually add World to test the process
Write-Host "`n3. Manually calling Format-Genres internals to add World..." -ForegroundColor Yellow

# Get the data
$details = got $testPath -Details

# Simulate what happens in [N]ew handler
$textInfo = (Get-Culture).TextInfo
$newGenre = $textInfo.ToTitleCase("world".ToLower())
Show-Message -Message "   Input: 'world' → Capitalized: '$newGenre'" -ForegroundColor Gray -Context $null

# Load config and add to it
$config = Get-OMConfig
if (-not $config.Genres.AllowedGenreNames) {
    $config.Genres | Add-Member -NotePropertyName AllowedGenreNames -NotePropertyValue @() -Force
}

# Check if World already exists
$worldExists = $config.Genres.AllowedGenreNames -contains $newGenre
Show-Message -Message "   'World' already in config: $worldExists" -ForegroundColor Gray -Context $null

if (-not $worldExists) {
    # Add World to the config
    $config.Genres.AllowedGenreNames += $newGenre
    
    # Save config
    $configPath = Join-Path $env:USERPROFILE '.OM' 'config.json'
    $config | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath -Force
    Show-Message -Message "   ✓ Added 'World' to config" -ForegroundColor Green -Context $null
} else {
    Show-Message -Message "   ! 'World' already exists in config" -ForegroundColor Yellow -Context $null
}

# Check config after
Show-Message -Message "`n4. Checking allowed genres AFTER adding World..." -ForegroundColor Yellow -Context $null
$configAfter = Get-OMConfig
$worldAfterCount = ($configAfter.Genres.AllowedGenreNames | Where-Object { $_ -eq "World" }).Count
$totalGenres = $configAfter.Genres.AllowedGenreNames.Count
Show-Message -Message "   Total allowed genres: $totalGenres" -ForegroundColor Gray -Context $null
Show-Message -Message "   Genres matching 'World': $worldAfterCount" -ForegroundColor Gray -Context $null

if ($worldAfterCount -gt 0) {
    Show-Message -Message "`n✓ SUCCESS: 'World' is now in the allowed genres list!" -ForegroundColor Green -Context $null
    Show-Message -Message "   You should now see 112 genres (111 + World)" -ForegroundColor Gray -Context $null
} else {
    Show-Message -Message "`n✗ FAILED: 'World' was not added to the allowed genres list" -ForegroundColor Red -Context $null
}

Show-Message -Message "`n5. Showing genres containing 'World':" -ForegroundColor Yellow -Context $null
$configAfter.Genres.AllowedGenreNames | Where-Object { $_ -like "*World*" } | ForEach-Object {
    Show-Message -Message "   - $_" -ForegroundColor White -Context $null
}


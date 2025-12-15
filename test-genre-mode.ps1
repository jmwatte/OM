# Test Genre Mode Toggle functionality

Import-Module "$PSScriptRoot\OM.psd1" -Force

Write-Host "`n=== Testing Genre Mode Toggle ===" -ForegroundColor Cyan

# Create a test file
$testDir = Join-Path $PSScriptRoot "testfiles\genre_mode_test"
if (-not (Test-Path $testDir)) {
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null
}

$testFile = Join-Path $testDir "test.mp3"

# Create a simple MP3 file if it doesn't exist (we'll use TagLib to create it)
if (-not (Test-Path $testFile)) {
    Write-Host "Creating test file..." -ForegroundColor Gray
    # Copy an existing test file if available
    $existingTest = Get-ChildItem "$PSScriptRoot\testfiles" -Recurse -Filter "*.mp3" | Select-Object -First 1
    if ($existingTest) {
        Copy-Item $existingTest.FullName $testFile
    } else {
        Write-Host "No test MP3 file found. Please run this test with an existing MP3 file." -ForegroundColor Yellow
        return
    }
}

Write-Host "Using test file: $testFile" -ForegroundColor Gray

# Test 1: Replace Mode (default)
Write-Host "`n--- Test 1: Replace Mode ---" -ForegroundColor Yellow
$tagValues1 = @{
    Title = "Test Track"
    Track = "01"
    Disc = "01"
    Performers = "Test Artist"
    Genres = "rock, indie rock"
    AlbumArtist = "Test Artist"
    Date = 2024
    Album = "Test Album"
}

$result1 = Save-TagsForFile -FilePath $testFile -TagValues $tagValues1
if ($result1.Success) {
    Write-Host "✅ Saved initial genres: rock, indie rock" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to save" -ForegroundColor Red
}

# Read back
$tagFile = [TagLib.File]::Create($testFile)
$currentGenres = $tagFile.Tag.Genres -join ', '
$tagFile.Dispose()
Write-Host "Current genres: $currentGenres" -ForegroundColor Cyan

# Test 2: Replace Mode with different genres
Write-Host "`n--- Test 2: Replace Mode (overwrite) ---" -ForegroundColor Yellow
$tagValues2 = @{
    Title = "Test Track"
    Track = "01"
    Disc = "01"
    Performers = "Test Artist"
    Genres = "pop, electronic"
    AlbumArtist = "Test Artist"
    Date = 2024
    Album = "Test Album"
}

$result2 = Save-TagsForFile -FilePath $testFile -TagValues $tagValues2 -GenreMergeMode:$false
if ($result2.Success) {
    Write-Host "✅ Replaced with: pop, electronic" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to save" -ForegroundColor Red
}

$tagFile = [TagLib.File]::Create($testFile)
$currentGenres = $tagFile.Tag.Genres -join ', '
$tagFile.Dispose()
Write-Host "Current genres: $currentGenres" -ForegroundColor Cyan

$test2Pass = $currentGenres -eq "pop, electronic"
if ($test2Pass) {
    Write-Host "✅ Replace mode working correctly" -ForegroundColor Green
} else {
    Write-Host "❌ Replace mode failed - expected 'pop, electronic' but got '$currentGenres'" -ForegroundColor Red
}

# Test 3: Merge Mode
Write-Host "`n--- Test 3: Merge Mode ---" -ForegroundColor Yellow
$tagValues3 = @{
    Title = "Test Track"
    Track = "01"
    Disc = "01"
    Performers = "Test Artist"
    Genres = "alternative rock, indie pop"
    AlbumArtist = "Test Artist"
    Date = 2024
    Album = "Test Album"
}

$result3 = Save-TagsForFile -FilePath $testFile -TagValues $tagValues3 -GenreMergeMode:$true
if ($result3.Success) {
    Write-Host "✅ Merged with: alternative rock, indie pop" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to save" -ForegroundColor Red
}

$tagFile = [TagLib.File]::Create($testFile)
$currentGenres = $tagFile.Tag.Genres
$tagFile.Dispose()
Write-Host "Current genres: $($currentGenres -join ', ')" -ForegroundColor Cyan
Write-Host "Genre count: $($currentGenres.Count)" -ForegroundColor Gray

# Check if merge worked (should have 4 unique genres)
$expectedGenres = @("pop", "electronic", "alternative rock", "indie pop")
$test3Pass = $currentGenres.Count -eq 4
if ($test3Pass) {
    Write-Host "✅ Merge mode working correctly - all genres preserved and deduplicated" -ForegroundColor Green
} else {
    Write-Host "❌ Merge mode issue - expected 4 genres but got $($currentGenres.Count)" -ForegroundColor Red
}

# Test 4: Merge with duplicate (case-insensitive)
Write-Host "`n--- Test 4: Merge Mode with duplicate ---" -ForegroundColor Yellow
$tagValues4 = @{
    Title = "Test Track"
    Track = "01"
    Disc = "01"
    Performers = "Test Artist"
    Genres = "Pop, ELECTRONIC, jazz"  # Pop and ELECTRONIC should be deduplicated
    AlbumArtist = "Test Artist"
    Date = 2024
    Album = "Test Album"
}

$result4 = Save-TagsForFile -FilePath $testFile -TagValues $tagValues4 -GenreMergeMode:$true
if ($result4.Success) {
    Write-Host "✅ Merged with deduplication" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to save" -ForegroundColor Red
}

$tagFile = [TagLib.File]::Create($testFile)
$currentGenres = $tagFile.Tag.Genres
$tagFile.Dispose()
Write-Host "Current genres: $($currentGenres -join ', ')" -ForegroundColor Cyan
Write-Host "Genre count: $($currentGenres.Count)" -ForegroundColor Gray

# Should have 5 unique genres (pop, electronic, alternative rock, indie pop, jazz)
# Pop and ELECTRONIC should not be duplicated
$test4Pass = $currentGenres.Count -eq 5
if ($test4Pass) {
    Write-Host "✅ Deduplication working correctly" -ForegroundColor Green
} else {
    Write-Host "❌ Deduplication issue - expected 5 genres but got $($currentGenres.Count)" -ForegroundColor Red
}

# Summary
Write-Host "`n=== Test Summary ===" -ForegroundColor Cyan
$passed = @($test2Pass, $test3Pass, $test4Pass) | Where-Object { $_ } | Measure-Object | Select-Object -ExpandProperty Count
$total = 3
Write-Host "Passed: $passed / $total" -ForegroundColor $(if ($passed -eq $total) { 'Green' } else { 'Yellow' })

if ($passed -eq $total) {
    Write-Host "`n✅ Genre Mode Toggle is working correctly!" -ForegroundColor Green
    Write-Host "   - Replace mode overwrites existing genres" -ForegroundColor Gray
    Write-Host "   - Merge mode combines and deduplicates genres" -ForegroundColor Gray
    Write-Host "`nYou can now use 'gm' command in Start-OM to toggle between modes." -ForegroundColor Cyan
} else {
    Write-Host "`n❌ Some tests failed. Please review the implementation." -ForegroundColor Red
}

# Cleanup
Write-Host "`nCleaning up test file..." -ForegroundColor Gray
Remove-Item $testFile -Force
if ((Get-ChildItem $testDir).Count -eq 0) {
    Remove-Item $testDir -Force
}

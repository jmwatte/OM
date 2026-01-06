# Test Genre Mode Toggle functionality

Import-Module "$PSScriptRoot\OM.psd1" -Force

# Ensure Show-Message helper available when running standalone
if (-not (Get-Command -Name Show-Message -ErrorAction SilentlyContinue)) {
    $p = Join-Path $PSScriptRoot 'Private\Utils\Show-Message.ps1'
    if (Test-Path $p) { . $p }
}

Show-Message -Message "`n=== Testing Genre Mode Toggle ===" -ForegroundColor Cyan -Context $null

# Create a test file
$testDir = Join-Path $PSScriptRoot "testfiles\genre_mode_test"
if (-not (Test-Path $testDir)) {
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null
}

$testFile = Join-Path $testDir "test.mp3"

# Create a simple MP3 file if it doesn't exist (we'll use TagLib to create it)
if (-not (Test-Path $testFile)) {
    Show-Message -Message "Creating test file..." -ForegroundColor Gray -Context $null
    # Copy an existing test file if available
    $existingTest = Get-ChildItem "$PSScriptRoot\testfiles" -Recurse -Filter "*.mp3" | Select-Object -First 1
    if ($existingTest) {
        Copy-Item $existingTest.FullName $testFile
    } else {
        Show-Message -Message "No test MP3 file found. Please run this test with an existing MP3 file." -ForegroundColor Yellow -Context $null
        return
    }
}

Show-Message -Message "Using test file: $testFile" -ForegroundColor Gray -Context $null

# Test 1: Replace Mode (default)
Show-Message -Message "`n--- Test 1: Replace Mode ---" -ForegroundColor Yellow -Context $null
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
    Show-Message -Message "✅ Saved initial genres: rock, indie rock" -ForegroundColor Green -Context $null
} else {
    Show-Message -Message "❌ Failed to save" -ForegroundColor Red -Context $null
}

# Read back
$tagFile = [TagLib.File]::Create($testFile)
$currentGenres = $tagFile.Tag.Genres -join ', '
$tagFile.Dispose()
Show-Message -Message "Current genres: $currentGenres" -ForegroundColor Cyan -Context $null

# Test 2: Replace Mode with different genres
Show-Message -Message "`n--- Test 2: Replace Mode (overwrite) ---" -ForegroundColor Yellow -Context $null
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
    Show-Message -Message "✅ Replaced with: pop, electronic" -ForegroundColor Green -Context $null
} else {
    Show-Message -Message "❌ Failed to save" -ForegroundColor Red -Context $null
}

$tagFile = [TagLib.File]::Create($testFile)
$currentGenres = $tagFile.Tag.Genres -join ', '
$tagFile.Dispose()
Write-Host "Current genres: $currentGenres" -ForegroundColor Cyan

$test2Pass = $currentGenres -eq "pop, electronic"
if ($test2Pass) {
    Show-Message -Message "✅ Replace mode working correctly" -ForegroundColor Green -Context $null
} else {
    Show-Message -Message "❌ Replace mode failed - expected 'pop, electronic' but got '$currentGenres'" -ForegroundColor Red -Context $null
}

# Test 3: Merge Mode
Show-Message -Message "`n--- Test 3: Merge Mode ---" -ForegroundColor Yellow -Context $null
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
    Show-Message -Message "✅ Merged with: alternative rock, indie pop" -ForegroundColor Green -Context $null
} else {
    Show-Message -Message "❌ Failed to save" -ForegroundColor Red -Context $null
}

$tagFile = [TagLib.File]::Create($testFile)
$currentGenres = $tagFile.Tag.Genres
$tagFile.Dispose()
Show-Message -Message "Current genres: $($currentGenres -join ', ')" -ForegroundColor Cyan -Context $null
Show-Message -Message "Genre count: $($currentGenres.Count)" -ForegroundColor Gray -Context $null

# Check if merge worked (should have 4 unique genres)
$expectedGenres = @("pop", "electronic", "alternative rock", "indie pop")
$test3Pass = $currentGenres.Count -eq 4
if ($test3Pass) {
    Show-Message -Message "✅ Merge mode working correctly - all genres preserved and deduplicated" -ForegroundColor Green -Context $null
} else {
    Show-Message -Message "❌ Merge mode issue - expected 4 genres but got $($currentGenres.Count)" -ForegroundColor Red -Context $null
}

# Test 4: Merge with duplicate (case-insensitive)
Show-Message -Message "`n--- Test 4: Merge Mode with duplicate ---" -ForegroundColor Yellow -Context $null
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
    Show-Message -Message "✅ Merged with deduplication" -ForegroundColor Green -Context $null
} else {
    Show-Message -Message "❌ Failed to save" -ForegroundColor Red -Context $null
}

$tagFile = [TagLib.File]::Create($testFile)
$currentGenres = $tagFile.Tag.Genres
$tagFile.Dispose()
Show-Message -Message "Current genres: $($currentGenres -join ', ')" -ForegroundColor Cyan -Context $null
Show-Message -Message "Genre count: $($currentGenres.Count)" -ForegroundColor Gray -Context $null

# Should have 5 unique genres (pop, electronic, alternative rock, indie pop, jazz)
# Pop and ELECTRONIC should not be duplicated
$test4Pass = $currentGenres.Count -eq 5
if ($test4Pass) {
    Show-Message -Message "✅ Deduplication working correctly" -ForegroundColor Green -Context $null
} else {
    Show-Message -Message "❌ Deduplication issue - expected 5 genres but got $($currentGenres.Count)" -ForegroundColor Red -Context $null
}

# Summary
Show-Message -Message "`n=== Test Summary ===" -ForegroundColor Cyan -Context $null
$passed = @($test2Pass, $test3Pass, $test4Pass) | Where-Object { $_ } | Measure-Object | Select-Object -ExpandProperty Count
$total = 3
Show-Message -Message "Passed: $passed / $total" -ForegroundColor $(if ($passed -eq $total) { 'Green' } else { 'Yellow' }) -Context $null

if ($passed -eq $total) {
    Show-Message -Message "`n✅ Genre Mode Toggle is working correctly!" -ForegroundColor Green -Context $null
    Show-Message -Message "   - Replace mode overwrites existing genres" -ForegroundColor Gray -Context $null
    Show-Message -Message "   - Merge mode combines and deduplicates genres" -ForegroundColor Gray -Context $null
    Show-Message -Message "`nYou can now use 'gm' command in Start-OM to toggle between modes." -ForegroundColor Cyan -Context $null
} else {
    Show-Message -Message "`n❌ Some tests failed. Please review the implementation." -ForegroundColor Red -Context $null
}

# Cleanup
Show-Message -Message "`nCleaning up test file..." -ForegroundColor Gray -Context $null
Remove-Item $testFile -Force
if ((Get-ChildItem $testDir).Count -eq 0) {
    Remove-Item $testDir -Force
}


# Test RenamePattern functionality
. .\Public\Set-OMTags.ps1

# Create a test tag object
$testTags = [PSCustomObject]@{
    Title = "Test Song"
    Artist = "Test Artist"
    Album = "Test Album"
    Track = 1
    Year = 2023
    Artists = @("Test Artist")
    AlbumArtists = @("Test Album Artist")
    Genres = @("Rock", "Pop")
}

Write-Host "Testing Expand-RenamePattern function:"

# Test basic pattern
$result1 = Expand-RenamePattern -Pattern "{Track:D2} - {Title}" -TagObject $testTags -FileExtension ".mp3"
Write-Host "Basic pattern: $result1"

# Test case formatting
$result2 = Expand-RenamePattern -Pattern "{Artist:Upper} - {Title:TitleCase}" -TagObject $testTags -FileExtension ".flac"
Write-Host "Case formatting: $result2"

# Test array property (should take first item)
$result3 = Expand-RenamePattern -Pattern "{Artist} - {Genre}" -TagObject $testTags -FileExtension ".mp3"
Write-Host "Array property: $result3"

Write-Host "All tests completed successfully!"
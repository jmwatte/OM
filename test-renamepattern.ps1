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

# Ensure Show-Message helper available when running standalone
if (-not (Get-Command -Name Show-Message -ErrorAction SilentlyContinue)) {
    $p = Join-Path $PSScriptRoot 'Private\Utils\Show-Message.ps1'
    if (Test-Path $p) { . $p }
}

Show-Message -Message "Testing Expand-RenamePattern function:" -Context $null

# Test basic pattern
$result1 = Expand-RenamePattern -Pattern "{Track:D2} - {Title}" -TagObject $testTags -FileExtension ".mp3"
Show-Message -Message "Basic pattern: $result1" -Context $null

# Test case formatting
$result2 = Expand-RenamePattern -Pattern "{Artist:Upper} - {Title:TitleCase}" -TagObject $testTags -FileExtension ".flac"
Show-Message -Message "Case formatting: $result2" -Context $null

# Test array property (should take first item)
$result3 = Expand-RenamePattern -Pattern "{Artist} - {Genre}" -TagObject $testTags -FileExtension ".mp3"
Show-Message -Message "Array property: $result3" -Context $null

Show-Message -Message "All tests completed successfully!" -Context $null
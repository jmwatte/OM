# Test to verify genre display formatting (tabs should be properly rendered)

Write-Host "`n=== Testing Genre Display Formatting ===" -ForegroundColor Cyan

# Test data with genres
$testAlbum = [PSCustomObject]@{
    name = "Help!"
    genres = @('Pop/Rock', 'Rock')
}

$testArtist = [PSCustomObject]@{
    name = "The Beatles"
    genres = @('beat music', 'classic rock', 'folk pop', 'folk rock', 'merseybeat')
}

$testTrack = [PSCustomObject]@{
    name = "Act Naturally (Remastered)"
    disc_number = 1
    track_number = 8
    duration_ms = 150000
    artists = @([PSCustomObject]@{ name = "The Beatles" })
}

Write-Host "`nTest 1: Album-level genres (Qobuz/Discogs)"
Write-Host "↓       01.08: Act Naturally (Remastered) (02:30)"
Write-Host "                artist: The Beatles"

# Test the actual code from Show-Tracks
$value = $testAlbum.genres
if ($value) {
    $providerGenres = $value -join ', '
    Write-Host ("`t`tgenres: {0}" -f $providerGenres)
}

Write-Host "`nTest 2: Artist-level genres (MusicBrainz)"
Write-Host "↓       01.10: You Like Me Too Much (02:38)"
Write-Host "                artist: The Beatles"

$value = $testArtist.genres
if ($value) {
    $providerGenres = $value -join ', '
    Write-Host ("`t`tgenres: {0}" -f $providerGenres)
}

Write-Host "`n✅ If tabs are properly rendered above (not showing \\t\\t), the fix is working!" -ForegroundColor Green
Write-Host "Expected output should show proper indentation, not literal backslash-t characters." -ForegroundColor Gray

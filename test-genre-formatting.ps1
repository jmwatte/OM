# Test to verify genre display formatting (tabs should be properly rendered)

# Ensure Show-Message helper available when running standalone
if (-not (Get-Command -Name Show-Message -ErrorAction SilentlyContinue)) {
    $p = Join-Path $PSScriptRoot 'Private\Utils\Show-Message.ps1'
    if (Test-Path $p) { . $p }
}

Show-Message -Message "`n=== Testing Genre Display Formatting ===" -ForegroundColor Cyan -Context $null

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

Show-Message -Message "`nTest 1: Album-level genres (Qobub/Discogs)" -Context $null
Show-Message -Message "↓       01.08: Act Naturally (Remastered) (02:30)" -Context $null
Show-Message -Message "                artist: The Beatles" -Context $null

# Test the actual code from Show-Tracks
$value = $testAlbum.genres
if ($value) {
    $providerGenres = $value -join ', '
    Write-Host ("`t`tgenres: {0}" -f $providerGenres)
}

Show-Message -Message "`nTest 2: Artist-level genres (MusicBrainz)" -Context $null
Show-Message -Message "↓       01.10: You Like Me Too Much (02:38)" -Context $null
Show-Message -Message "                artist: The Beatles" -Context $null

$value = $testArtist.genres
if ($value) {
    $providerGenres = $value -join ', '
    Write-Host ("`t`tgenres: {0}" -f $providerGenres)
}

Show-Message -Message "`n✅ If tabs are properly rendered above (not showing \\t\\t), the fix is working!" -ForegroundColor Green -Context $null
Show-Message -Message "Expected output should show proper indentation, not literal backslash-t characters." -ForegroundColor Gray -Context $null


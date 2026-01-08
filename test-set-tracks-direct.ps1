# Direct test of Set-Tracks function
Import-Module .\OM.psd1 -Force

# Create mock audio files from actual test folder
$testFolder = "testfiles\The Beatles\1965 - Help! (Remastered)"
$mp3Files = Get-ChildItem $testFolder -Filter *.mp3 | Sort-Object Name

Write-Host "Found $($mp3Files.Count) MP3 files" -ForegroundColor Cyan
$mp3Files | Select-Object -First 3 Name | ForEach-Object { Write-Host "  $_" }

# Create simple audio file objects
$audioFiles = @($mp3Files | ForEach-Object {
    [PSCustomObject]@{
        FilePath = $_.FullName
        Duration = 180000
        TrackNumber = 1
        DiscNumber = 1
    }
})

Write-Host "`nAudioFiles: $($audioFiles.Count) items, Type: $($audioFiles.GetType().Name)" -ForegroundColor Cyan

# Create mock Spotify tracks
$spotifyTracks = @(1..5 | ForEach-Object {
    [PSCustomObject]@{
        name = "Track $_"
        duration_ms = 180000
        track_number = $_
        disc_number = 1
    }
})

Write-Host "SpotifyTracks: $($spotifyTracks.Count) items, Type: $($spotifyTracks.GetType().Name)" -ForegroundColor Cyan

# Call the private function directly using module scope
Write-Host "`nCalling Set-Tracks with byOrder..." -ForegroundColor Yellow

$result = & (Get-Module OM) {
    param($audio, $spotify)
    Set-Tracks -AudioFiles $audio -SpotifyTracks $spotify -SortMethod 'byOrder' -Verbose
} $audioFiles $spotifyTracks

Write-Host "`nResult: $($result.Count) paired tracks" -ForegroundColor Green
$result | Select-Object -First 5 | ForEach-Object {
    $spotifyName = if ($_.SpotifyTrack) { $_.SpotifyTrack.name } else { "NULL" }
    $audioPath = if ($_.AudioFile) { [System.IO.Path]::GetFileName($_.AudioFile.FilePath) } else { "NULL" }
    Write-Host "  [$spotifyName] -> [$audioPath]"
}

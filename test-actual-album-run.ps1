# Test with the actual album that's failing
Import-Module .\OM.psd1 -Force

$albumPath = "C:\Users\jmw\Music\Adam Ant\1980 - Kings of the Wild Frontier"

if (-not (Test-Path $albumPath)) {
    Write-Host "Album path not found: $albumPath" -ForegroundColor Red
    Write-Host "Using test folder instead..."
    $albumPath = "testfiles\The Beatles\1965 - Help! (Remastered)"
}

Write-Host "Loading audio files from: $albumPath" -ForegroundColor Cyan

# Simulate what Start-OM does
$State = @{}
$State.Album = Get-Item $albumPath
$sortMethod = 'byOrder'
$skipSort = $sortMethod -eq 'byFilesystem'

# Call Reload-OMAudioFiles like Start-OM does
$State.AudioFiles = & (Get-Module OM) {
    param($path, $skip)
    Reload-OMAudioFiles -AlbumPath $path -SkipSort:$skip
} $State.Album.FullName $skipSort

Write-Host "AudioFiles loaded: $($State.AudioFiles.Count) files" -ForegroundColor Green
Write-Host "AudioFiles type: $($State.AudioFiles.GetType().Name)"
Write-Host "First 3 files:"
$State.AudioFiles | Select-Object -First 3 | ForEach-Object {
    $name = [System.IO.Path]::GetFileName($_.FilePath)
    Write-Host "  - $name (Track: $($_.TrackNumber), Disc: $($_.DiscNumber))"
}

# Create mock Spotify tracks like the real data
$tracksForAlbum = @(1..5 | ForEach-Object {
    [PSCustomObject]@{
        name = "0$($_).0$($_): Track Title $_"
        duration_ms = 180000
        track_number = $_
        disc_number = 1
    }
})

Write-Host "`nSpotifyTracks: $($tracksForAlbum.Count) tracks" -ForegroundColor Green

# Call Set-Tracks exactly like Start-OM does (line 979-987)
Write-Host "`nCalling Set-Tracks with byOrder (like Start-OM does)..." -ForegroundColor Yellow
$param = @{
    SortMethod    = $sortMethod
    AudioFiles    = @($State.AudioFiles)
    SpotifyTracks = @($tracksForAlbum)
}

Write-Host "  param.AudioFiles type: $($param.AudioFiles.GetType().Name), count: $($param.AudioFiles.Count)"
Write-Host "  param.SpotifyTracks type: $($param.SpotifyTracks.GetType().Name), count: $($param.SpotifyTracks.Count)"

$PairedTracks = & (Get-Module OM) {
    param($p)
    Set-Tracks @p -Verbose
} $param

Write-Host "`nResult: $($PairedTracks.Count) paired tracks" -ForegroundColor Magenta
$PairedTracks | Select-Object -First 5 | ForEach-Object {
    $spotifyName = if ($_.SpotifyTrack) { $_.SpotifyTrack.name } else { "❌ NULL" }
    $audioPath = if ($_.AudioFile) { [System.IO.Path]::GetFileName($_.AudioFile.FilePath) } else { "❌ NULL" }
    $conf = $_.ConfidenceLevel
    Write-Host "  $conf | [$spotifyName] -> [$audioPath]"
}

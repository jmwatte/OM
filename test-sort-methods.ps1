# Test rig to verify Set-Tracks sort methods are working correctly

Import-Module .\OM.psd1 -Force

# Dot-source private functions for testing
. .\Private\Utils\Reload-OMAudioFiles.ps1
. .\Private\Workflow\Set-Tracks.ps1

$albumPath = "C:\Users\jmw\Documents\music\Adam And The Ants\1980 - Kings Of The Wild Frontier"

if (-not (Test-Path $albumPath)) {
    Write-Host "Album path not found: $albumPath" -ForegroundColor Red
    exit 1
}

Write-Host "`n=== Testing Set-Tracks Sort Methods ===" -ForegroundColor Cyan
Write-Host "Album: $albumPath`n" -ForegroundColor Gray

# Load audio files
$audioFiles = Reload-OMAudioFiles -AlbumPath $albumPath
Write-Host "Loaded $($audioFiles.Count) audio files" -ForegroundColor Green

# Get Spotify tracks
$spotifyAlbum = Invoke-ProviderSearch -Provider Spotify -Query "Kings of the Wild Frontier" -Artist "Adam and the Ants" -Type album
if (-not $spotifyAlbum -or $spotifyAlbum.Count -eq 0) {
    Write-Host "Failed to get Spotify album" -ForegroundColor Red
    exit 1
}

$albumId = $spotifyAlbum[0].id
$spotifyTracks = Get-SpotifyAlbumTracks -AlbumId $albumId
Write-Host "Loaded $($spotifyTracks.Count) Spotify tracks`n" -ForegroundColor Green

# Test each sort method
$sortMethods = @('byOrder', 'byFilesystem', 'byTitle', 'byDuration', 'byTrackNumber')

foreach ($method in $sortMethods) {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Testing Sort Method: $method" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan
    
    $pairedTracks = Set-Tracks -SortMethod $method -AudioFiles $audioFiles -SpotifyTracks $spotifyTracks
    
    Write-Host "`nFirst 5 pairs:" -ForegroundColor Gray
    for ($i = 0; $i -lt [Math]::Min(5, $pairedTracks.Count); $i++) {
        $track = $pairedTracks[$i]
        $audioFile = if ($track.AudioFile) { Split-Path -Leaf $track.AudioFile.FilePath } else { "NO AUDIO FILE" }
        $spotifyName = $track.Name
        $match = if ($audioFile -match "^\d+\s*-\s*(.+)\.(mp3|flac)$") {
            $audioTitle = $matches[1].Trim()
            if ($spotifyName -like "*$audioTitle*" -or $audioTitle -like "*$spotifyName*") {
                "✓ MATCH"
            } else {
                "✗ MISMATCH"
            }
        } else {
            "? UNKNOWN"
        }
        
        Write-Host "  [$($i+1)] Audio: $audioFile" -ForegroundColor $(if ($match -eq "✓ MATCH") { "Green" } else { "Red" })
        Write-Host "       Spotify: $spotifyName $match" -ForegroundColor $(if ($match -eq "✓ MATCH") { "Green" } else { "Red" })
    }
    
    # Calculate match accuracy
    $correctMatches = 0
    $totalPairs = [Math]::Min($audioFiles.Count, $spotifyTracks.Count)
    
    for ($i = 0; $i -lt $totalPairs; $i++) {
        $track = $pairedTracks[$i]
        if ($track.AudioFile) {
            $audioFile = Split-Path -Leaf $track.AudioFile.FilePath
            $spotifyName = $track.Name
            
            if ($audioFile -match "^\d+\s*-\s*(.+)\.(mp3|flac)$") {
                $audioTitle = $matches[1].Trim()
                # Fuzzy match: check if titles are similar
                if ($spotifyName -like "*$audioTitle*" -or $audioTitle -like "*$spotifyName*") {
                    $correctMatches++
                }
            }
        }
    }
    
    $accuracy = if ($totalPairs -gt 0) { [Math]::Round(($correctMatches / $totalPairs) * 100, 1) } else { 0 }
    $color = if ($accuracy -ge 80) { "Green" } elseif ($accuracy -ge 50) { "Yellow" } else { "Red" }
    
    Write-Host "`n  Match Accuracy: $correctMatches / $totalPairs ($accuracy%)" -ForegroundColor $color
}

Write-Host "`n`n=== Test Complete ===" -ForegroundColor Cyan

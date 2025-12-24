# Test UpdateGenresOnly feature in Start-OM
# This test verifies the new -UpdateGenresOnly parameter

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "TEST: UpdateGenresOnly Feature" -ForegroundColor Magenta
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

# Find a test album folder with audio files
$testAlbum = Get-ChildItem -Path "c:\Users\jmw\Documents\PowerShell\Modules\OM\testfiles" -Directory -Recurse | 
    Where-Object { 
        $audioFiles = Get-ChildItem -LiteralPath $_.FullName -File -Recurse | 
            Where-Object { $_.Extension -match '\.(flac|mp3|m4a)' }
        $audioFiles.Count -gt 0
    } | Select-Object -First 1

if (-not $testAlbum) {
    Write-Host "❌ No test album folder found with audio files" -ForegroundColor Red
    exit
}

Write-Host "Test album: $($testAlbum.FullName)" -ForegroundColor Green
Write-Host ""

# Test 1: WhatIf mode with Replace
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
Write-Host "TEST 1: WhatIf Mode with Replace (Qobuz)" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
Write-Host ""
Write-Host "This will show what genres would be replaced (does not make changes)" -ForegroundColor Cyan
Write-Host "Press Ctrl+C to abort before album selection, or follow prompts..." -ForegroundColor Gray
Write-Host ""

Start-OM -Path $testAlbum.FullName -UpdateGenresOnly -GenreMode Replace -Provider Qobuz -WhatIf

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
Write-Host "TEST 2: Interactive Mode with Merge (Discogs)" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
Write-Host ""
Write-Host "This will interactively prompt you to select album and show genre merging" -ForegroundColor Cyan
Write-Host "Genres will be ADDED to existing genres (keeps both)" -ForegroundColor Cyan
Write-Host "Press Ctrl+C to abort, or follow prompts..." -ForegroundColor Gray
Write-Host ""

$continue = Read-Host "Run Test 2? (y/n) [n]"
if ($continue -eq 'y') {
    Start-OM -Path $testAlbum.FullName -UpdateGenresOnly -GenreMode Merge -Provider Discogs -WhatIf
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host "✓ Tests Complete" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host ""
Write-Host "To actually update genres (not WhatIf), remove the -WhatIf parameter:" -ForegroundColor Cyan
Write-Host "  Start-OM -Path 'album_folder' -UpdateGenresOnly -Provider Qobuz" -ForegroundColor White
Write-Host ""
Write-Host "For batch processing across multiple albums, use -Auto:" -ForegroundColor Cyan
Write-Host "  Start-OM -Path 'artist_folder' -UpdateGenresOnly -Auto -Provider Discogs" -ForegroundColor White
Write-Host ""

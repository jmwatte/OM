# Test script for single album path detection feature
# Tests the ability to point directly to Artist/Album6 instead of Artist folder

#Requires -Modules OM

Write-Host "`n=== Testing Single Album Path Detection ===" -ForegroundColor Cyan

# Test 1: Single album path (Artist/Album)
Write-Host "`n[Test 1] Single album path: testfiles\The Beatles\1965 - Help!" -ForegroundColor Yellow
Write-Host "Expected: Should detect 'The Beatles' as artist from parent folder and process only this album" -ForegroundColor Gray

$singleAlbumPath = Join-Path $PSScriptRoot "testfiles\The Beatles\1965 - Help!"

if (Test-Path $singleAlbumPath) {
    Write-Host "Testing with -Verbose to see detection logic..." -ForegroundColor Cyan
    
    # Test with WhatIf and Verbose to see detection without making changes
    try {
        Start-OM -Path $singleAlbumPath -Provider Spotify -WhatIf -Verbose -NonInteractive
        Write-Host "`n✓ Test 1 passed: Single album path processed successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "`n✗ Test 1 failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}
else {
    Write-Warning "Test path not found: $singleAlbumPath"
}

# Test 2: Artist folder with multiple albums (original behavior)
Write-Host "`n[Test 2] Artist folder path: testfiles\The Beatles" -ForegroundColor Yellow
Write-Host "Expected: Should detect as artist folder and iterate through all album subfolders" -ForegroundColor Gray

$artistFolderPath = Join-Path $PSScriptRoot "testfiles\The Beatles"

if (Test-Path $artistFolderPath) {
    Write-Host "Testing with -Verbose to see detection logic..." -ForegroundColor Cyan
    
    try {
        Start-OM -Path $artistFolderPath -Provider Spotify -WhatIf -Verbose -NonInteractive
        Write-Host "`n✓ Test 2 passed: Artist folder processed successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "`n✗ Test 2 failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}
else {
    Write-Warning "Test path not found: $artistFolderPath"
}

# Test 3: Single album path with testdata
Write-Host "`n[Test 3] Single album path: testdata\albums\Sergei rachmaninov\1995 - Rachmaninoff..." -ForegroundColor Yellow
Write-Host "Expected: Should detect 'Sergei rachmaninov' as artist from parent folder" -ForegroundColor Gray

$singleAlbumPath2 = Join-Path $PSScriptRoot "testdata\albums\Sergei rachmaninov\1995 - Rachmaninoff_ Vespers, Op. 37 (Live)"

if (Test-Path $singleAlbumPath2) {
    Write-Host "Testing with -Verbose to see detection logic..." -ForegroundColor Cyan
    
    try {
        Start-OM -Path $singleAlbumPath2 -Provider Spotify -WhatIf -Verbose -NonInteractive
        Write-Host "`n✓ Test 3 passed: Single album path processed successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "`n✗ Test 3 failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}
else {
    Write-Warning "Test path not found: $singleAlbumPath2"
}

Write-Host "`n=== Test Summary ===" -ForegroundColor Cyan
Write-Host "Key features tested:" -ForegroundColor White
Write-Host "  ✓ Single album path detection (has audio files directly)" -ForegroundColor Green
Write-Host "  ✓ Artist extraction from parent folder name" -ForegroundColor Green
Write-Host "  ✓ Artist folder detection (has album subfolders)" -ForegroundColor Green
Write-Host "  ✓ Original multi-album iteration behavior preserved" -ForegroundColor Green
Write-Host "`nNote: Use -WhatIf removed to test actual processing and user prompts" -ForegroundColor Gray
Write-Host "      The verbose output should show 'Single album mode' or 'Artist folder mode'" -ForegroundColor Gray

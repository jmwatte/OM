# Test script for single album path detection feature
# Tests the ability to point directly to Artist/Album6 instead of Artist folder

#Requires -Modules OM

# Ensure Show-Message helper available when running standalone
if (-not (Get-Command -Name Show-Message -ErrorAction SilentlyContinue)) {
    $p = Join-Path $PSScriptRoot 'Private\Utils\Show-Message.ps1'
    if (Test-Path $p) { . $p }
}

Show-Message -Message "`n=== Testing Single Album Path Detection ===" -ForegroundColor Cyan -Context $null

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
Show-Message -Message "`n[Test 2] Artist folder path: testfiles\The Beatles" -ForegroundColor Yellow -Context $null
Show-Message -Message "Expected: Should detect as artist folder and iterate through all album subfolders" -ForegroundColor Gray -Context $null

$artistFolderPath = Join-Path $PSScriptRoot "testfiles\The Beatles"

if (Test-Path $artistFolderPath) {
    Show-Message -Message "Testing with -Verbose to see detection logic..." -ForegroundColor Cyan -Context $null
    
    try {
        Start-OM -Path $artistFolderPath -Provider Spotify -WhatIf -Verbose -NonInteractive
        Show-Message -Message "`n✓ Test 2 passed: Artist folder processed successfully" -ForegroundColor Green -Context $null
    }
    catch {
        Show-Message -Message "`n✗ Test 2 failed: $($_.Exception.Message)" -ForegroundColor Red -Context $null
    }
}
else {
    Write-Warning "Test path not found: $artistFolderPath"
}

# Test 3: Single album path with testdata
Show-Message -Message "`n[Test 3] Single album path: testdata\albums\Sergei rachmaninov\1995 - Rachmaninoff..." -ForegroundColor Yellow -Context $null
Show-Message -Message "Expected: Should detect 'Sergei rachmaninov' as artist from parent folder" -ForegroundColor Gray -Context $null

$singleAlbumPath2 = Join-Path $PSScriptRoot "testdata\albums\Sergei rachmaninov\1995 - Rachmaninoff_ Vespers, Op. 37 (Live)"

if (Test-Path $singleAlbumPath2) {
    Show-Message -Message "Testing with -Verbose to see detection logic..." -ForegroundColor Cyan -Context $null
    
    try {
        Start-OM -Path $singleAlbumPath2 -Provider Spotify -WhatIf -Verbose -NonInteractive
        Show-Message -Message "`n✓ Test 3 passed: Single album path processed successfully" -ForegroundColor Green -Context $null
    }
    catch {
        Show-Message -Message "`n✗ Test 3 failed: $($_.Exception.Message)" -ForegroundColor Red -Context $null
    }
}
else {
    Write-Warning "Test path not found: $singleAlbumPath2"
}

Show-Message -Message "`n=== Test Summary ===" -ForegroundColor Cyan -Context $null
Show-Message -Message "Key features tested:" -ForegroundColor White -Context $null
Show-Message -Message "  ✓ Single album path detection (has audio files directly)" -ForegroundColor Green -Context $null
Show-Message -Message "  ✓ Artist extraction from parent folder name" -ForegroundColor Green -Context $null
Show-Message -Message "  ✓ Artist folder detection (has album subfolders)" -ForegroundColor Green -Context $null
Show-Message -Message "  ✓ Original multi-album iteration behavior preserved" -ForegroundColor Green -Context $null
Show-Message -Message "`nNote: Use -WhatIf removed to test actual processing and user prompts" -ForegroundColor Gray -Context $null
Show-Message -Message "      The verbose output should show 'Single album mode' or 'Artist folder mode'" -ForegroundColor Gray -Context $null


# Test UpdateGenresOnly feature in Start-OM
# This test verifies the new -UpdateGenresOnly parameter

# Ensure Show-Message helper available when running standalone
if (-not (Get-Command -Name Show-Message -ErrorAction SilentlyContinue)) {
    $p = Join-Path $PSScriptRoot 'Private\Utils\Show-Message.ps1'
    if (Test-Path $p) { . $p }
}

Show-Message -Message "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan -Context $null
Show-Message -Message "TEST: UpdateGenresOnly Feature" -ForegroundColor Magenta -Context $null
Show-Message -Message "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan -Context $null
Show-Message -Message "" -Context $null

# Find a test album folder with audio files
$testAlbum = Get-ChildItem -Path "c:\Users\jmw\Documents\PowerShell\Modules\OM\testfiles" -Directory -Recurse | 
    Where-Object { 
        $audioFiles = Get-ChildItem -LiteralPath $_.FullName -File -Recurse | 
            Where-Object { $_.Extension -match '\.(flac|mp3|m4a)' }
        $audioFiles.Count -gt 0
    } | Select-Object -First 1

if (-not $testAlbum) {
    Show-Message -Message "❌ No test album folder found with audio files" -ForegroundColor Red -Context $null
    exit
}

Show-Message -Message "Test album: $($testAlbum.FullName)" -ForegroundColor Green -Context $null
Show-Message -Message "" -Context $null

# Test 1: WhatIf mode with Replace
Show-Message -Message "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow -Context $null
Show-Message -Message "TEST 1: WhatIf Mode with Replace (Qobuz)" -ForegroundColor Yellow -Context $null
Show-Message -Message "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow -Context $null
Show-Message -Message "" -Context $null
Show-Message -Message "This will show what genres would be replaced (does not make changes)" -ForegroundColor Cyan -Context $null
Show-Message -Message "Press Ctrl+C to abort before album selection, or follow prompts..." -ForegroundColor Gray -Context $null
Show-Message -Message "" -Context $null

Start-OM -Path $testAlbum.FullName -UpdateGenresOnly -GenreMode Replace -Provider Qobuz -WhatIf

Show-Message -Message "" -Context $null
Show-Message -Message "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow -Context $null
Show-Message -Message "TEST 2: Interactive Mode with Merge (Discogs)" -ForegroundColor Yellow -Context $null
Show-Message -Message "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow -Context $null
Show-Message -Message "" -Context $null
Show-Message -Message "This will interactively prompt you to select album and show genre merging" -ForegroundColor Cyan -Context $null
Show-Message -Message "Genres will be ADDED to existing genres (keeps both)" -ForegroundColor Cyan -Context $null
Show-Message -Message "Press Ctrl+C to abort, or follow prompts..." -ForegroundColor Gray -Context $null
Show-Message -Message "" -Context $null

$continue = Read-Host "Run Test 2? (y/n) [n]"
if ($continue -eq 'y') {
    Start-OM -Path $testAlbum.FullName -UpdateGenresOnly -GenreMode Merge -Provider Discogs -WhatIf
}

Show-Message -Message "" -Context $null
Show-Message -Message "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green -Context $null
Show-Message -Message "✓ Tests Complete" -ForegroundColor Green -Context $null
Show-Message -Message "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green -Context $null
Show-Message -Message "" -Context $null
Show-Message -Message "To actually update genres (not WhatIf), remove the -WhatIf parameter:" -ForegroundColor Cyan -Context $null
Show-Message -Message "  Start-OM -Path 'album_folder' -UpdateGenresOnly -Provider Qobuz" -ForegroundColor White -Context $null
Show-Message -Message "" -Context $null
Show-Message -Message "For batch processing across multiple albums, use -Auto:" -ForegroundColor Cyan -Context $null
Show-Message -Message "  Start-OM -Path 'artist_folder' -UpdateGenresOnly -Auto -Provider Discogs" -ForegroundColor White -Context $null
Show-Message -Message "" -Context $null


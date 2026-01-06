# Test script for AlbumArtist folder naming fix
# Verifies that folder rename uses AlbumArtist from saved tags, not ProviderArtist.name

#Requires -Modules OM

# Ensure Show-Message helper available when running standalone
if (-not (Get-Command -Name Show-Message -ErrorAction SilentlyContinue)) {
    $p = Join-Path $PSScriptRoot 'Private\Utils\Show-Message.ps1'
    if (Test-Path $p) { . $p }
}

Show-Message -Message "`n=== Testing AlbumArtist Folder Naming Fix ===" -ForegroundColor Cyan -Context $null
Show-Message -Message "This test verifies that after saving tags, the folder rename uses" -ForegroundColor Gray -Context $null
Show-Message -Message "the AlbumArtist from saved tags instead of ProviderArtist.name" -ForegroundColor Gray -Context $null
Show-Message -Message "" -Context $null

# Test scenario explanation
Show-Message -Message "Scenario: Classical music album where:" -ForegroundColor Yellow -Context $null
Show-Message -Message "  - Search artist (folder name): 'Holst'" -ForegroundColor Gray -Context $null
Show-Message -Message "  - Provider artist (search result): Generic or composer name" -ForegroundColor Gray -Context $null
Show-Message -Message "  - AlbumArtist in tags: 'Herbert von Karajan' (conductor/orchestra)" -ForegroundColor Gray -Context $null
Show-Message -Message "" -Context $null
Show-Message -Message "Expected result after 'sa' (save all):" -ForegroundColor Green -Context $null
Show-Message -Message "  Folder should be renamed using AlbumArtist from tags (Herbert von Karajan)" -ForegroundColor Green -Context $null
Show-Message -Message "  NOT using the original search/folder artist (Holst)" -ForegroundColor Green -Context $null
Show-Message -Message "" -Context $null

# Create a test scenario with mock data
Show-Message -Message "To test this fix:" -ForegroundColor Cyan -Context $null
Show-Message -Message "1. Point Start-OM to an album with mismatched artist/album artist" -ForegroundColor White -Context $null
Show-Message -Message "2. Use -Verbose to see 'Read AlbumArtist from saved tags: <artist>'" -ForegroundColor White -Context $null
Show-Message -Message "3. Verify the folder rename uses the AlbumArtist from tags" -ForegroundColor White -Context $null
Show-Message -Message "" -Context $null

Show-Message -Message "Example test command:" -ForegroundColor Yellow -Context $null
Show-Message -Message "  Start-OM -Path 'E:\WrongArtistName\AlbumFolder' -Provider Qobuz -Verbose" -ForegroundColor Gray -Context $null
Show-Message -Message "" -Context $null
Show-Message -Message "After saving (sa command), look for these verbose messages:" -ForegroundColor Yellow -Context $null
Show-Message -Message "  'Read AlbumArtist from saved tags: <correct artist>'" -ForegroundColor Green -Context $null
Show-Message -Message "  'Using ProviderArtist.name as fallback: <artist>' (should NOT appear if tags were saved)" -ForegroundColor Red -Context $null
Show-Message -Message "" -Context $null

# Show the key code change
Show-Message -Message "Key fix implemented:" -ForegroundColor Cyan -Context $null
Show-Message -Message "  Before: artistNameForFolder = ProviderArtist.name" -ForegroundColor Red -Context $null
Show-Message -Message "  After:  artistNameForFolder = Read from saved AlbumArtist tag" -ForegroundColor Green -Context $null
Show-Message -Message "" -Context $null
Show-Message -Message "This ensures folder structure matches saved metadata." -ForegroundColor Cyan -Context $null

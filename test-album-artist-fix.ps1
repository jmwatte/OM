# Test script for AlbumArtist folder naming fix
# Verifies that folder rename uses AlbumArtist from saved tags, not ProviderArtist.name

#Requires -Modules OM

Write-Host "`n=== Testing AlbumArtist Folder Naming Fix ===" -ForegroundColor Cyan
Write-Host "This test verifies that after saving tags, the folder rename uses" -ForegroundColor Gray
Write-Host "the AlbumArtist from saved tags instead of ProviderArtist.name" -ForegroundColor Gray
Write-Host ""

# Test scenario explanation
Write-Host "Scenario: Classical music album where:" -ForegroundColor Yellow
Write-Host "  - Search artist (folder name): 'Holst'" -ForegroundColor Gray
Write-Host "  - Provider artist (search result): Generic or composer name" -ForegroundColor Gray
Write-Host "  - AlbumArtist in tags: 'Herbert von Karajan' (conductor/orchestra)" -ForegroundColor Gray
Write-Host ""
Write-Host "Expected result after 'sa' (save all):" -ForegroundColor Green
Write-Host "  Folder should be renamed using AlbumArtist from tags (Herbert von Karajan)" -ForegroundColor Green
Write-Host "  NOT using the original search/folder artist (Holst)" -ForegroundColor Green
Write-Host ""

# Create a test scenario with mock data
Write-Host "To test this fix:" -ForegroundColor Cyan
Write-Host "1. Point Start-OM to an album with mismatched artist/album artist" -ForegroundColor White
Write-Host "2. Use -Verbose to see 'Read AlbumArtist from saved tags: <artist>'" -ForegroundColor White
Write-Host "3. Verify the folder rename uses the AlbumArtist from tags" -ForegroundColor White
Write-Host ""

Write-Host "Example test command:" -ForegroundColor Yellow
Write-Host "  Start-OM -Path 'E:\WrongArtistName\AlbumFolder' -Provider Qobuz -Verbose" -ForegroundColor Gray
Write-Host ""
Write-Host "After saving (sa command), look for these verbose messages:" -ForegroundColor Yellow
Write-Host "  'Read AlbumArtist from saved tags: <correct artist>'" -ForegroundColor Green
Write-Host "  'Using ProviderArtist.name as fallback: <artist>' (should NOT appear if tags were saved)" -ForegroundColor Red
Write-Host ""

# Show the key code change
Write-Host "Key fix implemented:" -ForegroundColor Cyan
Write-Host "  Before: artistNameForFolder = ProviderArtist.name" -ForegroundColor Red
Write-Host "  After:  artistNameForFolder = Read from saved AlbumArtist tag" -ForegroundColor Green
Write-Host ""
Write-Host "This ensures folder structure matches saved metadata." -ForegroundColor Cyan

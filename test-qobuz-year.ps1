# Test script to debug Qobuz year extraction
Import-Module "C:\Users\jmw\Documents\PowerShell\Modules\OM\OM.psd1" -Force

$url = "https://www.qobuz.com/us-en/album/bach-goldberg-variations-johann-sebastian-bach-dmitry-sitkovetsky-nes-chamber-orchestra/0075597934168"

Write-Host "Testing Qobuz year extraction..." -ForegroundColor Cyan
Write-Host "URL: $url`n" -ForegroundColor Gray

# Dot-source the function directly
. "C:\Users\jmw\Documents\PowerShell\Modules\OM\Private\Providers\Qobuz\Get-QAlbumTracks.ps1"

# Call it with verbose
$tracks = Get-QAlbumTracks -Id $url -Verbose

Write-Host "`n=== RESULTS ===" -ForegroundColor Cyan
Write-Host "Total tracks returned: $($tracks.Count)" -ForegroundColor Yellow
Write-Host "`nFirst track properties:" -ForegroundColor Yellow
$tracks[0] | Select-Object id, name, release_date, album_name, album_artist | Format-List

Write-Host "`nChecking release_date across all tracks:" -ForegroundColor Yellow
$tracks | Select-Object -First 5 name, release_date | Format-Table -AutoSize

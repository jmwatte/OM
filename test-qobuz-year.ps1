# Test script to debug Qobuz year extraction
Import-Module "C:\Users\jmw\Documents\PowerShell\Modules\OM\OM.psd1" -Force

# Ensure Show-Message helper available when running standalone
if (-not (Get-Command -Name Show-Message -ErrorAction SilentlyContinue)) {
    $p = Join-Path $PSScriptRoot 'Private\Utils\Show-Message.ps1'
    if (Test-Path $p) { . $p }
}

$url = "https://www.qobuz.com/us-en/album/bach-goldberg-variations-johann-sebastian-bach-dmitry-sitkovetsky-nes-chamber-orchestra/0075597934168"

Show-Message -Message "Testing Qobuz year extraction..." -ForegroundColor Cyan -Context $null
Show-Message -Message "URL: $url`n" -ForegroundColor Gray -Context $null

# Dot-source the function directly
. "C:\Users\jmw\Documents\PowerShell\Modules\OM\Private\Providers\Qobuz\Get-QAlbumTracks.ps1"

# Call it with verbose
$tracks = Get-QAlbumTracks -Id $url -Verbose

Show-Message -Message "`n=== RESULTS ===" -ForegroundColor Cyan -Context $null
Show-Message -Message "Total tracks returned: $($tracks.Count)" -ForegroundColor Yellow -Context $null
Show-Message -Message "`nFirst track properties:" -ForegroundColor Yellow -Context $null
$tracks[0] | Select-Object id, name, release_date, album_name, album_artist | Format-List

Show-Message -Message "`nChecking release_date across all tracks:" -ForegroundColor Yellow -Context $null
$tracks | Select-Object -First 5 name, release_date | Format-Table -AutoSize

# Simpler test: Run Start-OM and trace Set-Tracks calls

$albumPath = "C:\Users\jmw\Documents\music\Adam And The Ants\1980 - Kings Of The Wild Frontier"

if (-not (Test-Path $albumPath)) {
    Write-Host "Album path not found: $albumPath" -ForegroundColor Red
    exit 1
}

Write-Host "`n=== Testing Sort Methods with Start-OM ===" -ForegroundColor Cyan
Write-Host "We'll run Start-OM and manually test each sort method" -ForegroundColor Yellow
Write-Host "Commands to test: o, l, d, t, f, h" -ForegroundColor Yellow
Write-Host "`nPress Enter to start..." -ForegroundColor Gray
Read-Host

Import-Module .\OM.psd1 -Force -Verbose:$false

# Run Start-OM with WhatIf and let user manually test sort methods
Start-OM -Path $albumPath -Provider Spotify -WhatIf

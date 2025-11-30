# Test script to check file creation times and other metadata
$testPath = "C:\Users\jmw\Documents\PowerShell\Modules\OM\testfiles\Ophelie Gaillard\2011 - Bach Cello Suites"

Write-Host "`n=== Checking file metadata ===" -ForegroundColor Cyan

$files = Get-ChildItem -LiteralPath $testPath -File | 
    Where-Object { $_.Extension -match '\.flac' } |
    Select-Object Name, CreationTime, LastWriteTime |
    Sort-Object CreationTime

Write-Host "`nFiles sorted by CreationTime:" -ForegroundColor Yellow
$files | Format-Table -AutoSize

Write-Host "`nFirst file by creation time: $($files[0].Name)" -ForegroundColor Green
Write-Host "First file alphabetically: 00 - Suite I in G-Dur, BWV 1007 - Allemande.flac" -ForegroundColor Magenta

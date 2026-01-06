# Test script to check file creation times and other metadata
$testPath = "C:\Users\jmw\Documents\PowerShell\Modules\OM\testfiles\Ophelie Gaillard\2011 - Bach Cello Suites"

# Ensure Show-Message helper available when running standalone
if (-not (Get-Command -Name Show-Message -ErrorAction SilentlyContinue)) {
    $p = Join-Path $PSScriptRoot 'Private\Utils\Show-Message.ps1'
    if (Test-Path $p) { . $p }
}

Show-Message -Message "`n=== Checking file metadata ===" -ForegroundColor Cyan -Context $null

$files = Get-ChildItem -LiteralPath $testPath -File | 
    Where-Object { $_.Extension -match '\.flac' } |
    Select-Object Name, CreationTime, LastWriteTime |
    Sort-Object CreationTime

Show-Message -Message "`nFiles sorted by CreationTime:" -ForegroundColor Yellow -Context $null
$files | Format-Table -AutoSize

Show-Message -Message "`nFirst file by creation time: $($files[0].Name)" -ForegroundColor Green -Context $null
Show-Message -Message "First file alphabetically: 00 - Suite I in G-Dur, BWV 1007 - Allemande.flac" -ForegroundColor Magenta -Context $null

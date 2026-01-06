# Test script to verify filesystem ordering behavior
$testPath = "C:\Users\jmw\Documents\PowerShell\Modules\OM\testfiles\Ophelie Gaillard\2011 - Bach Cello Suites"

# Ensure Show-Message helper available when running standalone
if (-not (Get-Command -Name Show-Message -ErrorAction SilentlyContinue)) {
    $p = Join-Path $PSScriptRoot 'Private\Utils\Show-Message.ps1'
    if (Test-Path $p) { . $p }
}

Show-Message -Message "`n=== Testing Get-ChildItem order ===" -ForegroundColor Cyan -Context $null
Show-Message -Message "Path: $testPath`n" -ForegroundColor Gray -Context $null

# Get files as they come from filesystem
$files = Get-ChildItem -LiteralPath $testPath -File | 
    Where-Object { $_.Extension -match '\.(mp3|flac|wav|m4a|aac|ogg|ape)' }

Show-Message -Message "Files from Get-ChildItem (raw order):" -ForegroundColor Yellow -Context $null
$files | ForEach-Object { $i = 0 } { 
    $i++
    Show-Message -Message "  [$i] $($_.Name)" -ForegroundColor White -Context $null
}

# Now sort them alphabetically (what byOrder does)
Show-Message -Message "`nFiles after Sort-Object with regex padding:" -ForegroundColor Yellow -Context $null
$sortedFiles = $files | Sort-Object { [regex]::Replace($_.Name, '(\d+)', { $args[0].Value.PadLeft(10, '0') }) }
$sortedFiles | ForEach-Object { $i = 0 } { 
    $i++
    Show-Message -Message "  [$i] $($_.Name)" -ForegroundColor White -Context $null
}

# Compare
Show-Message -Message "`n=== Analysis ===" -ForegroundColor Cyan -Context $null
$firstRaw = $files[0].Name
$firstSorted = $sortedFiles[0].Name

if ($firstRaw -eq $firstSorted) {
    Show-Message -Message "✓ Order is IDENTICAL - Get-ChildItem already returns alphabetical order" -ForegroundColor Green -Context $null
} else {
    Show-Message -Message "✗ Order is DIFFERENT" -ForegroundColor Red -Context $null
    Show-Message -Message "  Raw first file:    $firstRaw" -ForegroundColor Magenta -Context $null
    Show-Message -Message "  Sorted first file: $firstSorted" -ForegroundColor Magenta -Context $null
}


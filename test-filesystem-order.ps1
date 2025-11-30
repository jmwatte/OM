# Test script to verify filesystem ordering behavior
$testPath = "C:\Users\jmw\Documents\PowerShell\Modules\OM\testfiles\Ophelie Gaillard\2011 - Bach Cello Suites"

Write-Host "`n=== Testing Get-ChildItem order ===" -ForegroundColor Cyan
Write-Host "Path: $testPath`n" -ForegroundColor Gray

# Get files as they come from filesystem
$files = Get-ChildItem -LiteralPath $testPath -File | 
    Where-Object { $_.Extension -match '\.(mp3|flac|wav|m4a|aac|ogg|ape)' }

Write-Host "Files from Get-ChildItem (raw order):" -ForegroundColor Yellow
$files | ForEach-Object { $i = 0 } { 
    $i++
    Write-Host "  [$i] $($_.Name)" -ForegroundColor White
}

# Now sort them alphabetically (what byOrder does)
Write-Host "`nFiles after Sort-Object with regex padding:" -ForegroundColor Yellow
$sortedFiles = $files | Sort-Object { [regex]::Replace($_.Name, '(\d+)', { $args[0].Value.PadLeft(10, '0') }) }
$sortedFiles | ForEach-Object { $i = 0 } { 
    $i++
    Write-Host "  [$i] $($_.Name)" -ForegroundColor White
}

# Compare
Write-Host "`n=== Analysis ===" -ForegroundColor Cyan
$firstRaw = $files[0].Name
$firstSorted = $sortedFiles[0].Name

if ($firstRaw -eq $firstSorted) {
    Write-Host "✓ Order is IDENTICAL - Get-ChildItem already returns alphabetical order" -ForegroundColor Green
} else {
    Write-Host "✗ Order is DIFFERENT" -ForegroundColor Red
    Write-Host "  Raw first file:    $firstRaw" -ForegroundColor Magenta
    Write-Host "  Sorted first file: $firstSorted" -ForegroundColor Magenta
}

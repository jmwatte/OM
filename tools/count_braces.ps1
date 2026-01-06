$s = Get-Content -Raw 'Public/Start-OM.ps1'
$open = ($s.ToCharArray() | Where-Object { $_ -eq '{' }).Count
$close = ($s.ToCharArray() | Where-Object { $_ -eq '}' }).Count
Write-Output "{0} opens, {1} closes" -f $open, $close

# Show first occurrence where counts diverge
$depth = 0
$index = 0
foreach ($ch in $s.ToCharArray()) {
    if ($ch -eq '{') { $depth++ }
    elseif ($ch -eq '}') { $depth-- }
    if ($depth -lt 0) { 
        # compute line number
        $prefix = $s.Substring(0, $index)
        $lineNum = ($prefix.ToCharArray() | Where-Object { $_ -eq "`n" }).Count + 1
        Write-Output "Mismatch: more closing braces at index $index (approx line $lineNum)"
        # Dump surrounding lines for context
        $lines = $s -split "`n"
        $start = [Math]::Max(0, $lineNum - 6)
        $end = [Math]::Min($lines.Count-1, $lineNum + 4)
        Write-Output "Context lines ($start..$end):"
        for ($i = $start; $i -le $end; $i++) { Write-Output "$($i+1): $($lines[$i])" }
        # Also print raw character context
        $charContext = $s.Substring([Math]::Max(0, $index - 100), [Math]::Min(200, $s.Length - [Math]::Max(0, $index - 100)))
        Write-Output "Char context (around index $index):"
        Write-Output $charContext
        break 
    }
    $index++
}
if ($depth -gt 0) { Write-Output "Mismatch: unclosed { $depth } brace(s)" }
else { Write-Output "Braces check complete" }
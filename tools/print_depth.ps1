$s = Get-Content -Raw 'Public/Start-OM.ps1'
$lines = $s -split "`n"
$depth = 0
for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    foreach ($ch in $line.ToCharArray()) {
        if ($ch -eq '{') { $depth++ }
        elseif ($ch -eq '}') { $depth-- }
    }
    if ($i -ge 3300) { Write-Output ("{0,5}: {1,3} {2}" -f ($i+1), $depth, $line.Trim()) }
}
Write-Output "Final depth: $depth"
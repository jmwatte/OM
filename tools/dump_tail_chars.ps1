$s = Get-Content -Raw 'Public/Start-OM.ps1'
$len = $s.Length
Write-Output "Length: $len"
$start = [Math]::Max(0, $len-200)
for ($i = $start; $i -lt $len; $i++) {
    $c = $s[$i]
    Write-Output ("{0,4}: '{1}' (0x{2:X2})" -f ($i - $start), $c, [int][char]$c)
}
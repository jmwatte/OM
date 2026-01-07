$lines = Get-Content (Join-Path $PSScriptRoot '..\Public\Start-OM.ps1')
$balance = 0
for ($i=0; $i -lt $lines.Length; $i++) {
    $l = $lines[$i]
    $opens = ($l.ToCharArray() | Where-Object { $_ -eq '{' }).Count
    $closes = ($l.ToCharArray() | Where-Object { $_ -eq '}' }).Count
    $balance += ($opens - $closes)
    if ($balance -lt 0) { Write-Output "Negative balance at line $($i+1): $l"; break }
}
Write-Output "Final balance: $balance"
if ($balance -gt 0) {
    # find last lines where balance increases
    $balance = 0
    for ($i=0; $i -lt $lines.Length; $i++) {
        $l = $lines[$i]
        $opens = ($l.ToCharArray() | Where-Object { $_ -eq '{' }).Count
        $closes = ($l.ToCharArray() | Where-Object { $_ -eq '}' }).Count
        $prev = $balance
        $balance += ($opens - $closes)
        if ($prev -lt $balance) {
            Write-Output "Balance increased to $balance at line $($i+1): $l"
        }
    }
}
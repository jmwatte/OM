$file = Join-Path $PSScriptRoot '..\Public\Start-OM.ps1'
$lines = Get-Content -LiteralPath $file
$stack = @()
for ($i=0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    for ($j = 0; $j -lt $line.Length; $j++) {
        $c = $line[$j]
        if ($c -eq '{') {
            $context = if ($j -gt 40) { $line.Substring([Math]::Max(0,$j-40),40).Trim() } else { $line.Substring(0,$j).Trim() }
            $stack += [pscustomobject]@{ Char = '{'; Line = $i + 1; Column = $j + 1; Text = $line.Trim(); Context = $context }
        } elseif ($c -eq '}') {
            if ($stack.Count -gt 0) {
                $stack = $stack[0..($stack.Count - 2)]
            } else {
                Write-Output "Unmatched closing brace at line $($i+1)"
            }
        }
    }
}
if ($stack.Count -gt 0) {
    Write-Output "Unmatched opening braces: $($stack.Count)"
    $stack | ForEach-Object { Write-Output "Line: $($_.Line) Col: $($_.Column) Text: $($_.Text)" }
} else {
    Write-Output "All braces matched"
}
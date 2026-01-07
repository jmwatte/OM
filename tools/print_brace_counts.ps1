$f = Join-Path $PSScriptRoot '..\Public\Start-OM.ps1'
$lines = Get-Content -LiteralPath $f
$openCount = 0; $closeCount = 0
for ($i=0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    $openCount += ([regex]::Matches($line,'\{')).Count
    $closeCount += ([regex]::Matches($line,'\}')).Count
    if ($line -match '}') { Write-Output "Line $($i+1): $line" }
}
Write-Output "Open braces: $openCount"
Write-Output "Close braces: $closeCount"
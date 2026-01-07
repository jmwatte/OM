param(
    [Parameter(Mandatory=$true)]
    [int]$startLine
)
$file = Join-Path $PSScriptRoot '..\Public\Start-OM.ps1'
$lines = Get-Content -LiteralPath $file
$depth = 0
$foundStart = $false
for ($i = 0; $i -lt $lines.Count; $i++) {
    $lineIndex = $i + 1
    $line = $lines[$i]
    if ($lineIndex -eq $startLine) {
        # find first '{' in this line
        $firstIdx = $line.IndexOf('{')
        if ($firstIdx -ge 0) { $foundStart = $true; $depth = 1 }
        else { Write-Output "No opening brace on start line"; break }
        continue
    }
    if (-not $foundStart) { continue }
    for ($j = 0; $j -lt $line.Length; $j++) {
        $c = $line[$j]
        if ($c -eq '{') { $depth++ }
        elseif ($c -eq '}') { $depth-- }
    }
    if ($depth -eq 0) { Write-Output "Matching closing brace found at line $lineIndex"; break }
}
if ($depth -ne 0) { Write-Output "Did not find matching closing brace; depth=$depth at EOF" }
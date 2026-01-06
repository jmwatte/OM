$lines = Get-Content -Path 'Public/Start-OM.ps1'
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '\btry\s*\{') {
        $hasCatch = $false
        $snippet = $lines[$i]
        for ($j = $i+1; $j -lt [Math]::Min($lines.Count, $i+80); $j++) {
            $snippet += "`n" + $lines[$j]
            if ($lines[$j] -match '\bcatch\b') { $hasCatch = $true; break }
            if ($lines[$j] -match '\bfinally\b') { $hasCatch = $true; break }
        }
        if (-not $hasCatch) { Write-Output "Try at line $(($i+1)) seems to have no catch/finally in next 80 lines"; Write-Output "Snippet:"; Write-Output $snippet; Write-Output '----' }
    }
}

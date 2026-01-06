Import-Module PSScriptAnalyzer -ErrorAction Stop

$issues = Invoke-ScriptAnalyzer -Path . -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.RuleName -eq 'PSUseBOMForUnicodeEncodedFile' } |
    Select-Object -Unique ScriptName

if (-not $issues) {
    Write-Output 'No PSUseBOMForUnicodeEncodedFile issues found.'
    exit 0
}

$results = [System.Collections.Generic.List[psobject]]::new()
foreach ($issue in $issues) {
    $f = $issue.ScriptName
    try {
        # Try resolving the path directly; if that fails attempt a recursive search
        try {
            $p = (Resolve-Path -LiteralPath $f -ErrorAction Stop).Path
        }
        catch {
            $matches = Get-ChildItem -Path . -Filter $f -Recurse -File -ErrorAction SilentlyContinue
            if ($matches -and $matches.Count -gt 0) {
                $p = $matches[0].FullName
            }
            else {
                throw $_
            }
        }

        Write-Output "Converting: $p"
        $content = Get-Content -Raw -LiteralPath $p -ErrorAction Stop
        Set-Content -LiteralPath $p -Value $content -Encoding utf8BOM -Force
        $results.Add([PSCustomObject]@{ File = $p; Status = 'OK' }) | Out-Null
    }
    catch {
        $results.Add([PSCustomObject]@{ File = $f; Status = 'FAILED'; Error = $_.Exception.Message }) | Out-Null
        Write-Output "FAILED: $f => $($_.Exception.Message)"
    }
}

Write-Output "Done. Summary:"
$results | Format-Table -AutoSize

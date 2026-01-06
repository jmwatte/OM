Import-Module PSScriptAnalyzer -ErrorAction Stop
$issues = Invoke-ScriptAnalyzer -Path . -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.RuleName -eq 'PSUseBOMForUnicodeEncodedFile' }
if ($issues -and $issues.Count -gt 0) {
    $issues | Select-Object ScriptName, Message | Sort-Object ScriptName | Format-Table -AutoSize
}
else {
    Write-Output 'No PSUseBOMForUnicodeEncodedFile warnings remain.'
}
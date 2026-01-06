$s = Get-Content -Raw 'Public/Start-OM.ps1'
$tryCount = [regex]::Matches($s, '\btry\b').Count
$catchCount = [regex]::Matches($s, '\bcatch\b').Count
Write-Output "try: $tryCount, catch: $catchCount"
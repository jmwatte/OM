try {
  $s = Get-Content -Raw '.\Public\Start-OM.ps1' -ErrorAction Stop
  [scriptblock]::Create($s) | Out-Null
  Write-Host 'PARSE_OK'
} catch {
  Write-Host 'PARSE_ERROR'
  if ($null -ne $_.Exception) { Write-Host 'Exception.Message:'; Write-Host $_.Exception.Message }
  if ($null -ne $_.InvocationInfo) { Write-Host 'PositionMessage:'; Write-Host $_.InvocationInfo.PositionMessage }
  if ($null -ne $_.ScriptStackTrace) { Write-Host 'ScriptStackTrace:'; Write-Host $_.ScriptStackTrace }
  exit 2
}

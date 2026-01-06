try {
  $s = Get-Content -Raw '.\Public\Start-OM.ps1' -ErrorAction Stop
  [scriptblock]::Create($s) | Out-Null
  Write-Output 'PARSE_OK'
} catch {
  Write-Error 'PARSE_ERROR'
  if ($null -ne $_.Exception) { Write-Error "Exception.Message: $($_.Exception.Message)" }
  if ($null -ne $_.InvocationInfo) { Write-Error "PositionMessage: $($_.InvocationInfo.PositionMessage)" }
  if ($null -ne $_.ScriptStackTrace) { Write-Error "ScriptStackTrace: $($_.ScriptStackTrace)" }
  exit 2
}

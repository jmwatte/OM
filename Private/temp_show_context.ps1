. 'Private/Utils/New-OMContext.ps1'
$display = { param($msg,$color) return "DISPLAY:$msg" }
$ctx = New-OMContext -DisplayWriter $display
$res = & $ctx.DisplayWriter 'hi','Yellow'
Write-Output "RES=>'$res'"
Write-Output "Type: $($ctx.DisplayWriter.GetType().FullName)"
Write-Output "ScriptBlock AST: $($ctx.DisplayWriter.Ast)"

. .\Public\Get-OMConfig.ps1
. .\Private\Get-IfExists.ps1
$x = Get-OMConfig -Provider Qobuz
Write-Host 'TYPE:' $x.GetType().FullName
foreach ($p in $x.PSObject.Properties) { Write-Host $p.Name ':' $p.Value }
Write-Host 'Locale via Get-IfExists:'
Write-Host (Get-IfExists -target $x -path 'Locale')

$base = (Get-Location).Path
$p = Join-Path $base 'Private\Utils\Reload-OMAudioFiles.ps1'
Write-Output "p=$p"
Write-Output (Test-Path $p)
Get-Item $p | Format-List -Property FullName
. $p
Write-Output "sourced OK"
$base = (Get-Location).Path
$p = Join-Path $base 'Private\Utils\Reload-OMAudioFiles.ps1'
Write-Host "p=$p"
Write-Host (Test-Path $p)
Get-Item $p | Format-List -Property FullName
. $p
Write-Host "sourced OK"
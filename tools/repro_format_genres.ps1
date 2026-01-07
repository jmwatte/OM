Import-Module .\OM.psm1 -Force
. .\Private\Utils\Show-Message.ps1

$input = [PSCustomObject]@{ Path='fakepath'; Genres=@('UnmappedGenre') }
$col = @()
$ctx=[PSCustomObject]@{ DisplayWriter = { param($m,$c,$n) $col += $m } }

try {
    Format-Genres -InputObject $input -NonInteractive -Context $ctx -PassThru:$false -Force:$true
    Write-Output 'OK'
}
catch {
    Write-Error $_
}

Write-Output "Captured messages:"
$col | ForEach-Object { Write-Output "MSG: $_" }

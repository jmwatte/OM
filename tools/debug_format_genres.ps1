Import-Module Pester -Force
Import-Module .\OM.psm1 -Force
. .\Private\Utils\Show-Message.ps1

Mock -CommandName Get-OMConfig -ModuleName OM -MockWith { @{ Genres = @{ AllowedGenreNames = @('Pop'); GenreMappings = @{}; GarbageGenres = @() } } }
$input = [PSCustomObject]@{ Path = 'fakepath'; Genres = @('UnmappedGenre') }
$script:msgs = New-Object System.Collections.Concurrent.ConcurrentBag[System.String]
Mock -CommandName Show-Message -ModuleName OM -MockWith { param($m) $script:msgs.Add($m) }
$ctx = [PSCustomObject]@{ DisplayWriter = { param($msg,$color,$no) $script:msgs.Add("DW: $msg") } }

Format-Genres -InputObject $input -NonInteractive -Context $ctx -PassThru:$false -Force:$true

Write-Output "COUNT: $($script:msgs.Count)"
$script:msgs | Select-Object -First 20 | ForEach-Object { Write-Output "MSG: '$_'" }

# Reproduce failing Get-OMAudioFile invocation under Trace-Command
$pCandidates = @()
if ($PSScriptRoot) { $pCandidates += Join-Path $PSScriptRoot '..\Private\Utils\Get-OMAudioFile.ps1' }
if ($MyInvocation.MyCommand.Path) { $pCandidates += Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\Private\Utils\Get-OMAudioFile.ps1' }
$pCandidates += Join-Path (Get-Location).Path 'Private\Utils\Get-OMAudioFile.ps1'
$p = $pCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $p) { Throw "Helper not found at runtime: $p" }
. $p

# Stub Get-OMTagFile as test does
function Get-OMTagFile { param($FilePath) [PSCustomObject]@{ Tag = [PSCustomObject]@{ Disc = 1; Track = 1; Title = 'Test'; Composers = @('C1'); Performers = @('A1') }; Properties = [PSCustomObject]@{ Duration = [TimeSpan]::FromMilliseconds(1234) } } }

$tmp = Join-Path $env:TEMP ("om_audiofile_test_$([guid]::NewGuid().ToString())")
New-Item -Path $tmp -ItemType Directory -Force | Out-Null
$f = Join-Path $tmp '1 - Test.mp3'
New-Item -Path $f -ItemType File -Force | Out-Null

# Run under Trace-Command
Trace-Command -Name ParameterBinding,CommandInvocation -Expression { Get-OMAudioFile -Path $tmp -Trace } -PSHost

Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
Write-Output Done
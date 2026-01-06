Write-Output 'Manual run start'
$tmp=Join-Path $env:TEMP "om_reload_manual_$([guid]::NewGuid())"
New-Item -Path $tmp -ItemType Directory -Force | Out-Null
$f=Join-Path $tmp '1 - Test.mp3'
New-Item -Path $f -ItemType File -Force | Out-Null
$scriptBase = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Output 'Script base:' $scriptBase
$helperPath = Join-Path $scriptBase '..\Private\Utils\Reload-OMAudioFiles.ps1'
$helperPath = Resolve-Path -Path $helperPath -ErrorAction SilentlyContinue
Write-Output 'helperPath:' $helperPath
if ($helperPath) { . $helperPath } else { Write-Output 'helper not found' }
function Get-OMTagFile { param($FilePath) [PSCustomObject]@{ Tag = [PSCustomObject]@{ Disc = 1; Track = 1; Title = 'Test'; Composers=@('C1'); Performers=@('A1') }; Properties = [PSCustomObject]@{ Duration = [TimeSpan]::FromMilliseconds(1234) } } }
Write-Output 'Defining Get-OMTagFile mock'
function Get-OMTagFile { param($FilePath) [PSCustomObject]@{ Tag = [PSCustomObject]@{ Disc = 1; Track = 1; Title = 'Test'; Composers=@('C1'); Performers=@('A1') }; Properties = [PSCustomObject]@{ Duration = [TimeSpan]::FromMilliseconds(1234) } } }
Write-Output 'Listing files found by Get-ChildItem:'
Get-ChildItem -LiteralPath $tmp -File -Recurse | ForEach-Object { Write-Output "F: $($_.FullName) Ext: $($_.Extension)" }
Write-Output 'Listing files matching pattern from helper code:'
$pattern = ('.mp3','.flac','.wav','.m4a','.aac','.ogg','.ape' -join '|') -replace '\\.', '\\\\.'
Get-ChildItem -LiteralPath $tmp -File -Recurse | Where-Object { $_.Extension -match "($pattern)$" } | ForEach-Object { Write-Output "MATCH: $($_.FullName) Ext: $($_.Extension)" }

Write-Output 'Calling Reload...'
$res = Reload-OMAudioFiles -AlbumPath $tmp
Write-Output 'Reload returned count:' $res.Count
$res | Format-List | Out-Host
Write-Output 'Manual run end'
Remove-Item -LiteralPath $tmp -Recurse -Force
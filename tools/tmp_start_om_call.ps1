Import-Module .\OM.psm1 -Force
function global:Show-Message { param($msg,$color,$no) Write-Output "SHOWMSG: $msg" }
function global:Assert-TagLibLoaded { return $true }
function global:Invoke-ProviderSearch { param($Provider,$Album,$Artist,$Type) if ($Provider -eq 'Spotify') { return @{ albums = @{ items = @() } } } elseif ($Provider -eq 'Qobuz') { return @{ albums = @{ items = @([PSCustomObject]@{ id='q1'; name='Album'; album_artist='Artist' }) } } } else { return @{ albums = @{ items = @() } } } }
$td = Join-Path $env:TEMP ("omtmp_" + (Get-Random))
New-Item -ItemType Directory -Path $td | Out-Null
$af = Join-Path $td 'Artist\2020 - Album'
New-Item -ItemType Directory -Path $af -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $af '01 - track.mp3') | Out-Null
Write-Output "Calling Start-OM with Path: $td"
Start-OM -Path $td -Auto -AutoFallback -NonInteractive -Confirm:$false -Context [PSCustomObject]@{}
Write-Output Done
Remove-Item -LiteralPath $td -Recurse -Force

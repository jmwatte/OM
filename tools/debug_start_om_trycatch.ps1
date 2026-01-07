Import-Module .\OM.psm1 -Force
function global:Show-Message { param($msg,$color,$no) Write-Output "SHOWMSG: $msg" }
function global:Invoke-ProviderSearch { 
    param($Provider,$Album,$Artist,$Type)
    if ($Provider -eq 'Spotify') {
        return @{ albums = @{ items = @() } }
    }
    elseif ($Provider -eq 'Qobuz') {
        return @{ albums = @{ items = @( [PSCustomObject]@{ id='q1'; name='Album'; album_artist='Artist' } ) } }
    }
    else {
        return @{ albums = @{ items = @() } }
    }
}
$td = Join-Path $env:TEMP ("omtmp_" + (Get-Random))
New-Item -ItemType Directory -Path $td | Out-Null
New-Item -ItemType Directory -Path (Join-Path $td 'Artist\2020 - Album') -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $td 'Artist\2020 - Album\01 - track.mp3') | Out-Null
Write-Output "Calling Start-OM with Path: $td"
Set-PSDebug -Trace 2
try {
    Start-OM -Path $td -Auto -AutoFallback -NonInteractive -Confirm:$false -Context [PSCustomObject]@{} -ErrorAction Stop -Verbose
    Set-PSDebug -Off
}
catch {
    Write-Output "CATCH: $($_.Exception.GetType().FullName): $($_.Exception.Message)"
    Write-Output 'InvocationInfo:'
    $_.InvocationInfo | Format-List *
    Write-Output 'ScriptStackTrace:'
    Write-Output $_.ScriptStackTrace
    Write-Output 'InnerException:'
    Write-Output $_.Exception.InnerException
    Write-Output 'StackTrace:'
    Write-Output $_.Exception.StackTrace
}
Write-Output Done
Remove-Item -LiteralPath $td -Recurse -Force

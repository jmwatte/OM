Import-Module .\OM.psm1 -Force
function global:Show-Message { param($msg,$color,$no) Write-Output "SHOWMSG: $msg" }
function global:Assert-TagLibLoaded { return $true }
function global:Invoke-ProviderSearch { param($Provider,$Album,$Artist,$Type) if ($Provider -eq 'Spotify') { return @{ albums = @{ items = @() } } } elseif ($Provider -eq 'Qobuz') { return @{ albums = @{ items = @([PSCustomObject]@{ id='q1'; name='Album'; album_artist='Artist' }) } } } else { return @{ albums = @{ items = @() } } } }

function DumpErrorRecordDetail { param($er)
    Write-Output "--- DumpErrorRecordDetail ---"
    $er | Format-List *
    if ($er.Exception) { $er.Exception | Format-List * }
    Write-Output "CallStack via Get-PSCallStack:"
    Get-PSCallStack | ForEach-Object { Write-Output "  $_" }
    Write-Output "--- end dump ---"
}

# Set breakpoint on ParameterBindingException and dump immediate details, then remove it and rethrow
Set-PSBreakpoint -Exception System.Management.Automation.ParameterBindingException -Action {
    Write-Output "*** BREAKPOINT HIT: ParameterBindingException ***"
    if ($error.Count -gt 0) { DumpErrorRecordDetail -er $error[0] }
    else { Write-Output "No $error available" }
    # Remove all breakpoints to avoid recurring
    Get-PSBreakpoint | Remove-PSBreakpoint
    # Re-throw to allow normal exception flow
    throw
}

$td = Join-Path $env:TEMP ("omtmp_" + (Get-Random))
New-Item -ItemType Directory -Path $td | Out-Null
$af = Join-Path $td 'Artist\2020 - Album'
New-Item -ItemType Directory -Path $af -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $af '01 - track.mp3') | Out-Null
Write-Output "Calling Start-OM with Path: $td"
try {
    Start-OM -Path $td -Auto -AutoFallback -NonInteractive -Confirm:$false -Context [PSCustomObject]@{} -Verbose
}
catch {
    Write-Output "CATCH: $($_.Exception.GetType().FullName): $($_.Exception.Message)"
    DumpErrorRecordDetail -er $_
}
Remove-Item -LiteralPath $td -Recurse -Force

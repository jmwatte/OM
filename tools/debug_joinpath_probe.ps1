Import-Module .\OM.psm1 -Force
# Temporary debug wrapper for Join-Path that logs and fails on empty ChildPath
function global:Join-Path {
    param(
        [Parameter(Mandatory=$true,Position=0)][string]$Path,
        [Parameter(Position=1)][string]$ChildPath
    )
    Write-Output "DEBUG_JOINPATH: Path='$Path' ChildPath='${ChildPath}'"
    if ([string]::IsNullOrWhiteSpace($ChildPath)) { throw 'DEBUG_JOINPATH: ChildPath is empty' }
    return Microsoft.PowerShell.Management\Join-Path -Path $Path -ChildPath $ChildPath
}

$td = Join-Path $env:TEMP ("omtmp_jpp_" + (Get-Random))
New-Item -ItemType Directory -Path (Join-Path $td 'Artist\2020 - Album') -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $td 'Artist\2020 - Album\01 - track.mp3') | Out-Null

Start-OM -Path $td -Auto -AutoFallback -NonInteractive -Confirm:$false -Context [pscustomobject]@{} -Verbose
Write-Output 'DEBUG_JOINPATH: Start-OM completed'

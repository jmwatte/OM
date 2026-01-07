# Lightweight debug harness: sets breakpoints and calls Start-OM directly (no Pester)
$modulePath = Join-Path $PSScriptRoot '..\OM.psm1'
if (-not (Test-Path $modulePath)) { Write-Warning "Module file not found: $modulePath" }
Import-Module -Name $modulePath -Force

# Set a few useful breakpoints (script lines + commands)
# To run unattended (e.g., CI or long-running debug), set env var OM_NO_BREAKPOINTS=1 to skip these
if (-not $env:OM_NO_BREAKPOINTS) {
    Set-PSBreakpoint -Script (Join-Path $PSScriptRoot '..\Public\Start-OM.ps1') -Line 1140 -ErrorAction SilentlyContinue
    Set-PSBreakpoint -Script (Join-Path $PSScriptRoot '..\Public\Start-OM.ps1') -Line 2005 -ErrorAction SilentlyContinue
    Set-PSBreakpoint -Script (Join-Path $PSScriptRoot '..\Public\Start-OM.ps1') -Line 2399 -ErrorAction SilentlyContinue
    Set-PSBreakpoint -Command Show-OMPrompt -ErrorAction SilentlyContinue
    Set-PSBreakpoint -Command Show-Tracks -ErrorAction SilentlyContinue
    Set-PSBreakpoint -Command Show-Message -ErrorAction SilentlyContinue
}

# Minimal stubs to avoid external dependencies
if (-not (Get-Command -Name Assert-TagLibLoaded -ErrorAction SilentlyContinue)) {
    function global:Assert-TagLibLoaded { return $true }
}
if (-not (Get-Command -Name Show-Message -ErrorAction SilentlyContinue)) {
    if (-not $global:__DBG_SHOWMSG) { $global:__DBG_SHOWMSG = [System.Collections.Concurrent.ConcurrentBag[string]]::new() }
    function global:Show-Message {
        param($Message, $ForegroundColor, $NoNewline, $Context)
        if (-not $global:__DBG_SHOWMSG) { $global:__DBG_SHOWMSG = [System.Collections.Concurrent.ConcurrentBag[string]]::new() }
        [void]$global:__DBG_SHOWMSG.Add("SHOWMSG: $Message") | Out-Null
        # Ensure no pipeline output
        Out-Null
    }
}
if (-not (Get-Command -Name Invoke-ProviderSearch -ErrorAction SilentlyContinue)) {
    function global:Invoke-ProviderSearch { param($Provider,$Album,$Artist,$Type) if ($Provider -eq 'Qobuz') { return @{ albums = @{ items = @([PSCustomObject]@{ id='q1'; name='Album'; album_artist='Artist' }) } } } ; return @{ albums = @{ items = @() } } }
}

# Create temporary album dir
$td = Join-Path $env:TEMP ("omtmp_debug_" + (Get-Random))
New-Item -Force -ItemType Directory -Path (Join-Path $td 'Artist\2020 - Album') | Out-Null
New-Item -Force -ItemType File -Path (Join-Path $td 'Artist\2020 - Album\01 - track.mp3') | Out-Null
Write-Output "Calling Start-OM with Path: $td"

try {
    # Run Start-OM under Trace-Command to capture ParameterBinding/CommandInvocation events for diagnostics
    Trace-Command -Name ParameterBinding,CommandInvocation -Expression { Start-OM -Path $td -Auto -AutoFallback -NonInteractive -Confirm:$false -Context [PSCustomObject]@{} -Verbose } -PSHost
}
catch {
    Write-Output "CATCH: $($_.Exception.GetType().FullName): $($_.Exception.Message)"
    if ($_.Exception) { $_.Exception | Format-List * -Force }
    if ($PSBoundParameters) { Write-Output "PSBoundParameters: $($PSBoundParameters.Keys -join ',')" }

    if (Get-Command -Name Dump-ExceptionDiagnostics -ErrorAction SilentlyContinue) {
        Dump-ExceptionDiagnostics -ErrorRecord $_ -ContextMsg "Top-level harness catch"
    }

    # Also print current call stack for extra context
    try { Get-PSCallStack | Format-Table -AutoSize } catch { }
}

# Cleanup
Remove-Item -LiteralPath $td -Recurse -Force -ErrorAction SilentlyContinue
Write-Output Done

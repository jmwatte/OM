$files = @('om_invoke_safe_diag.txt','om_invoke_safe_diag_details.txt','start_om_state_snapshot.txt','start_om_invocation_log.txt')
foreach ($f in $files) {
    $p = Join-Path $env:TEMP $f
    if (Test-Path $p) {
        Copy-Item -Path $p -Destination (Join-Path $PSScriptRoot $f) -Force
        Write-Output "Copied $p -> $PSScriptRoot\$f"
    }
    else { Write-Output "Not found: $p" }
}
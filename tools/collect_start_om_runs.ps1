param(
    [int]$Iterations = 30
)

$runDir = Join-Path $PSScriptRoot 'diag_runs'
if (-not (Test-Path $runDir)) { New-Item -ItemType Directory -Path $runDir | Out-Null }

for ($i = 1; $i -le $Iterations; $i++) {
    $ts = (Get-Date).ToString('yyyyMMdd_HHmmss')
    Write-Output "Run #$i at $ts"
    try {
        & "$PSScriptRoot\run_start_om_catch.ps1" -ErrorAction Stop
        $status = 'ok'
    } catch {
        $status = 'fail'
    }

    $dest = Join-Path $runDir "$ts`_$i`_$status"
    New-Item -ItemType Directory -Path $dest | Out-Null

    # Copy known diag files if present
    $files = @($env:TEMP + '\om_invoke_safe_diag.txt', $env:TEMP + '\om_invoke_safe_diag_details.txt', $env:TEMP + '\start_om_state_snapshot.txt', $env:TEMP + '\start_om_invocation_log.txt')
    foreach ($f in $files) {
        if (Test-Path $f) { Copy-Item -Path $f -Destination (Join-Path $dest (Split-Path $f -Leaf)) -Force }
    }

    # Copy harness trace outputs if they exist
    $traceFiles = Get-ChildItem -Path $PSScriptRoot -Filter 'start_om_regression_trace*.txt' -File -ErrorAction SilentlyContinue
    foreach ($tf in $traceFiles) { Copy-Item -Path $tf.FullName -Destination (Join-Path $dest $tf.Name) -Force }

    Start-Sleep -Milliseconds 200
}

Write-Output "Finished $Iterations runs. Diag runs saved in: $runDir"
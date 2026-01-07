# Reproduce Start-OM regression with Trace-Command
$td = Join-Path $env:TEMP ("OMStartRegress_" + (Get-Random))
New-Item -ItemType Directory -Path $td | Out-Null
$albumFolder = Join-Path $td 'Artist\2020 - Album'
New-Item -ItemType Directory -Path $albumFolder -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $albumFolder '01 - track.mp3') | Out-Null

# Simple stubs (Pester Mock not available in this raw script run)
if (-not (Get-Command -Name Assert-TagLibLoaded -ErrorAction SilentlyContinue)) { function global:Assert-TagLibLoaded { } }
if (-not (Get-Command -Name Invoke-ProviderSearch -ErrorAction SilentlyContinue)) { function global:Invoke-ProviderSearch { param($Provider,$Album,$Artist,$Type) if ($Provider -eq 'Spotify') { return @{ albums = @{ items = @() } } } if ($Provider -eq 'Qobuz') { return @{ albums = @{ items = @([PSCustomObject]@{ id="q1"; name="Album"; album_artist="Artist" }) } } } return @{ albums = @{ items = @() } } } }
if (-not (Get-Command -Name Show-Message -ErrorAction SilentlyContinue)) { function global:Show-Message { param($m,$c) if (-not $global:msgs) { $global:msgs = [System.Collections.Concurrent.ConcurrentBag[string]]::new() } $global:msgs.Add($m) } }
# Stubs for side-effecty functions used by Start-OM
if (-not (Get-Command -Name Save-CoverArt -ErrorAction SilentlyContinue)) { function global:Save-CoverArt { param($url) Write-Output "CALL_SAVE $url" } }
if (-not (Get-Command -Name Save-TagsForFile -ErrorAction SilentlyContinue)) { function global:Save-TagsForFile { param($file,$tags) Write-Output "CALL_SAVE_TAGS $file" } }

# Run Start-OM under Trace-Command and capture output
try {
    Trace-Command -Name ParameterBinding,CommandInvocation -Expression { Start-OM -Path $td -Auto -AutoFallback -NonInteractive -Confirm:$false -Context [PSCustomObject]@{} -Verbose } -PSHost | Out-File -FilePath .\tools\start_om_regression_trace.txt -Encoding utf8
} catch {
    "--- TOP-LEVEL CATCH: ErrorRecord ---" | Out-File -FilePath .\tools\start_om_regression_trace_error.txt -Encoding utf8
    $_ | Format-List * -Force | Out-File -FilePath .\tools\start_om_regression_trace_error.txt -Append -Encoding utf8
    if (Get-Command -Name Dump-ExceptionDiagnostics -ErrorAction SilentlyContinue) {
        Dump-ExceptionDiagnostics -ErrorRecord $_ -ContextMsg "Top-level Start-OM harness catch"
    }
    throw
}

Remove-Item -LiteralPath $td -Recurse -Force -ErrorAction SilentlyContinue
Write-Output Done
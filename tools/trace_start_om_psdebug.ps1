# PSDebug-based trace to catch ParameterBindingException origin
$td = Join-Path $env:TEMP ("OMStartRegress_" + (Get-Random))
New-Item -ItemType Directory -Path $td | Out-Null
$albumFolder = Join-Path $td 'Artist\2020 - Album'
New-Item -ItemType Directory -Path $albumFolder -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $albumFolder '01 - track.mp3') | Out-Null

# Simple stubs
if (-not (Get-Command -Name Assert-TagLibLoaded -ErrorAction SilentlyContinue)) { function global:Assert-TagLibLoaded { } }
if (-not (Get-Command -Name Invoke-ProviderSearch -ErrorAction SilentlyContinue)) { function global:Invoke-ProviderSearch { param($Provider,$Album,$Artist,$Type) if ($Provider -eq 'Spotify') { return @{ albums = @{ items = @() } } } if ($Provider -eq 'Qobuz') { return @{ albums = @{ items = @([PSCustomObject]@{ id="q1"; name="Album"; album_artist="Artist" }) } } } return @{ albums = @{ items = @() } } } }
if (-not (Get-Command -Name Show-Message -ErrorAction SilentlyContinue)) { function global:Show-Message { param($m,$c) if (-not $global:msgs) { $global:msgs = [System.Collections.Concurrent.ConcurrentBag[string]]::new() } $global:msgs.Add($m) } }
if (-not (Get-Command -Name Save-CoverArt -ErrorAction SilentlyContinue)) { function global:Save-CoverArt { param($url) Write-Output "CALL_SAVE $url" } }
if (-not (Get-Command -Name Save-TagsForFile -ErrorAction SilentlyContinue)) { function global:Save-TagsForFile { param($file,$tags) Write-Output "CALL_SAVE_TAGS $file" } }

$traceFile = Join-Path $PSScriptRoot 'start_om_psdebug_transcript.txt'
if (Test-Path $traceFile) { Remove-Item $traceFile -Force }

Start-Transcript -Path $traceFile -Force | Out-Null
Set-PSDebug -Trace 1
try {
    Start-OM -Path $td -Auto -AutoFallback -NonInteractive -Confirm:$false -Context [PSCustomObject]@{} -Verbose
} catch {
    "--- EXCEPTION CAUGHT IN HARNESS ---" | Out-File -FilePath $traceFile -Append -Encoding utf8
    $_ | Format-List * -Force | Out-File -FilePath $traceFile -Append -Encoding utf8
    if (Get-Command -Name Dump-ExceptionDiagnostics -ErrorAction SilentlyContinue) { Dump-ExceptionDiagnostics -ErrorRecord $_ -ContextMsg "Harness PSDebug catch" | Out-File -FilePath $traceFile -Append -Encoding utf8 }
}
Set-PSDebug -Off
Stop-Transcript | Out-Null

Remove-Item -LiteralPath $td -Recurse -Force -ErrorAction SilentlyContinue
Write-Output "Wrote trace to: $traceFile"
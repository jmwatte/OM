# Run Start-OM directly with try/catch to capture richer diagnostics
$td = Join-Path $env:TEMP ("OMStartRegress_" + (Get-Random))
New-Item -ItemType Directory -Path $td | Out-Null
$albumFolder = Join-Path $td 'Artist\2020 - Album'
New-Item -ItemType Directory -Path $albumFolder -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $albumFolder '01 - track.mp3') | Out-Null

# Stubs
if (-not (Get-Command -Name Assert-TagLibLoaded -ErrorAction SilentlyContinue)) { function global:Assert-TagLibLoaded { } }
if (-not (Get-Command -Name Invoke-ProviderSearch -ErrorAction SilentlyContinue)) { function global:Invoke-ProviderSearch { param($Provider,$Album,$Artist,$Type) if ($Provider -eq 'Spotify') { return @{ albums = @{ items = @() } } } if ($Provider -eq 'Qobuz') { return @{ albums = @{ items = @([PSCustomObject]@{ id="q1"; name="Album"; album_artist="Artist" }) } } } return @{ albums = @{ items = @() } } } }
if (-not (Get-Command -Name Show-Message -ErrorAction SilentlyContinue)) { function global:Show-Message { param($m,$c) if (-not $global:msgs) { $global:msgs = [System.Collections.Concurrent.ConcurrentBag[string]]::new() } $global:msgs.Add($m) } }
if (-not (Get-Command -Name Save-CoverArt -ErrorAction SilentlyContinue)) { function global:Save-CoverArt { param($PSBoundParameters) @{ Success = $true } } }
if (-not (Get-Command -Name Save-TagsForFile -ErrorAction SilentlyContinue)) { function global:Save-TagsForFile { param($PSBoundParameters) @{ Success = $true } } }

# Ensure errors surface
$ErrorActionPreference = 'Stop'
try {
    Start-OM -Path $td -Auto -AutoFallback -NonInteractive -Confirm:$false -Context [PSCustomObject]@{} -Verbose
    Write-Output "Start-OM completed successfully"
} catch {
    $err = $_
    $out = '.\tools\start_om_direct_error.txt'
    "--- ERROR RECORD ---" | Out-File -FilePath $out -Encoding utf8
    $err | Format-List * -Force | Out-File -FilePath $out -Append -Encoding utf8
    "--- Exception Details ---" | Out-File -FilePath $out -Append -Encoding utf8
    $err.Exception | Format-List * -Force | Out-File -FilePath $out -Append -Encoding utf8
    "--- Invocation Info ---" | Out-File -FilePath $out -Append -Encoding utf8
    $err.InvocationInfo | Format-List * -Force | Out-File -FilePath $out -Append -Encoding utf8
    "--- Script Stack Trace ---" | Out-File -FilePath $out -Append -Encoding utf8
    $err.ScriptStackTrace | Out-File -FilePath $out -Append -Encoding utf8
    "--- PS Call Stack ---" | Out-File -FilePath $out -Append -Encoding utf8
    Get-PSCallStack | Out-File -FilePath $out -Append -Encoding utf8
    if (Get-Command -Name Dump-ExceptionDiagnostics -ErrorAction SilentlyContinue) {
        Dump-ExceptionDiagnostics -ErrorRecord $err -ContextMsg "Top-level direct harness catch"
    }
    throw
} finally {
    Remove-Item -LiteralPath $td -Recurse -Force -ErrorAction SilentlyContinue
}

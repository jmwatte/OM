Import-Module Pester -Force
Import-Module .\OM.psm1 -Force
. .\Private\Utils\Show-Message.ps1

$testDir = Join-Path $env:TEMP ("OMStartAutoFallback_dbg_" + (Get-Random))
New-Item -ItemType Directory -Path $testDir | Out-Null
$albumFolder = Join-Path $testDir 'Artist\2020 - Album'
New-Item -ItemType Directory -Path $albumFolder -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $albumFolder '01 - track.mp3') | Out-Null

Mock -CommandName Assert-TagLibLoaded -ModuleName OM -MockWith { }

# Mock provider search to return nothing for Spotify, results for Qobuz
Mock -CommandName Invoke-ProviderSearch -ModuleName OM -MockWith {
    param($Provider,$Album,$Artist,$Type)
    if ($Provider -eq 'Spotify') { return @{ albums = @{ items = @() } } }
    if ($Provider -eq 'Qobuz') { return @{ albums = @{ items = @([PSCustomObject]@{ id='q1'; name='Album'; album_artist='Artist' }) } } }
    return @{ albums = @{ items = @() } }
}

$script:msgs = New-Object System.Collections.Concurrent.ConcurrentBag[System.String]
Mock -CommandName Show-Message -ModuleName OM -MockWith { $script:msgs.Add($args[0]) }

try {
    $VerbosePreference = 'Continue'
    $res = Start-OM -Path $testDir -Auto -AutoFallback -NonInteractive -Confirm:$false -Context [PSCustomObject]@{}
    Write-Output "Completed: $($res.Completed)"
} catch {
    Write-Output "=== FULL EXCEPTION ==="
    $_ | Format-List * -Force
    Write-Output "=== END EXCEPTION ==="
}

Write-Output "Captured messages:"
$script:msgs | Select-Object -First 20 | ForEach-Object { Write-Output "MSG: $_" }

Remove-Item -LiteralPath $testDir -Recurse -Force

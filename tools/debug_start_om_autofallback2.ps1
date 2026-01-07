try {
    Import-Module Pester -Force
    Import-Module .\OM.psm1 -Force
    . .\Private\Utils\Show-Message.ps1

    $testDir = Join-Path $env:TEMP ("OMStartAutoFallback_dbg_" + (Get-Random))
    New-Item -ItemType Directory -Path $testDir | Out-Null
    $albumFolder = Join-Path $testDir 'Artist\2020 - Album'
    New-Item -ItemType Directory -Path $albumFolder -Force | Out-Null
    New-Item -ItemType File -Path (Join-Path $albumFolder '01 - track.mp3') | Out-Null

    function Assert-TagLibLoaded { return $true }

    # Mock provider search to return nothing for Spotify, results for Qobuz
    function Invoke-ProviderSearch { param($Provider,$Album,$Artist,$Type)
        if ($Provider -eq 'Spotify') { return @{ albums = @{ items = @() } } }
        if ($Provider -eq 'Qobuz') { return @{ albums = @{ items = @([PSCustomObject]@{ id='q1'; name='Album'; album_artist='Artist' }) } } }
        return @{ albums = @{ items = @() } }
    }

    $script:msgs = New-Object System.Collections.Concurrent.ConcurrentBag[System.String]
    function Show-Message { param($msg,$color,$no) $script:msgs.Add($msg) }

    $VerbosePreference = 'Continue'
    Write-Output "DEBUG: Path var = '$testDir' (Length: $($testDir.Length))"
    Write-Output "DEBUG: Auto: $($true), AutoFallback: $($true), NonInteractive: $($true)"
    Write-Output "DEBUG: Context type: $(([PSCustomObject]@{}).GetType().FullName)"

    $res = Start-OM -Path $testDir -Auto -AutoFallback -NonInteractive -Confirm:$false -Context [PSCustomObject]@{}
    Write-Output "Completed: $($res.Completed)"

    Write-Output "Captured messages:"
    $script:msgs | Select-Object -First 20 | ForEach-Object { Write-Output "MSG: $_" }

    Remove-Item -LiteralPath $testDir -Recurse -Force
} catch {
    Write-Output "=== OUTER EXCEPTION ==="
    $_ | Format-List * -Force
    Write-Output "=== ERROR STACK ==="
    $global:Error | Select-Object -First 20 | ForEach-Object { Write-Output "ERR: $_" }
    throw
} finally {
    Write-Output "Script finished (finally)"
}

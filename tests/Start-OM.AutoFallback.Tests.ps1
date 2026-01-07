Describe 'Start-OM AUTO provider fallback and autosave cover tests' {
    It 'switches to fallback provider when default has no results' {
        Import-Module (Join-Path $PSScriptRoot '..\OM.psm1') -Force
        . (Join-Path $PSScriptRoot '..\Private\Utils\Show-Message.ps1')

        $testDir = Join-Path $env:TEMP ("OMStartAutoFallback_" + (Get-Random))
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

        $res = Start-OM -Path $testDir -Auto -AutoFallback -NonInteractive -WhatIf -Confirm:$false -Context [PSCustomObject]@{}

        $script:msgs -join "`n" | Should -Match 'Switched to provider: Qobuz|Switched to provider'
        $res.Completed | Should -Be $true

        Remove-Item -LiteralPath $testDir -Recurse -Force
    }

    It 'calls Save-CoverArt when AutoSaveCover is enabled' {
        Import-Module (Join-Path $PSScriptRoot '..\OM.psm1') -Force
        . (Join-Path $PSScriptRoot '..\Private\Utils\Show-Message.ps1')

        $testDir = Join-Path $env:TEMP ("OMStartAutoCover_" + (Get-Random))
        New-Item -ItemType Directory -Path $testDir | Out-Null
        $albumFolder = Join-Path $testDir 'Artist\2020 - Album'
        New-Item -ItemType Directory -Path $albumFolder -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $albumFolder '01 - track.mp3') | Out-Null

        Mock -CommandName Assert-TagLibLoaded -ModuleName OM -MockWith { }

        # Provider should return an album with cover_url
        Mock -CommandName Invoke-ProviderSearch -ModuleName OM -MockWith {
            param($Provider,$Album,$Artist,$Type)
            return @{ albums = @{ items = @([PSCustomObject]@{ id='a1'; name='Album'; album_artist='Artist'; cover_url='http://example/cover.jpg' }) } }
        }

        $script:saveCalls = 0
        Mock -CommandName Save-CoverArt -ModuleName OM -MockWith { $script:saveCalls++; return @{ Success = $true } }

        $script:msgs = New-Object System.Collections.Concurrent.ConcurrentBag[System.String]
        Mock -CommandName Show-Message -ModuleName OM -MockWith { $script:msgs.Add($args[0]) }

        $res = Start-OM -Path $testDir -Auto -AutoSaveCover -NonInteractive -WhatIf -Confirm:$false

        # Expect Save-CoverArt was invoked at least once
        $script:saveCalls | Should -BeGreaterThan 0
        $res.Completed | Should -Be $true

        Remove-Item -LiteralPath $testDir -Recurse -Force
    }
}
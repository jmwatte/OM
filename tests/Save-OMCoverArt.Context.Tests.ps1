Describe 'Save-OMCoverArt smoke test' {
    It 'fetches search results and saves cover art' {
        $testDir = Join-Path $env:TEMP ("OMCoverTest_" + (Get-Random))
        New-Item -ItemType Directory -Path $testDir | Out-Null
        $artistFolder = Join-Path $testDir 'Artist'
        New-Item -ItemType Directory -Path $artistFolder | Out-Null
        $albumFolder = Join-Path $artistFolder '2020 - Album'
        New-Item -ItemType Directory -Path $albumFolder | Out-Null
        New-Item -ItemType File -Path (Join-Path $albumFolder '01 - track.mp3') | Out-Null

        # Load module and ensure Show-Message available
        Import-Module (Join-Path $PSScriptRoot '..\OM.psm1') -Force
        . (Join-Path $PSScriptRoot '..\Private\Utils\Show-Message.ps1')

        # Ensure config and TagLib checks pass
        Mock -CommandName Get-OMConfig -ModuleName OM -MockWith { @{ } }
        Mock -CommandName Assert-TagLibLoaded -ModuleName OM -MockWith { } 

        # Mock provider search to return a cover_url
        Mock -CommandName Invoke-ProviderSearchAlbums -ModuleName OM -MockWith {
            @([PSCustomObject]@{ artist = 'Artist'; name = 'Album'; id = 'id'; cover_url = 'http://example/cover.jpg' })
        }

        # Capture Save-CoverArt calls
        $script:saveCalls = 0
        Mock -CommandName Save-CoverArt -ModuleName OM -MockWith { $script:saveCalls++; return @{ Success = $true } }

        $out = Save-OMCoverArt -Path $albumFolder -Provider 'Qobuz'

        # Assert Save-CoverArt was invoked and success message printed
        $script:saveCalls | Should -BeGreaterThan 0
        ($out -join "`n") | Should -Match '✓ Cover art saved successfully'

        Remove-Item -LiteralPath $testDir -Recurse -Force
    }
}
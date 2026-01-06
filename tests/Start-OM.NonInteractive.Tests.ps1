Describe 'Start-OM non-interactive smoke test' {
    It 'completes without prompting on -NonInteractive -Auto -WhatIf' {
        Import-Module (Join-Path $PSScriptRoot '..\OM.psm1') -Force
        . (Join-Path $PSScriptRoot '..\Private\Utils\Show-Message.ps1')

        $testDir = Join-Path $env:TEMP ("OMStartTest_" + (Get-Random))
        New-Item -ItemType Directory -Path $testDir | Out-Null
        # Create an album folder structure without audio files (safe non-destructive case)
        $albumFolder = Join-Path $testDir 'Artist\2020 - Album'
        New-Item -ItemType Directory -Path $albumFolder -Force | Out-Null

        # Prevent TagLib checks or interactive prompts from failing
        Mock -CommandName Assert-TagLibLoaded -MockWith { }
        Mock -CommandName Show-Message -ModuleName OM -MockWith { }

        # Run Start-OM in non-interactive auto preview mode
        $res = Start-OM -Path $testDir -Auto -AutoFallback -NonInteractive -WhatIf -Confirm:$false -Context [PSCustomObject]@{}

        # Expect a PSCustomObject with Completed = $true (function finishes gracefully)
        $res | Should -Not -BeNullOrEmpty
        $res.Completed | Should -Be $true

        # Cleanup
        Remove-Item -LiteralPath $testDir -Recurse -Force
    }
}
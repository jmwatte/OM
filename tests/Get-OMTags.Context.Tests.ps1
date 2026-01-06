Describe 'Get-OMTags TagLib failure uses Context' {
    It 'shows install instructions via Show-Message when Add-Type fails' {
        Import-Module (Join-Path $PSScriptRoot '..\OM.psm1') -Force
        . (Join-Path $PSScriptRoot '..\Private\Utils\Show-Message.ps1')

        # Mock Add-Type to throw to simulate TagLib load failure
        Mock -CommandName Add-Type -MockWith { throw "Simulated Add-Type failure" }

        $script:msgs = @()
        Mock -CommandName Show-Message -MockWith { param($Message,$ForegroundColor,$NoNewline,$DisplayWriter,$Context) $script:msgs += $Message }

        # Call Get-OMTags with a fake path (it will attempt to load TagLib and hit the mocked Add-Type)
        $res = Get-OMTags -Path (Join-Path $env:TEMP 'nonexistent_folder') -Context [PSCustomObject]@{}

        $script:msgs | Should -Not -BeNullOrEmpty
        ($script:msgs -join "`n") | Should -Match 'Please try reinstalling TagLib-Sharp'
    }
}
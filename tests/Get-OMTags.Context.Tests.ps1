Describe 'Get-OMTags TagLib failure uses Context' {
    It 'shows install instructions via Show-Message when Add-Type fails' {
        Import-Module (Join-Path $PSScriptRoot '..\OM.psm1') -Force
        . (Join-Path $PSScriptRoot '..\Private\Utils\Show-Message.ps1')

        # If TagLib is already present in the environment, skip this test because we can't force a missing Add-Type
        if ([System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.FullName -like '*TagLib*' }) { Skip 'TagLib present in environment; skipping TagLib failure path' }

        # Mock Add-Type to throw to simulate TagLib load failure
        Mock -CommandName Add-Type -MockWith { throw "Simulated Add-Type failure" }

        $script:msgs = New-Object System.Collections.Generic.List[System.String]
        Mock -CommandName Show-Message -ModuleName OM -MockWith { param($Message,$ForegroundColor,$NoNewline,$DisplayWriter,$Context) $script:msgs.Add($Message) }

        # Call Get-OMTags with a fake path (it will attempt to load TagLib and hit the mocked Add-Type)
        $res = Get-OMTags -Path (Join-Path $env:TEMP 'nonexistent_folder') -Context [PSCustomObject]@{}

        $script:msgs | Should -Not -BeNullOrEmpty
        ($script:msgs -join "`n") | Should -Match 'Please try reinstalling TagLib-Sharp'
    }
}
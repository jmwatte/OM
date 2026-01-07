Describe 'Set-OMTags Context propagation' {
    It 'uses Context and reports successful update via Show-Message' {
        Import-Module (Join-Path $PSScriptRoot '..\OM.psm1') -Force
        . (Join-Path $PSScriptRoot '..\Private\Utils\Show-Message.ps1')

        $testDir = Join-Path $env:TEMP ("OMSetTags_" + (Get-Random))
        New-Item -ItemType Directory -Path $testDir | Out-Null
        $file = Join-Path $testDir '01 - track.mp3'
        New-Item -ItemType File -Path $file | Out-Null

        # Mock Save-TagsForFile to simulate success without touching disk
        Mock -CommandName Save-TagsForFile -ModuleName OM -MockWith { return @{ Success = $true } }

        $script:messages = New-Object System.Collections.Concurrent.ConcurrentBag[System.String]
        Mock -CommandName Show-Message -ModuleName OM -MockWith { $script:messages.Add($args[0]) }

        # Stub Assert-TagLibLoaded so Set-OMTags does not require TagLib
        Mock -CommandName Assert-TagLibLoaded -ModuleName OM -MockWith { return }

        # Run Set-OMTags in simple mode on the temp file
        Set-OMTags -Path $file -Tags @{ Title = 'Test' } -Confirm:$false -PassThru:$false

        $script:messages | Should -Not -BeNullOrEmpty
        ($script:messages -join "`n") | Should -Match 'Successfully updated|✓ Successfully updated'

        # Cleanup
        Remove-Item -LiteralPath $testDir -Recurse -Force
    }
}
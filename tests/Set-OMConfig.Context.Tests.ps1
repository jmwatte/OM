Describe 'Set-OMConfig Context propagation' {
    It 'saves config to provided path and calls Show-Message' {
        Import-Module (Join-Path $PSScriptRoot '..\OM.psm1') -Force
        . (Join-Path $PSScriptRoot '..\Private\Utils\Show-Message.ps1')

        $tmpdir = Join-Path $env:TEMP ("om_config_" + (Get-Random))
        New-Item -ItemType Directory -Path $tmpdir | Out-Null
        $tmpFile = Join-Path $tmpdir 'config.json'

        $script:messages = New-Object System.Collections.Generic.List[System.String]
        Mock -CommandName Show-Message -ModuleName OM -MockWith { param($Message,$ForegroundColor,$NoNewline,$DisplayWriter,$Context) $script:messages.Add($Message) }

        Set-OMConfig -SpotifyClientId 'cid' -SpotifyClientSecret 'secret' -ConfigPath $tmpFile -Context [PSCustomObject]@{} -Confirm:$false

        $script:messages | Should -Not -BeNullOrEmpty
        ($script:messages -join "`n") | Should -Match 'Configuration saved to'

        # cleanup
        Remove-Item -LiteralPath $tmpdir -Recurse -Force
    }
}
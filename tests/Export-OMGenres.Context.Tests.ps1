Describe 'Export-OMGenres Context propagation' {
    It 'uses Context and calls Show-Message on export' {
        . (Join-Path $PSScriptRoot '..\Public\Export-OMGenres.ps1')
        . (Join-Path $PSScriptRoot '..\Private\Utils\Show-Message.ps1')

        $tmp = Join-Path $env:TEMP ("om_genres_" + (Get-Random) + ".json")
        # Stub config
        Mock -CommandName Get-OMConfig -MockWith { @{ Genres = [PSCustomObject]@{ AllowedGenreNames = @('Pop'); GenreMappings = @{ 'x' = 'y' } } } }

        $script:messages = @()
        Mock -CommandName Show-Message -MockWith { param($Message,$ForegroundColor,$NoNewline,$DisplayWriter,$Context) $script:messages += $Message }

        $ctx = [PSCustomObject]@{ DisplayWriter = { param($msg,$color,$no) $script:messages += "DW: $msg" } }

        Export-OMGenres -Path $tmp -Context $ctx -PassThru:$false

        $script:messages | Should -Not -BeNullOrEmpty
        ($script:messages -join "`n") | Should -Match "exported to:"

        if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Force }
    }
}
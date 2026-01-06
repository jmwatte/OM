Describe 'Format-Genres Context propagation' {
    It 'uses Context and emits unmapped summary in NonInteractive mode' {
        Import-Module (Join-Path $PSScriptRoot '..\OM.psm1') -Force
        . (Join-Path $PSScriptRoot '..\Private\Utils\Show-Message.ps1')

        # Ensure config exists with empty mappings
        Mock -CommandName Get-OMConfig -MockWith { @{ Genres = @{ AllowedGenreNames = @('Pop'); GenreMappings = @{}; GarbageGenres = @() } } }

        $input = [PSCustomObject]@{ Path = 'fakepath'; Genres = @('UnmappedGenre') }

        $script:msgs = New-Object System.Collections.Generic.List[System.String]
        Mock -CommandName Show-Message -ModuleName OM -MockWith { param($Message,$ForegroundColor,$NoNewline,$DisplayWriter,$Context) $script:msgs.Add($Message) }

        $ctx = [PSCustomObject]@{ DisplayWriter = { param($msg,$color,$no) $script:msgs.Add("DW: $msg") } }

        # Run in NonInteractive so it doesn't prompt
        $res = Format-Genres -InputObject $input -NonInteractive -Context $ctx -PassThru:$false -Force:$true

        # Expect some unmapped summary message
        $script:msgs | Should -Not -BeNullOrEmpty
        ($script:msgs -join "`n") | Should -Match 'Unmapped genres|Unmapped'
    }
}
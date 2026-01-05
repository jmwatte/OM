Describe 'New-OMContext' {
    BeforeAll {
        $pCandidates = @()
        if ($PSScriptRoot) { $pCandidates += Join-Path $PSScriptRoot '..\Utils\New-OMContext.ps1' }
        if ($MyInvocation.MyCommand.Path) { $pCandidates += Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\Utils\New-OMContext.ps1' }
        $pCandidates += Join-Path (Get-Location).Path 'Private\Utils\New-OMContext.ps1'
        $p = $pCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
        if (-not $p) { Throw "Helper not found: $p" }
        . $p
    }

    It 'creates a context with sensible defaults' {
        $ctx = New-OMContext
        $ctx | Should -Not -BeNullOrEmpty
        $ctx.InputReader | Should -BeOfType ScriptBlock
        $ctx.DisplayWriter | Should -BeOfType ScriptBlock
        $ctx.UseWhatIf | Should -BeFalse
        $ctx.NonInteractive | Should -BeFalse
        $ctx.Config | Should -Be $null
        ($ctx.AlbumCandidates -is [array]) | Should -BeTrue
    }

    It 'accepts overrides and returns provided values' {
        $reader = { param($p) return 'READER' }
        $display = { param($msg, $color) return "DISPLAY:$msg" }
        $ctx = New-OMContext -InputReader $reader -DisplayWriter $display -Provider 'Spotify' -UseWhatIf
        (& $ctx.InputReader 'prompt') | Should -Be 'READER'
        (& $ctx.DisplayWriter 'hi' 'Yellow') | Should -Be 'DISPLAY:hi'
        $ctx.Provider | Should -Be 'Spotify'
        $ctx.UseWhatIf | Should -BeTrue
    }
}

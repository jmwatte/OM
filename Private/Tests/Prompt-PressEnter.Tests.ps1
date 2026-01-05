Describe 'Prompt-PressEnter' {
    BeforeAll {
        $pCandidates = @()
        if ($PSScriptRoot) { $pCandidates += Join-Path $PSScriptRoot '..\Utils\Prompt-PressEnter.ps1' }
        if ($MyInvocation.MyCommand.Path) { $pCandidates += Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\Utils\Prompt-PressEnter.ps1' }
        $pCandidates += Join-Path (Get-Location).Path 'Private\Utils\Prompt-PressEnter.ps1'
        $p = $pCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
        if (-not $p) { Throw "Helper not found: $p" }
        . $p
    }

    It 'invokes InputReader when provided' {
        $reader = { param($p) return 'SENTINEL' }
        $res = Prompt-PressEnter -InputReader $reader
        $res | Should -Be 'SENTINEL'
    }

    It 'uses Read-Host when no InputReader is provided (mocked)' {
        Mock -CommandName Read-Host -MockWith { param($prompt) return '' }
        $res = Prompt-PressEnter
        $res | Should -Be ''
        Assert-MockCalled -CommandName Read-Host -Times 1
    }
}
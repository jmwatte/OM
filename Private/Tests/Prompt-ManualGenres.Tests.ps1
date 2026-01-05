Describe 'Prompt-ManualGenres' {
    BeforeAll {
        $pCandidates = @()
        if ($PSScriptRoot) { $pCandidates += Join-Path $PSScriptRoot '..\Utils\Prompt-ManualGenres.ps1' }
        if ($MyInvocation.MyCommand.Path) { $pCandidates += Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\Utils\Prompt-ManualGenres.ps1' }
        $pCandidates += Join-Path (Get-Location).Path 'Private\Utils\Prompt-ManualGenres.ps1'
        $p = $pCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
        if (-not $p) { Throw "Helper not found: $p" }
        . $p
    }

    It 'returns array when user enters genres' {
        $script:seq = @('e','rock, pop')
        $script:i = 0
        $reader = { param($prompt) $val = $script:seq[$script:i]; $script:i++; return $val }
        $res = Prompt-ManualGenres -Provider 'Spotify' -InputReader $reader
        $res.Count | Should -Be 2
        $res -join ',' | Should -Be 'rock,pop'
    }

    It 'returns null when user skips' {
        Mock -CommandName Read-Host -MockWith { param($Prompt) 's' }
        $res = Prompt-ManualGenres -Provider 'Spotify'
        $res | Should -Be $null
    }
}
Describe 'Show-OMPrompt' {
    BeforeAll {
        # Dot-source helper
        $pCandidates = @()
        if ($PSScriptRoot) { $pCandidates += Join-Path $PSScriptRoot '..\Utils\Show-OMPrompt.ps1' }
        if ($MyInvocation.MyCommand.Path) { $pCandidates += Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\Utils\Show-OMPrompt.ps1' }
        $pCandidates += Join-Path (Get-Location).Path 'Private\Utils\Show-OMPrompt.ps1'
        $p = $pCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
        if (-not $p) { Throw "Helper not found at runtime: $p" }
        . $p
    }

    It 'returns default when input is empty' {
        Mock -CommandName Read-Host -MockWith { return '' }
        $res = Show-OMPrompt -Prompt 'Artist' -Default 'DefaultArtist'
        $res | Should -Be 'DefaultArtist'
    }

    It 'returns user input when provided' {
        Mock -CommandName Read-Host -MockWith { return 'UserArtist' }
        $res = Show-OMPrompt -Prompt 'Artist' -Default 'DefaultArtist'
        $res | Should -Be 'UserArtist'
    }

    It 'supports NoNewline behavior and returns default on empty' {
        Mock -CommandName Read-Host -MockWith { return '' }
        $res = Show-OMPrompt -Prompt 'Album' -Default 'DefaultAlbum' -NoNewline
        $res | Should -Be 'DefaultAlbum'
    }
}
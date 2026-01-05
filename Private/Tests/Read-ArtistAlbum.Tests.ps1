Describe 'Read-ArtistAlbum' {
    BeforeAll {
        # Dot-source helper under test and the prompt helper
        $pCandidates = @()
        if ($PSScriptRoot) { $pCandidates += Join-Path $PSScriptRoot '..\Utils\Prompt-NewArtistAlbum.ps1' }
        if ($MyInvocation.MyCommand.Path) { $pCandidates += Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\Utils\Prompt-NewArtistAlbum.ps1' }
        $pCandidates += Join-Path (Get-Location).Path 'Private\Utils\Prompt-NewArtistAlbum.ps1'
        $p = $pCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
        if (-not $p) { Throw "Helper not found at runtime: $p" }
        . $p

        # Dot-source the centralized prompt helper
        $promptHelper = Join-Path (Split-Path -Parent $p) 'Show-OMPrompt.ps1'
        if (Test-Path $promptHelper) { . $promptHelper }
    }

    It 'returns defaults when prompt returns empty' {
        Mock -CommandName Show-OMPrompt -MockWith { return '' }
        $res = Read-ArtistAlbum -DefaultArtist 'DefA' -DefaultAlbum 'DefB'
        $res.Artist | Should -Be 'DefA'
        $res.Album | Should -Be 'DefB'
        $res.ChangedArtist | Should -BeFalse
        $res.ChangedAlbum | Should -BeFalse
    }

    It 'returns values when prompt provides input' {
        # first call returns artist, second call returns album
        $call = 0
        Mock -CommandName Show-OMPrompt -MockWith { $script:call++; if ($script:call -eq 1) { return 'UserA' } else { return 'UserB' } }
        $res = Read-ArtistAlbum -DefaultArtist 'DefA' -DefaultAlbum 'DefB'
        $res.Artist | Should -Be 'UserA'
        $res.Album | Should -Be 'UserB'
        $res.ChangedArtist | Should -BeTrue
        $res.ChangedAlbum | Should -BeTrue
    }

    It 'trims whitespace from input' {
        Mock -CommandName Show-OMPrompt -MockWith { return '  Some Artist  ' }
        # second call returns empty to preserve default album
        $second = 0
        Mock -CommandName Show-OMPrompt -MockWith { if ($script:second++) { return '' } else { return '  Some Artist  ' } }
        $res = Read-ArtistAlbum -DefaultArtist 'D' -DefaultAlbum 'DA'
        $res.Artist | Should -Be 'Some Artist'
    }
}
Describe 'ConvertFrom-AlbumSelectionChoice' {
    BeforeAll {
        $pCandidates = @()
        if ($PSScriptRoot) { $pCandidates += Join-Path $PSScriptRoot '..\Utils\ConvertFrom-AlbumSelectionChoice.ps1' }
        if ($MyInvocation.MyCommand.Path) { $pCandidates += Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\Utils\ConvertFrom-AlbumSelectionChoice.ps1' }
        $pCandidates += Join-Path (Get-Location).Path 'Private\Utils\ConvertFrom-AlbumSelectionChoice.ps1'
        $p = $pCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
        if (-not $p) { Throw "Helper not found: $p" }
        . $p
    }

    It 'parses numeric choice' {
        $r = ConvertFrom-AlbumSelectionChoice -Choice '3' -MaxIndex 10
        $r.Command | Should -Be 'Number'
        $r.Number | Should -Be 3
    }

    It 'rejects out-of-range numeric choice' {
        $r = ConvertFrom-AlbumSelectionChoice -Choice '99' -MaxIndex 5
        $r.Command | Should -Be 'Invalid'
        $r.Error | Should -Match 'out of range'
    }

    It 'parses provider shortcodes' {
        $r = ConvertFrom-AlbumSelectionChoice -Choice 'ps'
        $r.Command | Should -Be 'SwitchProvider'
        $r.Provider | Should -Be 'Spotify'

        $r2 = ConvertFrom-AlbumSelectionChoice -Choice 'p'
        $r2.Command | Should -Be 'Provider'
    }

    It 'parses cover and cover original commands' {
        $r = ConvertFrom-AlbumSelectionChoice -Choice 'cv2'
        $r.Command | Should -Be 'Cover'
        $r.RangeText | Should -Be '2'

        $r2 = ConvertFrom-AlbumSelectionChoice -Choice 'cvo'
        $r2.Command | Should -Be 'CoverOriginal'
        $r2.RangeText | Should -Be '1'
    }

    It 'parses cs and ct commands with default range' {
        $r = ConvertFrom-AlbumSelectionChoice -Choice 'cs'
        $r.Command | Should -Be 'SaveToFolder'
        $r.RangeText | Should -Be '1'

        $r2 = ConvertFrom-AlbumSelectionChoice -Choice 'ct3'
        $r2.Command | Should -Be 'EmbedInTags'
        $r2.RangeText | Should -Be '3'
    }

    It 'handles non-command text as Text' {
        $r = ConvertFrom-AlbumSelectionChoice -Choice 'search term'
        $r.Command | Should -Be 'Text'
        $r.RangeText | Should -Be 'search term'
    }
}
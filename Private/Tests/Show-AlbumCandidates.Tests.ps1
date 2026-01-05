Describe 'Show-AlbumCandidates' {
    BeforeAll {
        $pCandidates = @()
        if ($PSScriptRoot) { $pCandidates += Join-Path $PSScriptRoot '..\Utils\Show-AlbumCandidates.ps1' }
        if ($MyInvocation.MyCommand.Path) { $pCandidates += Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\Utils\Show-AlbumCandidates.ps1' }
        $pCandidates += Join-Path (Get-Location).Path 'Private\Utils\Show-AlbumCandidates.ps1'
        $p = $pCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
        if (-not $p) { Throw "Helper not found: $p" }
        . $p

        # Ensure helper deps
        $g = Join-Path (Split-Path -Parent $p) '..\Get-IfExists.ps1'
        if (Test-Path $g) { . $g }
    }

    It 'prints album lines for each candidate' {
        $albums = @(
            @{ name = 'One'; id = '1'; artists = @(@{ name = 'A' }); release_date = '2001'; total_tracks = 10 },
            @{ name = 'Two'; id = '2'; artists = @(@{ name = 'B' }); release_date = '2002' }
        )

        $lines = Show-AlbumCandidates -AlbumCandidates $albums

        $lines.Count | Should -Be 2
        $lines[0] | Should -Match '\[1\] One - A \(id: 1\) \(year: 2001\) \(10 tracks\)'
        $lines[1] | Should -Match '\[2\] Two - B \(id: 2\) \(year: 2002\)'

    }
}
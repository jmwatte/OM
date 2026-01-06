Describe 'Set-PairedTracks' {
    BeforeAll {
        $pCandidates = @()
        if ($PSScriptRoot) { $pCandidates += Join-Path $PSScriptRoot '..\Utils\Set-PairedTracks.ps1' }
        if ($MyInvocation.MyCommand.Path) { $pCandidates += Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\Utils\Set-PairedTracks.ps1' }
        $pCandidates += Join-Path (Get-Location).Path 'Private\Utils\Set-PairedTracks.ps1'
        $p = $pCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
        if (-not $p) { Throw "Helper not found: $p" }
        . $p

        # Ensure Expand-SelectionRange is available (dot-source similar to other tests)
        $xCandidates = @()
        if ($PSScriptRoot) { $xCandidates += Join-Path $PSScriptRoot '..\Utils\Expand-SelectionRange.ps1' }
        if ($MyInvocation.MyCommand.Path) { $xCandidates += Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\Utils\Expand-SelectionRange.ps1' }
        $xCandidates += Join-Path (Get-Location).Path 'Private\Utils\Expand-SelectionRange.ps1'
        $x = $xCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($x) { . $x }
    }

    It 'marks a single track' {
        $p = @([
            PSCustomObject]@{ SpotifyTrack = $null; AudioFile = $null }, [PSCustomObject]@{ SpotifyTrack = $null; AudioFile = $null })
        $count = Set-PairedTracks -PairedTracks $p -RangeText '1'
        $count | Should -Be 1
        $p[0].PSObject.Properties.Match('Marked') | Should -Not -Be $null
        $p[0].Marked | Should -Be $true
    }

    It 'marks a range of tracks' {
        $p = @([PSCustomObject]@{}, [PSCustomObject]@{}, [PSCustomObject]@{})
        $count = Set-PairedTracks -PairedTracks $p -RangeText '1-2'
        $count | Should -Be 2
        $p[1].Marked | Should -Be $true
    }

    It 'throws on invalid range' {
        $p = @([PSCustomObject]@{}, [PSCustomObject]@{})
        { Set-PairedTracks -PairedTracks $p -RangeText '99' } | Should -Throw
    }
}
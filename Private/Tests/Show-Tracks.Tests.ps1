Describe 'Show-Tracks' {
    BeforeAll {
        $pCandidates = @()
        if ($PSScriptRoot) { $pCandidates += Join-Path $PSScriptRoot '..\Utils\Show-Tracks.ps1' }
        if ($MyInvocation.MyCommand.Path) { $pCandidates += Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\Utils\Show-Tracks.ps1' }
        $pCandidates += Join-Path (Get-Location).Path 'Private\Utils\Show-Tracks.ps1'
        $p = $pCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
        if (-not $p) { Throw "Helper not found: $p" }
        . $p

        # Ensure helper deps
        $x = Join-Path (Split-Path -Parent $p) '..\Expand-SelectionRange.ps1'
        if (Test-Path $x) { . $x }
        $g = Join-Path (Split-Path -Parent $p) '..\Get-IfExists.ps1'
        if (Test-Path $g) { . $g }

        Mock -CommandName Start-Sleep -MockWith { }
        Mock -CommandName Clear-Host -MockWith { }
    }

    It 'returns null when no tracks and Enter pressed' {
        $reader = { param($prompt) return '' }
        $res = Show-Tracks -PairedTracks @() -AlbumName 'NoTracks' -InputReader $reader
        $res | Should -Be $null
    }



    It 'returns command when ValidCommands include rm and user enters rm' {
        $pair = [PSCustomObject]@{ SpotifyTrack = [PSCustomObject]@{ name = 't' }; AudioFile = [PSCustomObject]@{ FilePath = 'C:\1.mp3' } }
        $reader = { param($prompt) return 'rm' }
        $res = Show-Tracks -PairedTracks @($pair) -AlbumName 'CmdTest' -ValidCommands @('rm') -InputReader $reader
        $res | Should -Be 'rm'
    }
}
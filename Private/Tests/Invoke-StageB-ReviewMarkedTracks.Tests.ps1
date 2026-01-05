Describe 'Invoke-StageB-ReviewMarkedTracks' {
    BeforeAll {
        $pCandidates = @()
        if ($PSScriptRoot) { $pCandidates += Join-Path $PSScriptRoot '..\Utils\Invoke-StageB-ReviewMarkedTracks.ps1' }
        if ($MyInvocation.MyCommand.Path) { $pCandidates += Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\Utils\Invoke-StageB-ReviewMarkedTracks.ps1' }
        $pCandidates += Join-Path (Get-Location).Path 'Private\Utils\Invoke-StageB-ReviewMarkedTracks.ps1'
        $p = $pCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
        if (-not $p) { Throw "Helper not found: $p" }
        . $p

        # Ensure helper deps
        $g = Join-Path (Split-Path -Parent $p) '..\Get-IfExists.ps1'
        if (Test-Path $g) { . $g }
        $m = Join-Path (Split-Path -Parent $p) '..\Mark-PairedTracks.ps1'
        if (Test-Path $m) { . $m }

        Mock -CommandName Start-Sleep -MockWith { }
        Mock -CommandName Clear-Host -MockWith { }
        if (-not (Get-Command Get-MatchConfidence -ErrorAction SilentlyContinue)) { function Get-MatchConfidence { param($ProviderTrack,$AudioFile) return [PSCustomObject]@{ Score = 100; Level = 'High' } } }
    }

    It 'returns NoProviderTracks when no audio files' {
        $pairs = @()
        $tracks = @()
        $res = Invoke-StageB-ReviewMarkedTracks -PairedTracks $pairs -TracksForAlbum $tracks -InputReader { param($prompt) return '1' }
        $res.NoProviderTracks | Should -BeTrue
    }

    It 'updates paired track when selection made' {
        $audio = [PSCustomObject]@{ FilePath = 'C:\1.mp3'; Duration = 1000 }
        $provider = @([PSCustomObject]@{ name = 'p1'; track_number = 1; disc_number = 1; duration_ms = 1000 })
        $pair = [PSCustomObject]@{ AudioFile = $audio; SpotifyTrack = $provider[0]; Marked = $true }

        $inputs = @('1')
        $i = 0
        $reader = { param($prompt) $val = $inputs[$i]; $i++; return $val }

        $res = Invoke-StageB-ReviewMarkedTracks -PairedTracks @($pair) -TracksForAlbum $provider -InputReader $reader
        $res.Updated | Should -Be 1
        $pair.SpotifyTrack.name | Should -Be 'p1'
    }
}
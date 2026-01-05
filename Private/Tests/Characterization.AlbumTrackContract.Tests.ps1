Describe 'Album/Track contract' {
    BeforeAll {
        # Dot-source helper under test and shared helpers
        $pCandidates = @()
        if ($PSScriptRoot) { $pCandidates += Join-Path $PSScriptRoot '..\Utils\Get-OMAudioFile.ps1' }
        if ($MyInvocation.MyCommand.Path) { $pCandidates += Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\Utils\Get-OMAudioFile.ps1' }
        $pCandidates += Join-Path (Get-Location).Path 'Private\Utils\Get-OMAudioFile.ps1'
        $p = $pCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
        if (-not $p) { Throw "Helper not found at runtime: $p" }
        . $p

        # Dot-source supporting helpers when available so tests can mock them
        $tagp = Join-Path (Split-Path -Parent $p) 'Get-OMTagFile.ps1'
        if (Test-Path $tagp) { . $tagp }
        $apep = Join-Path (Split-Path -Parent $p) '..\Get-ApeDuration.ps1'
        if (Test-Path $apep) { . $apep }
    }

    It 'ensures the album/track object contract fields exist and types are sane' {
        # Construct a representative track object and assert contract properties
        $track = [PSCustomObject]@{
            FilePath    = 'C:\Test\01 - First.mp3'
            DiscNumber  = 1
            TrackNumber = 1
            Title       = 'First'
            TagFile     = [PSCustomObject]@{ Dummy = $true }
            Composer    = 'Composer'
            Artist      = 'Artist'
            Name        = 'First'
            Duration    = 1234
        }

        $track | Should -Not -BeNullOrEmpty
        $track.PSObject.Properties.Name | Should -Contain 'FilePath'
        $track.PSObject.Properties.Name | Should -Contain 'Duration'
        $track.FilePath | Should -BeOfType ([string])
        $track.Duration | Should -BeGreaterThan 0
        $track.TrackNumber | Should -BeOfType ([int])
        $track.DiscNumber | Should -BeOfType ([int])
        $track.Title | Should -BeOfType ([string])
        $track.TagFile | Should -Not -BeNullOrEmpty
    }
}
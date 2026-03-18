$helperPath = Join-Path $PSScriptRoot '..\Utils\Get-AlbumMatchConfidence.ps1'
if (-not (Test-Path $helperPath)) { Throw "Helper not found: $helperPath" }

# Also require Get-StringSimilarity helper
$simPath = Join-Path $PSScriptRoot '..\Utils\Get-StringSimilarity.ps1'

Describe 'Get-AlbumMatchConfidence' {
    BeforeAll {
        # Ensure local Get-StringSimilarity supersedes any external command
        if (Get-Command Get-StringSimilarity -ErrorAction SilentlyContinue) { Remove-Item Function:\Get-StringSimilarity -ErrorAction SilentlyContinue }
        $p = Join-Path $PSScriptRoot '..\Utils\Get-AlbumMatchConfidence.ps1'
        if (-not (Test-Path $p)) { Throw "Helper not found: $p" }
        . $p
        $s = Join-Path $PSScriptRoot '..\Utils\Get-StringSimilarity.ps1'
        if (-not (Test-Path $s)) { Throw "Helper not found: $s" }
        . $s
        # Ensure the Function: provider uses the dot-sourced implementation
        $sb = (Get-Command Get-StringSimilarity -ErrorAction SilentlyContinue).ScriptBlock
        if ($sb) { Set-Item Function:\Get-StringSimilarity -Value $sb }
        $i = Join-Path $PSScriptRoot '..\Get-IfExists.ps1'
        if (-not (Test-Path $i)) { Throw "Helper not found: $i" }
        . $i
    }

    It 'loads the helper and defines a function' {
        (Get-Command Get-AlbumMatchConfidence -ErrorAction SilentlyContinue) | Should -Not -Be $null
        (Get-Command Get-AlbumMatchConfidence -ErrorAction SilentlyContinue).CommandType | Should -Be 'Function'
    }

    It 'has the expected parameters' {
        $cmd = Get-Command Get-AlbumMatchConfidence -ErrorAction SilentlyContinue
        $cmd.Parameters.Keys | Should -Contain 'Candidate'
        $cmd.Parameters.Keys | Should -Contain 'LocalArtist'
        $cmd.Parameters.Keys | Should -Contain 'LocalAlbum'
        $cmd.Parameters.Keys | Should -Contain 'LocalTrackCount'
    }

    It 'extracts artist from single-element artists array (pipeline-unwrapped PSCustomObject)' {
        # Simulate what Normalize-AlbumResult produces: artists = @([PSCustomObject]@{name='X'})
        # When Get-IfExists returns this, PowerShell pipeline unwraps it to a bare PSCustomObject
        $candidate = [PSCustomObject]@{
            name        = 'Beyond Painting'
            artists     = @([PSCustomObject]@{ name = 'Robert Turman' })
            track_count = 7
        }
        $score = Get-AlbumMatchConfidence -Candidate $candidate `
            -LocalArtist 'Robert Turman' -LocalAlbum 'Beyond Painting' -LocalTrackCount 7
        # Perfect match on all 3 axes: artist=1.0*0.3 + album=1.0*0.4 + tracks=1.0*0.3 = 1.0
        $score | Should -BeGreaterOrEqual 0.99
    }

    It 'extracts artist from bare artist string property' {
        # Discogs-style candidate with artist as plain string (no artists array)
        $candidate = [PSCustomObject]@{
            name        = 'Dark Side of the Moon'
            artist      = 'Pink Floyd'
            track_count = 10
        }
        $score = Get-AlbumMatchConfidence -Candidate $candidate `
            -LocalArtist 'Pink Floyd' -LocalAlbum 'Dark Side of the Moon' -LocalTrackCount 10
        $score | Should -BeGreaterOrEqual 0.99
    }

    It 'scores above threshold even when album name includes artist (Album - Artist pattern)' {
        $candidate = [PSCustomObject]@{
            name        = 'Beyond Painting'
            artists     = @([PSCustomObject]@{ name = 'Robert Turman' })
            track_count = 7
        }
        # Local album still has "Beyond Painting - Robert Turman" (not yet cleaned)
        $score = Get-AlbumMatchConfidence -Candidate $candidate `
            -LocalArtist 'Robert Turman' -LocalAlbum 'Beyond Painting - Robert Turman' -LocalTrackCount 7
        # Artist=1.0*0.3=0.3, Album~0.52*0.4~0.21, Tracks=1.0*0.3=0.3 => ~0.81
        $score | Should -BeGreaterOrEqual 0.70
    }
}

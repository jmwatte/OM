$helperPath = Join-Path $PSScriptRoot '..\Utils\Get-BestAutoMatch.ps1'
if (-not (Test-Path $helperPath)) { Throw "Helper not found: $helperPath" }

# Require album confidence and string similarity helpers
$confPath = Join-Path $PSScriptRoot '..\Utils\Get-AlbumMatchConfidence.ps1'
$simPath = Join-Path $PSScriptRoot '..\Utils\Get-StringSimilarity.ps1'

Describe 'Get-BestAutoMatch' {
    BeforeAll {
        # Ensure local Get-StringSimilarity supersedes any external command
        if (Get-Command Get-StringSimilarity -ErrorAction SilentlyContinue) { Remove-Item Function:\Get-StringSimilarity -ErrorAction SilentlyContinue }
        $p = Join-Path $PSScriptRoot '..\Utils\Get-BestAutoMatch.ps1'
        if (-not (Test-Path $p)) { Throw "Helper not found: $p" }
        . $p
        $c = Join-Path $PSScriptRoot '..\Utils\Get-AlbumMatchConfidence.ps1'
        if (-not (Test-Path $c)) { Throw "Helper not found: $c" }
        . $c
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

    It 'returns null when no candidate meets threshold' {
        $candidates = @(
            @{ name = 'Far Away'; artists = @(@{ name = 'Other' }); total_tracks = 5 },
            @{ name = 'Another'; artists = @(@{ name = 'Someone' }); total_tracks = 6 }
        )
        $res = Get-BestAutoMatch $candidates 'Artist' 'Album' 10 0.7
        $res | Should -Be $null
    }

    It 'loads the helper and defines a function' {
        (Get-Command Get-BestAutoMatch -ErrorAction SilentlyContinue) | Should -Not -Be $null
        (Get-Command Get-BestAutoMatch -ErrorAction SilentlyContinue).CommandType | Should -Be 'Function'
    }

    It 'has the expected parameters' {
        $cmd = Get-Command Get-BestAutoMatch -ErrorAction SilentlyContinue
        $cmd.Parameters.Keys | Should -Contain 'Candidates'
        $cmd.Parameters.Keys | Should -Contain 'LocalArtist'
        $cmd.Parameters.Keys | Should -Contain 'LocalAlbum'
        $cmd.Parameters.Keys | Should -Contain 'LocalTrackCount'
        $cmd.Parameters.Keys | Should -Contain 'Threshold'
    }
}

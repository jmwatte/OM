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
}

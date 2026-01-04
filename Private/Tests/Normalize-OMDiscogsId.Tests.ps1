$p = Join-Path $PSScriptRoot '..\Utils\Normalize-OMDiscogsId.ps1'
if (-not (Test-Path $p)) { Throw "Helper not found: $p" }

Describe 'Normalize-OMDiscogsId' {
    BeforeAll {
        if (Get-Command Normalize-OMDiscogsId -ErrorAction SilentlyContinue) { Remove-Item Function:\Normalize-OMDiscogsId -ErrorAction SilentlyContinue }
        $p = Join-Path $PSScriptRoot '..\Utils\Normalize-OMDiscogsId.ps1'
        if (-not (Test-Path $p)) { Throw "Helper not found: $p" }
        . $p
        $sb = (Get-Command Normalize-OMDiscogsId -ErrorAction SilentlyContinue).ScriptBlock
        if ($sb) { Set-Item Function:\Normalize-OMDiscogsId -Value $sb }
    }

    It 'removes surrounding brackets' {
        Normalize-OMDiscogsId '[r2388472]' | Should -Be 'r2388472'
        Normalize-OMDiscogsId '[m1764178]' | Should -Be 'm1764178'
    }

    It 'trims whitespace' {
        Normalize-OMDiscogsId '  r12345  ' | Should -Be 'r12345'
    }

    It 'returns unchanged id if already normalized' {
        Normalize-OMDiscogsId 'r12345' | Should -Be 'r12345'
    }


}
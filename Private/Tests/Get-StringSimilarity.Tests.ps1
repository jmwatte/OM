$helperPath = Join-Path $PSScriptRoot '..\Utils\Get-StringSimilarity.ps1'
if (-not (Test-Path $helperPath)) { Throw "Helper not found: $helperPath" }

Describe 'Get-StringSimilarity' {
    BeforeAll {
        # Remove any conflicting Get-StringSimilarity from other modules and dot-source the local helper
        if (Get-Command Get-StringSimilarity -ErrorAction SilentlyContinue) { Remove-Item Function:\Get-StringSimilarity -ErrorAction SilentlyContinue }
        $p = Join-Path $PSScriptRoot '..\Utils\Get-StringSimilarity.ps1'
        if (-not (Test-Path $p)) { Throw "Helper not found: $p" }
        . $p
        # Ensure the Function: provider uses the dot-sourced implementation
        $sb = (Get-Command Get-StringSimilarity -ErrorAction SilentlyContinue).ScriptBlock
        if ($sb) { Set-Item Function:\Get-StringSimilarity -Value $sb }
    }

    It 'returns 1.0 for identical strings' {
        Get-StringSimilarity 'Hello' 'Hello' | Should -Be 1.0
    }

    It 'is case-insensitive and ignores punctuation' {
        Get-StringSimilarity 'TRON: Legacy' 'TRON_ Legacy' | Should -Be 1.0
    }

    It 'returns 0.0 when either input is empty or null' {
        Get-StringSimilarity $null 'Hello' | Should -Be 0.0
        Get-StringSimilarity '' '' | Should -Be 0.0
    }

    It 'returns a value between 0 and 1 for similar strings' {
        $val = Get-StringSimilarity 'Hello' 'Helo'
        $val | Should -BeGreaterThan 0.0
        $val | Should -BeLessThanOrEqual 1.0
    }
}

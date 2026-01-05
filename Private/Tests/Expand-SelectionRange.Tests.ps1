Describe 'Expand-SelectionRange' {
    BeforeAll {
        $pCandidates = @()
        if ($PSScriptRoot) { $pCandidates += Join-Path $PSScriptRoot '..\Utils\Expand-SelectionRange.ps1' }
        if ($MyInvocation.MyCommand.Path) { $pCandidates += Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\Utils\Expand-SelectionRange.ps1' }
        $pCandidates += Join-Path (Get-Location).Path 'Private\Utils\Expand-SelectionRange.ps1'
        $p = $pCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
        if (-not $p) { Throw "Helper not found at runtime: $p" }
        . $p
    }

    It 'returns empty for empty input' {
        (Expand-SelectionRange -RangeText '' -MaxIndex 10).Count | Should -Be 0
    }

    It 'parses single numbers and returns them' {
        $res = Expand-SelectionRange -RangeText '3' -MaxIndex 5
        $res | Should -Be @('3')
    }

    It 'parses comma separated values and deduplicates and sorts' {
        $res = Expand-SelectionRange -RangeText '3,1,2,3' -MaxIndex 10
        $res | Should -Be @(1,2,3)
    }

    It 'parses ranges with dash and inclusive endpoints' {
        $res = Expand-SelectionRange -RangeText '2-4' -MaxIndex 6
        $res | Should -Be @(2,3,4)
    }

    It 'parses ranges with .. syntax' {
        $res = Expand-SelectionRange -RangeText '5..7' -MaxIndex 10
        $res | Should -Be @(5,6,7)
    }

    It 'handles reversed ranges by normalizing to ascending' {
        $res = Expand-SelectionRange -RangeText '8-6' -MaxIndex 10
        $res | Should -Be @(6,7,8)
    }

    It 'throws on out-of-range single value' {
        { Expand-SelectionRange -RangeText '11' -MaxIndex 10 } | Should -Throw
    }

    It 'throws on out-of-range range' {
        { Expand-SelectionRange -RangeText '8-12' -MaxIndex 10 } | Should -Throw
    }

    It 'throws on unrecognized segment' {
        { Expand-SelectionRange -RangeText 'a' -MaxIndex 10 } | Should -Throw
    }
}
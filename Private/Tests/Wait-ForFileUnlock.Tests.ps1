Describe 'Wait-ForFileUnlock' {
    BeforeAll {
        $pCandidates = @()
        if ($PSScriptRoot) { $pCandidates += Join-Path $PSScriptRoot '..\Wait-ForFileUnlock.ps1' }
        if ($MyInvocation.MyCommand.Path) { $pCandidates += Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\Wait-ForFileUnlock.ps1' }
        $pCandidates += Join-Path (Get-Location).Path 'Private\Wait-ForFileUnlock.ps1'
        $p = $pCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
        if (-not $p) { Throw "Helper not found: $p" }
        . $p

        # Ensure Assert-FileLocked helper is available for mocking
        $aCandidates = @()
        if ($PSScriptRoot) { $aCandidates += Join-Path $PSScriptRoot '..\Assert-FileLocked.ps1' }
        if ($MyInvocation.MyCommand.Path) { $aCandidates += Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\Assert-FileLocked.ps1' }
        $aCandidates += Join-Path (Get-Location).Path 'Private\Assert-FileLocked.ps1'
        $a = $aCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
        if (-not $a) { Throw "Helper not found: $a" }
        . $a

        # Ensure New-OMContext is available for Context-based tests
        $cCandidates = @()
        if ($PSScriptRoot) { $cCandidates += Join-Path $PSScriptRoot '..\Utils\New-OMContext.ps1' }
        if ($MyInvocation.MyCommand.Path) { $cCandidates += Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\Utils\New-OMContext.ps1' }
        $cCandidates += Join-Path (Get-Location).Path 'Private\Utils\New-OMContext.ps1'
        $c = $cCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
        if (-not $c) { Throw "Helper not found: $c" }
        . $c

        # Ensure Show-OMPrompt is available
        $sCandidates = @()
        if ($PSScriptRoot) { $sCandidates += Join-Path $PSScriptRoot '..\Utils\Show-OMPrompt.ps1' }
        if ($MyInvocation.MyCommand.Path) { $sCandidates += Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\Utils\Show-OMPrompt.ps1' }
        $sCandidates += Join-Path (Get-Location).Path 'Private\Utils\Show-OMPrompt.ps1'
        $s = $sCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
        if (-not $s) { Throw "Helper not found: $s" }
        . $s
    }

    It 'returns skip when file missing' {
        $res = Wait-ForFileUnlock -Path (Join-Path $env:TEMP 'nonexistent-file.txt') -RetryIntervalSeconds 0
        $res.Action | Should -Be 'skip'
        $res.Unlocked | Should -BeFalse
    }

    It 'uses Context.InputReader to select skip' {
        # Create a temp file and mock Assert-FileLocked to always true for this test
        $f = [IO.Path]::GetTempFileName()
        Mock -CommandName Assert-FileLocked -MockWith { return $true } -Verifiable
        $ctx = New-OMContext -InputReader { param($p) return 'skip' }
        $res = Wait-ForFileUnlock -Path $f -RetryIntervalSeconds 0 -Context $ctx
        $res.Action | Should -Be 'skip'
        Remove-Item $f -Force
    }
}
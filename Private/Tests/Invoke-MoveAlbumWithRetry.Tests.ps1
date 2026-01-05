Write-Verbose "TOP: PSScriptRoot=[$PSScriptRoot] CWD=[$(Get-Location)]"


Describe 'Invoke-MoveAlbumWithRetry' {
    BeforeAll {
        Write-Host "[INVOKE-RETRY-TEST] BeforeAll start"
        # compute helper path candidates in this runspace
        $pCandidates = @()
        if ($PSScriptRoot) { $pCandidates += Join-Path $PSScriptRoot '..\Utils\Invoke-MoveAlbumWithRetry.ps1' }
        if ($MyInvocation.MyCommand.Path) { $pCandidates += Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\Utils\Invoke-MoveAlbumWithRetry.ps1' }
        $pCandidates += Join-Path (Get-Location).Path 'Private\Utils\Invoke-MoveAlbumWithRetry.ps1'
        $pCandidates += Join-Path (Join-Path (Get-Location).Path '..') 'Private\Utils\Invoke-MoveAlbumWithRetry.ps1'
        foreach ($c in $pCandidates | Select-Object -Unique) { Write-Host "Candidate: $c -> Exists: $(Test-Path $c)" }
        $p = $pCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
        if (-not $p) { Throw "Helper not found: candidates: $($pCandidates -join ', ')" }
        Write-Host "[INVOKE-RETRY-TEST] Dot-sourcing helper: $p"
        . $p
        Write-Host "[INVOKE-RETRY-TEST] BeforeAll end"
    }

    It 'returns move result when Move-AlbumFolder succeeds on first attempt' {
        . $p
        function Move-AlbumFolder { param($WhatIf) return @{ Success = $true; NewAlbumPath = 'C:\new' } }
        $res = Invoke-MoveAlbumWithRetryCore -mvArgs @{ Foo = 'Bar' } -UseWhatIf:$false -OnRetry { param($e) return }
        $res | Should -Not -Be $null
        $res.Success | Should -Be $true
    }

    It 'retries when Move-AlbumFolder fails once and then succeeds' {
        . $p
        $script:calls = 0
        function Move-AlbumFolder {
            $script:calls++
            if ($script:calls -lt 2) { throw 'Locked' }
            return @{ Success = $true; NewAlbumPath = 'C:\new' }
        }
        $script:retryCalled = 0
        $onRetry = { param($e) $script:retryCalled++; return }

        $res = Invoke-MoveAlbumWithRetryCore -mvArgs @{ Foo = 'Bar' } -UseWhatIf:$false -OnRetry $onRetry
        $res | Should -Not -Be $null
        $script:retryCalled | Should -Be 1
    }

    It 'returns null when Move-AlbumFolder keeps failing and OnRetry requests skip' {
        . $p
        function Move-AlbumFolder { throw 'Locked' }
        $onRetry = { param($e) return 's' }
        $res = Invoke-MoveAlbumWithRetryCore -mvArgs @{ Foo = 'Bar' } -UseWhatIf:$false -OnRetry $onRetry
        $res | Should -Be $null
    }

    It 'returns null immediately when AutoSkip is enabled' {
        . $p
        function Move-AlbumFolder { throw 'Locked' }
        $res = Invoke-MoveAlbumWithRetryCore -mvArgs @{ Foo = 'Bar' } -UseWhatIf:$false -AutoSkip
        $res | Should -Be $null
    }

    It 'gives up after MaxRetries when OnRetry does not request skip' {
        . $p
        $script:calls = 0
        function Move-AlbumFolder {
            $script:calls++
            throw 'Locked'
        }
        $onRetry = { param($e) return }

        $res = Invoke-MoveAlbumWithRetryCore -mvArgs @{ Foo = 'Bar' } -UseWhatIf:$false -OnRetry $onRetry -MaxRetries 3
        $res | Should -Be $null
        $script:calls | Should -Be 3
    }
}

Write-Verbose "TOP: PSScriptRoot=[$PSScriptRoot] CWD=[$(Get-Location)]"
$p = Join-Path $PSScriptRoot '..\Utils\Invoke-MoveAlbumWithRetry.ps1'
if (-not (Test-Path $p)) { Throw "Helper not found: $p" }

Describe 'Invoke-MoveAlbumWithRetry' {
    BeforeAll {
        Write-Verbose "DEBUG: helper path=[$p]"
        if (-not (Test-Path $p)) { Throw "Helper not found: $p" }
        . $p
    }

    It 'returns move result when Move-AlbumFolder succeeds on first attempt' {
        function Move-AlbumFolder { param($WhatIf) return @{ Success = $true; NewAlbumPath = 'C:\new' } }
        $res = Invoke-MoveAlbumWithRetryCore -mvArgs @{ Foo = 'Bar' } -UseWhatIf:$false -OnRetry { param($e) return }
        $res | Should -Not -Be $null
        $res.Success | Should -Be $true
    }

    It 'retries when Move-AlbumFolder fails once and then succeeds' {
        $calls = 0
        function Move-AlbumFolder {
            $calls++
            if ($calls -lt 2) { throw 'Locked' }
            return @{ Success = $true; NewAlbumPath = 'C:\new' }
        }
        $retryCalled = 0
        $onRetry = { param($e) $script:retryCalled++; return }

        $res = Invoke-MoveAlbumWithRetryCore -mvArgs @{ Foo = 'Bar' } -UseWhatIf:$false -OnRetry $onRetry
        $res | Should -Not -Be $null
        $retryCalled | Should -Be 1
    }

    It 'returns null when Move-AlbumFolder keeps failing and OnRetry requests skip' {
        function Move-AlbumFolder { throw 'Locked' }
        $onRetry = { param($e) return 's' }
        $res = Invoke-MoveAlbumWithRetryCore -mvArgs @{ Foo = 'Bar' } -UseWhatIf:$false -OnRetry $onRetry
        $res | Should -Be $null
    }

    It 'returns null immediately when AutoSkip is enabled' {
        function Move-AlbumFolder { throw 'Locked' }
        $res = Invoke-MoveAlbumWithRetryCore -mvArgs @{ Foo = 'Bar' } -UseWhatIf:$false -AutoSkip
        $res | Should -Be $null
    }
}

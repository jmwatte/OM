Describe 'Invoke-MoveAlbumWithRetry' {
    BeforeAll {
        $p = Join-Path $PSScriptRoot '..\Utils\Invoke-MoveAlbumWithRetry.ps1'
        if (-not (Test-Path $p)) { Throw "Helper not found: $p" }
        . $p
        # Stub so Pester Mock can intercept calls from Invoke-MoveAlbumWithRetryCore
        function Move-AlbumFolder {
            [CmdletBinding(SupportsShouldProcess)]
            param()
        }
    }

    It 'returns move result when Move-AlbumFolder succeeds on first attempt' {
        Mock Move-AlbumFolder { @{ Success = $true; NewAlbumPath = 'C:\new' } }
        $res = Invoke-MoveAlbumWithRetryCore -mvArgs @{} -UseWhatIf:$false
        $res | Should -Not -Be $null
        $res.Success | Should -Be $true
    }

    It 'retries when Move-AlbumFolder fails once and then succeeds' {
        $script:retryState = @{ Calls = 0; RetryCalled = 0 }
        Mock Move-AlbumFolder {
            $script:retryState.Calls++
            if ($script:retryState.Calls -lt 2) { throw 'Locked' }
            @{ Success = $true; NewAlbumPath = 'C:\new' }
        }
        $onRetry = { param($e) $script:retryState.RetryCalled++ }

        $res = Invoke-MoveAlbumWithRetryCore -mvArgs @{} -UseWhatIf:$false -OnRetry $onRetry
        $res | Should -Not -Be $null
        $script:retryState.RetryCalled | Should -Be 1
    }

    It 'returns null when Move-AlbumFolder keeps failing and OnRetry requests skip' {
        Mock Move-AlbumFolder { throw 'Locked' }
        $res = Invoke-MoveAlbumWithRetryCore -mvArgs @{} -UseWhatIf:$false -OnRetry { param($e) 's' }
        $res | Should -Be $null
    }

    It 'returns null immediately when AutoSkip is enabled' {
        Mock Move-AlbumFolder { throw 'Locked' }
        $res = Invoke-MoveAlbumWithRetryCore -mvArgs @{} -UseWhatIf:$false -AutoSkip
        $res | Should -Be $null
    }
}

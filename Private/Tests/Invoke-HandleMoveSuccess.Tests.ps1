# Tests for Invoke-HandleMoveSuccess using the Context object pattern.
# These tests verify that the function correctly reads/writes the Context
# hashtable instead of relying on $script: variables.

Describe 'Invoke-HandleMoveSuccess' {
    BeforeAll {
        $helperPath = Join-Path $PSScriptRoot '..\Workflow\Invoke-HandleMoveSuccess.ps1'
        if (-not (Test-Path $helperPath)) { throw "Helper not found: $helperPath" }
        . $helperPath
    }

    BeforeEach {
        # Create temp directories for real file system operations
        $script:testRoot = Join-Path $TestDrive 'HandleMoveSuccess'
        $script:albumDir = Join-Path $script:testRoot 'Artist' '2024 - TestAlbum'
        $script:targetDir = Join-Path $script:testRoot 'Target'
        New-Item -Path $script:albumDir -ItemType Directory -Force | Out-Null

        # Stub out dependencies that touch TagLib or do expensive I/O
        function Reload-OMAudioFiles { param([string]$AlbumPath) return @() }
        function Approve-PathSegment {
            param([string]$Segment, [string]$Replacement, [switch]$CollapseRepeating, [switch]$Transliterate)
            return $Segment
        }
    }

    Context 'With Context object' {
        It 'sets TargetFolderMoved when album is moved to target folder' {
            $ctx = @{
                Album             = Get-Item -LiteralPath $script:albumDir
                AudioFiles        = @()
                PairedTracks      = @()
                RefreshTracks     = $false
                TargetFolderMoved = $false
                IsSingleAlbumPath = $false
            }

            $moveResult = @{ Success = $true; NewAlbumPath = $script:albumDir }

            Invoke-HandleMoveSuccess `
                -MoveResult $moveResult `
                -UseWhatIf $false `
                -OldPath $script:albumDir `
                -TargetFolder $script:targetDir `
                -Context $ctx

            $ctx.TargetFolderMoved | Should -BeTrue
        }

        It 'does not set TargetFolderMoved when no TargetFolder specified' {
            $ctx = @{
                Album             = Get-Item -LiteralPath $script:albumDir
                AudioFiles        = @()
                PairedTracks      = @()
                RefreshTracks     = $false
                TargetFolderMoved = $false
                IsSingleAlbumPath = $false
            }

            $moveResult = @{ Success = $true; NewAlbumPath = $script:albumDir }

            Invoke-HandleMoveSuccess `
                -MoveResult $moveResult `
                -UseWhatIf $false `
                -OldPath $script:albumDir `
                -Context $ctx

            $ctx.TargetFolderMoved | Should -BeFalse
        }

        It 'sets RefreshTracks when folder is renamed' {
            # Create a new folder to simulate the rename destination
            $newAlbumDir = Join-Path $script:testRoot 'Artist' '2024 - RenamedAlbum'
            # Move the folder so Get-Item works on the new path
            Move-Item -LiteralPath $script:albumDir -Destination $newAlbumDir

            $ctx = @{
                Album             = Get-Item -LiteralPath $newAlbumDir
                AudioFiles        = @()
                PairedTracks      = @()
                RefreshTracks     = $false
                TargetFolderMoved = $false
                IsSingleAlbumPath = $false
            }

            $moveResult = @{ Success = $true; NewAlbumPath = $newAlbumDir }

            Invoke-HandleMoveSuccess `
                -MoveResult $moveResult `
                -UseWhatIf $false `
                -OldPath $script:albumDir `
                -Context $ctx

            $ctx.RefreshTracks | Should -BeTrue
        }

        It 'updates Album when moved to target folder' {
            $ctx = @{
                Album             = Get-Item -LiteralPath $script:albumDir
                AudioFiles        = @()
                PairedTracks      = @()
                RefreshTracks     = $false
                TargetFolderMoved = $false
                IsSingleAlbumPath = $false
            }

            $moveResult = @{ Success = $true; NewAlbumPath = $script:albumDir }

            Invoke-HandleMoveSuccess `
                -MoveResult $moveResult `
                -UseWhatIf $false `
                -OldPath $script:albumDir `
                -TargetFolder $script:targetDir `
                -Context $ctx

            # Album should now point to the target folder location
            $ctx.Album.FullName | Should -BeLike "$($script:targetDir)*"
            $ctx.TargetFolderMoved | Should -BeTrue
        }

        It 'does not produce pipeline output (no leaks)' {
            $ctx = @{
                Album             = Get-Item -LiteralPath $script:albumDir
                AudioFiles        = @()
                PairedTracks      = @()
                RefreshTracks     = $false
                TargetFolderMoved = $false
                IsSingleAlbumPath = $false
            }

            $moveResult = @{ Success = $true; NewAlbumPath = $script:albumDir }

            $output = Invoke-HandleMoveSuccess `
                -MoveResult $moveResult `
                -UseWhatIf $false `
                -OldPath $script:albumDir `
                -TargetFolder $script:targetDir `
                -Context $ctx

            $output | Should -BeNullOrEmpty
        }

        It 'cleans up empty parent when IsSingleAlbumPath is false' {
            # Use a separate artist folder so it becomes truly empty after the album moves
            $isolatedArtistDir = Join-Path $script:testRoot 'IsolatedArtist'
            $isolatedAlbumDir = Join-Path $isolatedArtistDir '2024 - TestAlbum'
            New-Item -Path $isolatedAlbumDir -ItemType Directory -Force | Out-Null

            $ctx = @{
                Album             = Get-Item -LiteralPath $isolatedAlbumDir
                AudioFiles        = @()
                PairedTracks      = @()
                RefreshTracks     = $false
                TargetFolderMoved = $false
                IsSingleAlbumPath = $false
            }

            $moveResult = @{ Success = $true; NewAlbumPath = $isolatedAlbumDir }

            Invoke-HandleMoveSuccess `
                -MoveResult $moveResult `
                -UseWhatIf $false `
                -OldPath $isolatedAlbumDir `
                -TargetFolder $script:targetDir `
                -Context $ctx

            # The parent "IsolatedArtist" folder should have been cleaned up (it's now empty)
            Test-Path -LiteralPath $isolatedArtistDir | Should -BeFalse
        }

        It 'preserves parent when IsSingleAlbumPath is true' {
            $ctx = @{
                Album             = Get-Item -LiteralPath $script:albumDir
                AudioFiles        = @()
                PairedTracks      = @()
                RefreshTracks     = $false
                TargetFolderMoved = $false
                IsSingleAlbumPath = $true
            }

            $moveResult = @{ Success = $true; NewAlbumPath = $script:albumDir }
            $parentFolder = Split-Path $script:albumDir -Parent

            Invoke-HandleMoveSuccess `
                -MoveResult $moveResult `
                -UseWhatIf $false `
                -OldPath $script:albumDir `
                -TargetFolder $script:targetDir `
                -Context $ctx

            # The parent folder should still exist
            Test-Path -LiteralPath $parentFolder | Should -BeTrue
        }

        It 'handles failed MoveResult with warning' {
            $ctx = @{
                Album             = Get-Item -LiteralPath $script:albumDir
                AudioFiles        = @()
                PairedTracks      = @()
                RefreshTracks     = $false
                TargetFolderMoved = $false
                IsSingleAlbumPath = $false
            }

            $moveResult = @{ Success = $false }

            Invoke-HandleMoveSuccess `
                -MoveResult $moveResult `
                -UseWhatIf $false `
                -OldPath $script:albumDir `
                -Context $ctx 3>&1 | Should -Not -BeNullOrEmpty

            # Context should be unchanged
            $ctx.TargetFolderMoved | Should -BeFalse
            $ctx.RefreshTracks | Should -BeFalse
        }

        It 'does not move or modify when WhatIf is true' {
            $ctx = @{
                Album             = Get-Item -LiteralPath $script:albumDir
                AudioFiles        = @()
                PairedTracks      = @()
                RefreshTracks     = $false
                TargetFolderMoved = $false
                IsSingleAlbumPath = $false
            }

            $moveResult = @{ Success = $true; NewAlbumPath = (Join-Path $script:testRoot 'Artist' '2024 - NewName') }

            Invoke-HandleMoveSuccess `
                -MoveResult $moveResult `
                -UseWhatIf $true `
                -OldPath $script:albumDir `
                -TargetFolder $script:targetDir `
                -Context $ctx

            # WhatIf should not modify context state
            $ctx.TargetFolderMoved | Should -BeFalse
            $ctx.RefreshTracks | Should -BeFalse
            # Original album folder should still exist
            Test-Path -LiteralPath $script:albumDir | Should -BeTrue
        }
    }

}

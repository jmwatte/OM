# Tests that verify Stage C's 'sa' handler return contract.
# The key invariant: every code path must return exactly ONE hashtable,
# never an array (which would happen if uncaptured function output leaks to pipeline).

Describe 'Stage C sa handler - pipeline leak prevention' {
    BeforeAll {
        # We test the pattern, not the full function. The sa handler calls:
        #   Save-CoverArtWithFallback  -> returns PSCustomObject (MUST be captured)
        #   Save-OMTagsLoop            -> returns nothing (but could leak)
        #   Invoke-OMFolderRename      -> returns hashtable (captured in $moveResult)
        #   Invoke-HandleMoveSuccess   -> returns nothing (but could leak)
        #
        # If any of these leak output, the return statement
        #   return (& $buildResult @{ NextStage = 'AlbumDone' })
        # produces an array: [leaked_output, hashtable] instead of just hashtable.
    }

    It 'buildResult scriptblock returns exactly one hashtable' {
        $defaultResult = @{
            NextStage     = 'AlbumDone'
            Provider      = 'Qobuz'
            ProviderAlbum = @{ name = 'Test' }
            UseWhatIf     = $false
            ReverseSource = $false
            SortMethod    = 'byFilesystem'
        }
        $buildResult = {
            param([hashtable]$Overrides)
            $result = $defaultResult.Clone()
            foreach ($key in $Overrides.Keys) {
                $result[$key] = $Overrides[$key]
            }
            return $result
        }

        $output = & $buildResult @{ NextStage = 'AlbumDone' }
        $output | Should -BeOfType [hashtable]
        @($output).Count | Should -Be 1
    }

    It 'leaked function output + buildResult produces array (demonstrates the bug)' {
        $defaultResult = @{
            NextStage     = 'AlbumDone'
            Provider      = 'Qobuz'
            ProviderAlbum = @{ name = 'Test' }
        }
        $buildResult = {
            param([hashtable]$Overrides)
            $result = $defaultResult.Clone()
            foreach ($key in $Overrides.Keys) {
                $result[$key] = $Overrides[$key]
            }
            return $result
        }

        # Simulate what happens when a function's output leaks onto the pipeline
        $output = & {
            # This is the BUGGY pattern - uncaptured function that returns something
            [PSCustomObject]@{ Success = $true }  # leaked output
            return (& $buildResult @{ NextStage = 'AlbumDone' })
        }

        # This is exactly the bug: output becomes an array
        @($output).Count | Should -Be 2
        $output -is [hashtable] | Should -BeFalse
    }

    It '$null = capture prevents pipeline leak (the fix)' {
        $defaultResult = @{
            NextStage     = 'AlbumDone'
            Provider      = 'Qobuz'
            ProviderAlbum = @{ name = 'Test' }
        }
        $buildResult = {
            param([hashtable]$Overrides)
            $result = $defaultResult.Clone()
            foreach ($key in $Overrides.Keys) {
                $result[$key] = $Overrides[$key]
            }
            return $result
        }

        # Simulate the FIXED pattern - output captured in $null
        $output = & {
            $null = [PSCustomObject]@{ Success = $true }  # captured, won't leak
            return (& $buildResult @{ NextStage = 'AlbumDone' })
        }

        $output | Should -BeOfType [hashtable]
        @($output).Count | Should -Be 1
        $output.NextStage | Should -Be 'AlbumDone'
    }

    Context 'Verify actual code uses $null capture' {
        BeforeAll {
            $stageCSrc = Get-Content (Join-Path $PSScriptRoot '..\Stages\stages\Invoke-StageC-TrackSelection.ps1') -Raw
        }

        It 'Save-CoverArtWithFallback calls are captured with $null' {
            # Every call to Save-CoverArtWithFallback should be preceded by $null =
            $pattern = '(?m)^[^#\n]*(?<!\$null\s*=\s*)Save-CoverArtWithFallback\b'
            $stageCSrc | Should -Not -Match $pattern
        }

        It 'Save-OMTagsLoop calls do not need capture (returns void)' {
            # This test documents the expectation: Save-OMTagsLoop should not return anything
            $helperPath = Join-Path $PSScriptRoot '..\Workflow\Save-OMTagsLoop.ps1'
            $src = Get-Content $helperPath -Raw
            # The function should not have explicit return statements with values
            $src | Should -Not -Match 'return \$[a-zA-Z]'
        }

        It 'Invoke-HandleMoveSuccess calls do not need capture (returns void)' {
            $helperPath = Join-Path $PSScriptRoot '..\Workflow\Invoke-HandleMoveSuccess.ps1'
            $src = Get-Content $helperPath -Raw
            # The function should not have explicit return statements with values
            $src | Should -Not -Match '^\s*return \$[a-zA-Z]'
        }
    }
}

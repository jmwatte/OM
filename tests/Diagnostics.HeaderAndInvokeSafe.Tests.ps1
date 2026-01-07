Describe 'Show-OMHeader and Invoke-SafeScriptBlock behavior' {

    BeforeAll {
        . (Join-Path $PSScriptRoot '..\Private\Utils\Show-Message.ps1')
        . (Join-Path $PSScriptRoot '..\Private\Utils\Show-OMHeader.ps1')
        . (Join-Path $PSScriptRoot '..\Private\Utils\Invoke-SafeScriptBlock.ps1')
    }

    Context 'Show-OMHeader display behavior' {
        It 'prints header every time when called (no dedupe)' {
            $script:msgs = @()
            # Use InModuleScope alternative - override Show-Message in local scope
            function Show-Message { param($Message,$ForegroundColor,[switch]$NoNewline,$Context) $script:msgs += $Message }

            Show-OMHeader -Provider 'ProvX' -Artist 'ArtistY' -AlbumName 'AlbumZ' -TrackCount 3 -Context $null
            Show-OMHeader -Provider 'ProvX' -Artist 'ArtistY' -AlbumName 'AlbumZ' -TrackCount 3 -Context $null

            $providerLines = $script:msgs | Where-Object { $_ -like '*Provider*' }
            $providerLines.Count | Should -Be 2
        }

        It 'skips header when all args are empty' {
            $script:msgs = @()
            function Show-Message { param($Message,$ForegroundColor,[switch]$NoNewline,$Context) $script:msgs += $Message }

            # Use whitespace instead of empty to avoid mandatory param validation
            Show-OMHeader -Provider ' ' -Artist ' ' -AlbumName ' ' -TrackCount 0 -Context $null

            $providerLines = $script:msgs | Where-Object { $_ -like '*Provider*' }
            $providerLines.Count | Should -Be 0
        }
    }

    Context 'Invoke-SafeScriptBlock empty-first-arg fallback' {
        It 'returns no-args result when first arg is empty string' {
            $block = {
                if ($args.Count -gt 0 -and [string]::IsNullOrWhiteSpace($args[0])) {
                    throw [System.Management.Automation.ParameterBindingException] "A positional parameter cannot be found that accepts argument '$($args[0])'."
                }
                elseif ($args.Count -gt 0) { return "ARGS:$($args -join ',')" }
                else { return 'NOARGS' }
            }

            $res = Invoke-SafeScriptBlock -Block $block -Args @('') -ContextMsg 'test-empty-first-arg'
            $res | Should -Be 'NOARGS'
        }

        It 'returns ARGS when non-empty args are passed' {
            $block = { if ($args.Count -gt 0) { return "ARGS:$($args -join ',')" } else { return 'NOARGS' } }
            $res = Invoke-SafeScriptBlock -Block $block -Args @('nonempty') -ContextMsg 'test-nonempty'
            $res | Should -Be 'ARGS:nonempty'
        }
    }
}

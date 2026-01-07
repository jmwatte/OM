Describe 'Show-OMHeader dedupe and Invoke-SafeScriptBlock empty-arg fallback' {

    BeforeAll {
        . (Join-Path $PSScriptRoot '..\Private\Utils\Show-OMHeader.ps1')
        . (Join-Path $PSScriptRoot '..\Private\Utils\Invoke-SafeScriptBlock.ps1')
    }

    Context 'Show-OMHeader dedupe behavior' {
        It 'prints Provider line only once when called twice quickly with same args' {
            # Ensure clean state
            Remove-Variable -Name __lastShownOMHeader -Scope Script -ErrorAction SilentlyContinue
            $script:msgs = @()
            Mock -CommandName Show-Message -ModuleName OM -MockWith { param($msg,$color,$no,$ctx) $script:msgs += $msg }

            Show-OMHeader -Provider 'ProvX' -Artist 'ArtistY' -AlbumName 'AlbumZ' -TrackCount 3 -Context $null
            Show-OMHeader -Provider 'ProvX' -Artist 'ArtistY' -AlbumName 'AlbumZ' -TrackCount 3 -Context $null

            $providerLines = $script:msgs | Where-Object { $_ -like '*Provider:*' }
            $providerLines.Count | Should -Be 1
        }

        It 'prints again when album name changes' {
            Remove-Variable -Name __lastShownOMHeader -Scope Script -ErrorAction SilentlyContinue
            $script:msgs = @()
            Mock -CommandName Show-Message -ModuleName OM -MockWith { param($msg,$color,$no,$ctx) $script:msgs += $msg }

            Show-OMHeader -Provider 'ProvX' -Artist 'ArtistY' -AlbumName 'AlbumA' -TrackCount 1 -Context $null
            Show-OMHeader -Provider 'ProvX' -Artist 'ArtistY' -AlbumName 'AlbumB' -TrackCount 1 -Context $null

            $providerLines = $script:msgs | Where-Object { $_ -like '*Provider:*' }
            $providerLines.Count | Should -Be 2
        }

        It 'prints again if last shown time is old' {
            Remove-Variable -Name __lastShownOMHeader -Scope Script -ErrorAction SilentlyContinue
            $script:msgs = @()
            Mock -CommandName Show-Message -ModuleName OM -MockWith { param($msg,$color,$no,$ctx) $script:msgs += $msg }

            Show-OMHeader -Provider 'P' -Artist 'A' -AlbumName 'AL' -TrackCount 5 -Context $null
            # Simulate old time
            $script:__lastShownOMHeader.Time = (Get-Date).AddSeconds(-10)
            Show-OMHeader -Provider 'P' -Artist 'A' -AlbumName 'AL' -TrackCount 5 -Context $null

            $providerLines = $script:msgs | Where-Object { $_ -like '*Provider:*' }
            $providerLines.Count | Should -Be 2
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

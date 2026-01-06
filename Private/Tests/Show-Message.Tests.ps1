Describe 'Show-Message' {
    It 'calls explicit DisplayWriter when provided' {
        $global:called = $false
        $global:argsCaptured = $null
        $writer = { param($msg,$color) $global:called = $true; $global:argsCaptured = @($msg,$color) }

        . "$PSScriptRoot\..\Utils\Show-Message.ps1"

        Show-Message -Message 'Hello' -ForegroundColor 'Cyan' -DisplayWriter $writer

        $global:called | Should -Be $true
        $global:argsCaptured[0] | Should -Be 'Hello'
        $global:argsCaptured[1] | Should -Be 'Cyan'
    }

    It 'uses Context.DisplayWriter when DisplayWriter not provided' {
        $global:called = $false
        $writer = { param($msg,$color) $global:called = $true; $global:args = @($msg,$color) }
        $ctx = New-Object PSObject -Property @{ DisplayWriter = $writer }

        . "$PSScriptRoot\..\Utils\Show-Message.ps1"

        Show-Message -Message 'FromContext' -ForegroundColor 'Yellow' -Context $ctx

        $global:called | Should -Be $true
        $global:args[0] | Should -Be 'FromContext'
        $global:args[1] | Should -Be 'Yellow'
    }
}

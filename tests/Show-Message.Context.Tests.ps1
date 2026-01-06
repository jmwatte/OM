Describe 'Show-Message with Context.DisplayWriter' {
    It 'uses Context.DisplayWriter when provided' {
        # Dot-source helper
        . (Join-Path $PSScriptRoot '..\Private\Utils\Show-Message.ps1')

        $script:captured = @()
        $ctx = [PSCustomObject]@{ DisplayWriter = { param($msg,$color,$no) $script:captured += $msg } }

        Show-Message -Message 'Hello Context' -ForegroundColor Cyan -Context $ctx

        $script:captured | Should -Contain 'Hello Context'
    }
}

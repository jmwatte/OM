Describe 'Invoke-SafeScriptBlock' {
    BeforeAll {
        $p = Join-Path $PSScriptRoot '..\Utils\Invoke-SafeScriptBlock.ps1'
        if (-not (Test-Path $p)) { Throw "Helper not found at runtime: $p" }
        . $p
    }

    It 'returns null when target is not a scriptblock' {
        $res = Invoke-SafeScriptBlock -Block 'NotAScriptblock' -Args @('x')
        $res | Should -Be $null
    }

    It 'invokes scriptblock with args and returns result' {
        $sb = { param($a,$b) return "$a|$b" }
        $res = Invoke-SafeScriptBlock -Block $sb -Args @('one','two')
        $res | Should -Be 'one|two'
    }

    It 'catches ParameterBindingException and returns null when block throws ParameterBindingException' {
        # Block that always throws ParameterBindingException
        $sb = { throw [System.Management.Automation.ParameterBindingException]::new("boom") }
        { Invoke-SafeScriptBlock -Block $sb -Args @('') } | Should -Not -Throw
        $res = Invoke-SafeScriptBlock -Block $sb -Args @('')
        $res | Should -Be $null
    }

    It 'tries named -Prompt fallback when ParameterBindingException occurs' {
        # Block that only accepts named -Prompt (simulate by checking $PSBoundParameters)
        $sb = { param($Prompt) if ($PSBoundParameters.ContainsKey('Prompt')) { return "named:$Prompt" } else { throw [System.Management.Automation.ParameterBindingException]::new("positional fail") } }

        # If called positionally, first attempt will throw, but helper should fall back to -Prompt and succeed
        $res = Invoke-SafeScriptBlock -Block $sb -Args @('hello') -ContextMsg 'test'
        $res | Should -Be 'named:hello'
    }

    It 'handles empty first arg by trying no-arg then named -Prompt' {
        # Block that succeeds with no args, but also supports named -Prompt
        $sb = { param($Prompt) if ($PSBoundParameters.Count -eq 0) { return 'noarg' } elseif ($PSBoundParameters.ContainsKey('Prompt')) { return "named:$Prompt" } else { throw [System.Management.Automation.ParameterBindingException]::new('fail') } }

        # When passed an empty string as first arg, helper should attempt no-arg invocation first and succeed
        $res = Invoke-SafeScriptBlock -Block $sb -Args @('') -ContextMsg 'empty-first'
        $res | Should -Be 'noarg'
    }
}
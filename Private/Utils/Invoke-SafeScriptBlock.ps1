function Invoke-SafeScriptBlock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][object]$Block,
        [Parameter(Mandatory=$false)][object[]]$Args = @(),
        [Parameter(Mandatory=$false)][string]$ContextMsg = ''
    )

    if (-not ($Block -is [scriptblock])) {
        Write-Verbose "Invoke-SafeScriptBlock: target is not a scriptblock (value: '$Block')"
        return $null
    }

    try {
        # Write a non-error diagnostic entry for successful or attempted invocations so we can
        # trace the sequence of scriptblock calls leading up to failures.
        try {
            $diagFile = Join-Path $env:TEMP 'om_invoke_safe_diag.txt'
            $entry = "$(Get-Date -Format o) | ENTER: Context: $ContextMsg | Block: $($Block.ToString()) | Args: $($Args -join ', ')"
            $entry | Out-File -FilePath $diagFile -Append -Encoding utf8 -Force
        } catch {
            Write-Verbose "Invoke-SafeScriptBlock: failed to write entry diag file: $($_.Exception.Message)"
        }

        if ($Args -and $Args.Count -gt 0) {
            return & $Block @Args
        }
        else {
            return & $Block
        }
    }
    catch [System.Management.Automation.ParameterBindingException] {
        Write-Verbose "Invoke-SafeScriptBlock: ParameterBindingException invoking block: $($_.Exception.Message)"
        Write-Verbose "Invoke-SafeScriptBlock: ContextMsg: $ContextMsg"
        if ($Args -and $Args.Count -gt 0) {
            for ($i = 0; $i -lt $Args.Count; $i++) {
                $a = $Args[$i]
                Write-Verbose ("Invoke-SafeScriptBlock: Arg[{0}] Type={1} Value='{2}'" -f $i, ($a -ne $null ? $a.GetType().FullName : '<null>'), ($a -ne $null ? $a.ToString() : '<null>'))
            }
        }
        Write-Verbose ("Invoke-SafeScriptBlock: BlockText: $($Block.ToString())")

        # Write a persistent diagnostic entry so we can inspect failing invocations after the run
        try {
            $diagFile = Join-Path $env:TEMP 'om_invoke_safe_diag.txt'
            $diagEntry = "$(Get-Date -Format o) | Context: $ContextMsg | Block: $($Block.ToString()) | Args: $($Args -join ', ') | Exception: $($_.Exception.Message)"
            $diagEntry | Out-File -FilePath $diagFile -Append -Encoding utf8 -Force
        } catch {
            Write-Verbose "Invoke-SafeScriptBlock: failed to write diag file: $($_.Exception.Message)"
        }

        if (Get-Command -Name Dump-ExceptionDiagnostics -ErrorAction SilentlyContinue) {
            Dump-ExceptionDiagnostics -ErrorRecord $_ -ContextMsg ("Invoke-SafeScriptBlock: $ContextMsg")
        }

        # Add richer diagnostics to persistent diag file
        try {
            $diagFile2 = Join-Path $env:TEMP 'om_invoke_safe_diag_details.txt'
            $details = @()
            $details += "Timestamp: $(Get-Date -Format o)"
            $details += "ContextMsg: $ContextMsg"
            $details += "BlockText: $($Block.ToString())"
            $details += "Args: $($Args -join ', ')"
            $details += "ExceptionMessage: $($_.Exception.Message)"
            $details += "InvocationInfo: $($_.InvocationInfo | Out-String)"
            $details += "PSCallStack: $((Get-PSCallStack) | Out-String)"
            $details += "----"
            $details | Out-File -FilePath $diagFile2 -Append -Encoding utf8 -Force
        } catch {
            Write-Verbose "Invoke-SafeScriptBlock: failed to write detailed diag file: $($_.Exception.Message)"
        }

        # If debugging mode enabled, rethrow the original error so harness captures full context
        if ($env:OM_DEBUG_RETHROW_INVOKE -eq '1') {
            Write-Verbose "Invoke-SafeScriptBlock: rethrowing ParameterBindingException because OM_DEBUG_RETHROW_INVOKE=1"
            throw $_
        }

        # Special-case: if the first arg is an empty string, avoid passing it positionally
        if ($Args -and $Args.Count -gt 0 -and ($Args[0] -is [string]) -and [string]::IsNullOrWhiteSpace($Args[0])) {
            Write-Verbose "Invoke-SafeScriptBlock: first arg is empty/whitespace; attempting no-arg call first"
            try { return & $Block } catch {
                Write-Verbose "Invoke-SafeScriptBlock: no-args fallback failed: $($_.Exception.Message)"
            }
            # try named -Prompt fallback as a secondary attempt
            try { return & $Block -Prompt $Args[0] } catch {
                Write-Verbose "Invoke-SafeScriptBlock: named -Prompt fallback failed: $($_.Exception.Message)"
            }
        }

        # Try named -Prompt fallback if first arg looks like a prompt message
        if ($Args -and $Args.Count -gt 0 -and ($Args[0] -is [string])) {
            try { return & $Block -Prompt $Args[0] } catch {
                Write-Verbose "Invoke-SafeScriptBlock: fallback -Prompt failed: $($_.Exception.Message)"
            }
        }

        # Try calling with no args as a last resort
        try { return & $Block } catch {
            Write-Verbose "Invoke-SafeScriptBlock: fallback no-args failed: $($_.Exception.Message)"
        }

        return $null
    }
    catch {
        Write-Verbose "Invoke-SafeScriptBlock: invocation failed: $($_.Exception.Message)"
        if (Get-Command -Name Dump-ExceptionDiagnostics -ErrorAction SilentlyContinue) {
            Dump-ExceptionDiagnostics -ErrorRecord $_ -ContextMsg ("Invoke-SafeScriptBlock: $ContextMsg")
        }
        return $null
    }
}
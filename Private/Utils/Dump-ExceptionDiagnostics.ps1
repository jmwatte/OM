function Dump-ExceptionDiagnostics {
    <#
    .SYNOPSIS
        Dumps detailed exception diagnostics for debugging.
    
    .DESCRIPTION
        Writes exception type, message, InvocationInfo, PSBoundParameters, and call stack
        to verbose output and standard output for debugging purposes.
    
    .PARAMETER ErrorRecord
        The ErrorRecord or exception to dump.
    
    .PARAMETER ContextMsg
        Optional context message describing where the error occurred.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [object]$ErrorRecord,
        
        [string]$ContextMsg = ''
    )
    
    try {
        Write-Verbose "DUMP-EX: $ContextMsg - $($ErrorRecord.Exception.GetType().FullName): $($ErrorRecord.Exception.Message)"
        Write-Output "--- DUMP-EX: $ContextMsg ---"
        Write-Output ("ExceptionType: {0}" -f $ErrorRecord.Exception.GetType().FullName)
        Write-Output ("Message: {0}" -f $ErrorRecord.Exception.Message)
        if ($ErrorRecord.InvocationInfo) {
            Write-Output "InvocationInfo:"
            $ErrorRecord.InvocationInfo | Format-List * | ForEach-Object { Write-Output $_ }
        }
        Write-Output ("PSBoundParameters (at this scope): {0}" -f ($PSBoundParameters.Keys -join ','))
        Write-Output "Get-PSCallStack:"
        Get-PSCallStack | ForEach-Object { Write-Output "  $_" }
        Write-Output "--- end DUMP-EX ---"
    }
    catch {
        Write-Verbose "Dump-ExceptionDiagnostics failed: $_"
    }
}

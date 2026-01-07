function Show-Message {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [string]$ForegroundColor,

        [Parameter(Mandatory = $false)]
        [switch]$NoNewline,

        [Parameter(Mandatory = $false)][scriptblock]$DisplayWriter,
        [Parameter(Mandatory = $false)][object]$Context
    )

    # If a custom DisplayWriter is provided (explicit or via Context), use it through Invoke-SafeScriptBlock
    # Otherwise, just call Write-Host directly (no need for the indirection complexity)
    $customWriter = if ($DisplayWriter) { $DisplayWriter } elseif ($Context -and $Context.DisplayWriter) { $Context.DisplayWriter } else { $null }

    if ($customWriter) {
        # Invoke custom writer defensively using the safe helper
        if (-not (Get-Command -Name Invoke-SafeScriptBlock -ErrorAction SilentlyContinue)) {
            $candidates = @()
            if ($PSScriptRoot) { $candidates += Join-Path $PSScriptRoot 'Invoke-SafeScriptBlock.ps1' }
            if ($MyInvocation.MyCommand.Path) { $candidates += Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'Invoke-SafeScriptBlock.ps1' }
            $candidates += Join-Path (Get-Location) 'Private\Utils\Invoke-SafeScriptBlock.ps1'
            foreach ($p in $candidates) { if (Test-Path $p) { . $p; break } }
        }

        $argsToPass = if ($NoNewline) { @($Message, $ForegroundColor, $true) } else { @($Message, $ForegroundColor) }
        $res = Invoke-SafeScriptBlock -Block $customWriter -Args $argsToPass -ContextMsg "Show-Message writer"
        
        # If custom writer failed, fall back to Write-Host
        if ($null -eq $res) {
            Write-Verbose "Show-Message: custom writer returned null/failure; falling back to Write-Host."
            if ($NoNewline) {
                if ($ForegroundColor) { Write-Host -NoNewline -ForegroundColor $ForegroundColor $Message } else { Write-Host -NoNewline $Message }
            }
            else {
                if ($ForegroundColor) { Write-Host -ForegroundColor $ForegroundColor $Message } else { Write-Host $Message }
            }
        }
    }
    else {
        # No custom writer - use Write-Host directly (simple, no duplication possible)
        if ($NoNewline) {
            if ($ForegroundColor) { Write-Host -NoNewline -ForegroundColor $ForegroundColor $Message } else { Write-Host -NoNewline $Message }
        }
        else {
            if ($ForegroundColor) { Write-Host -ForegroundColor $ForegroundColor $Message } else { Write-Host $Message }
        }
    }
}

function Prompt-PressEnter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)][scriptblock]$InputReader,
        [Parameter(Mandatory=$false)][object]$Context
    )

    $reader = if ($InputReader) { $InputReader } elseif ($Context -and $Context.InputReader) { $Context.InputReader } else { { param($prompt) Read-Host -Prompt $prompt } }

    if (-not (Get-Command -Name Invoke-SafeScriptBlock -ErrorAction SilentlyContinue)) {
        $candidates = @()
        if ($PSScriptRoot) { $candidates += Join-Path $PSScriptRoot 'Invoke-SafeScriptBlock.ps1' }
        if ($MyInvocation.MyCommand.Path) { $candidates += Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'Invoke-SafeScriptBlock.ps1' }
        $candidates += Join-Path (Get-Location) 'Private\Utils\Invoke-SafeScriptBlock.ps1'
        foreach ($p in $candidates) { if (Test-Path $p) { . $p; break } }
    }

    return Invoke-SafeScriptBlock -Block $reader -Args @("Press Enter to continue...") -ContextMsg "Prompt-PressEnter"
}
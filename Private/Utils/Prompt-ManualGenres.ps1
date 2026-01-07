function Prompt-ManualGenres {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)][string]$Provider,
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

    $choice = Invoke-SafeScriptBlock -Block $reader -Args @("Do you want to (s)kip or (e)nter genres manually? [s]: ") -ContextMsg "Prompt-ManualGenres choice"
    if ($choice -eq 'e') {
        $manual = Invoke-SafeScriptBlock -Block $reader -Args @("Enter genres (comma-separated): ") -ContextMsg "Prompt-ManualGenres manual"
        if (-not $manual) { return @() }
        return @($manual -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    }

    return $null
}
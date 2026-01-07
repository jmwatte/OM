function Show-OMPrompt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prompt,

        [Parameter(Mandatory = $false)]
        [string[]]$ContextualActions,

        [Parameter(Mandatory = $false)]
        [string]$Default,

        [Parameter(Mandatory = $false)]
        [switch]$NoNewline,

        [Parameter(Mandatory = $false)][scriptblock]$InputReader,
        [Parameter(Mandatory = $false)][object]$Context
    )

    # Define the standard, universal actions (removed - redundant and some not implemented)
    # Each prompt should explicitly list its own available actions
    # $universalActions = @(
    #     "(p)rovider <name>",
    #     "(b)ack",
    #     "(s)kip album",
    #     "e(x)it"
    # )

    # Combine the stage-specific actions (no universal actions added)
    $allActions = @()
    if ($ContextualActions) {
        $allActions += $ContextualActions
    }
    # No longer appending universal actions - they were redundant and confusing

    # Build the action string
    $actionString = $allActions -join ', '

    # Build the prompt string including default if any
    if ($Default -ne $null -and $Default -ne '') {
        $fullPrompt = "$Prompt [$Default] ($actionString):"
    }
    else {
        $fullPrompt = "$Prompt ($actionString):"
    }

    # Ensure Invoke-SafeScriptBlock helper available when dot-sourced in tests
    if (-not (Get-Command -Name Invoke-SafeScriptBlock -ErrorAction SilentlyContinue)) {
        $candidates = @()
        if ($PSScriptRoot) { $candidates += Join-Path $PSScriptRoot 'Invoke-SafeScriptBlock.ps1' }
        if ($MyInvocation.MyCommand.Path) { $candidates += Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'Invoke-SafeScriptBlock.ps1' }
        $candidates += Join-Path (Get-Location) 'Private\Utils\Invoke-SafeScriptBlock.ps1'
        foreach ($path in $candidates) { if (Test-Path $path) { . $path; break } }
    }

    $reader = if ($InputReader) { $InputReader } elseif ($Context -and $Context.InputReader) { $Context.InputReader } else { { param($prompt) Read-Host -Prompt $prompt } }

    # Normalize reader: prefer scriptblock; if reader is a command name string, resolve to its scriptblock; otherwise fallback to Read-Host
    if (-not ($reader -is [scriptblock])) {
        try {
            if ($reader -and (Get-Command -Name $reader -ErrorAction SilentlyContinue)) {
                $readerCmd = Get-Command -Name $reader -ErrorAction Stop
                $reader = $readerCmd.ScriptBlock
            }
            else {
                Write-Verbose "Show-OMPrompt: InputReader invalid or not callable (value: '$reader'), falling back to Read-Host"
                $reader = { param($prompt) Read-Host -Prompt $prompt }
            }
        }
        catch {
            Write-Verbose "Show-OMPrompt: failed to resolve InputReader ('$reader'): $_; falling back to Read-Host"
            $reader = { param($prompt) Read-Host -Prompt $prompt }
        }
    }

    # If caller wants no newline, render prompt text and then call reader without prompt text (to mimic prior behavior)
    if ($NoNewline) {
        Write-Host -NoNewline $fullPrompt
        # Many readers (Read-Host) throw when given an empty -Prompt; prefer calling the reader with NO args
        $input = Invoke-SafeScriptBlock -Block $reader -ContextMsg 'Show-OMPrompt NoNewline'
    }
    else {
        # If prompt text is empty/whitespace, avoid passing it positionally (some readers or commands can fail on empty positional args)
        if ([string]::IsNullOrWhiteSpace($fullPrompt)) {
            Write-Verbose "Show-OMPrompt: fullPrompt is empty; calling reader with no args to avoid positional empty arg"
            $input = Invoke-SafeScriptBlock -Block $reader -ContextMsg 'Show-OMPrompt NoPrompt'
        }
        else {
            # Prefer named param to avoid accidental positional mismatches; use safe-invoke for diagnostics/fallbacks
            $input = Invoke-SafeScriptBlock -Block $reader -Args @($fullPrompt) -ContextMsg 'Show-OMPrompt Prompt'
        }
    }

    if ([string]::IsNullOrEmpty($input) -and $Default -ne $null) {
        return $Default
    }

    return $input
}
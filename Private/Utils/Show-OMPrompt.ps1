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

    # Define the standard, universal actions
    $universalActions = @(
        "(p)rovider <name>",
        "(b)ack",
        "(s)kip album",
        "e(x)it"
    )

    # Combine the stage-specific actions with the universal ones
    $allActions = @()
    if ($ContextualActions) {
        $allActions += $ContextualActions
    }
    $allActions += $universalActions

    # Build the action string
    $actionString = $allActions -join ', '

    # Build the prompt string including default if any
    if ($Default -ne $null -and $Default -ne '') {
        $fullPrompt = "$Prompt [$Default] ($actionString):"
    }
    else {
        $fullPrompt = "$Prompt ($actionString):"
    }

    $reader = if ($InputReader) { $InputReader } elseif ($Context -and $Context.InputReader) { $Context.InputReader } else { { param($prompt) Read-Host -Prompt $prompt } }

    # If caller wants no newline, render prompt text and then call reader without prompt text (to mimic prior behavior)
    if ($NoNewline) {
        Write-Host -NoNewline $fullPrompt
        $input = & $reader ''
    }
    else {
        $input = & $reader $fullPrompt
    }

    if ([string]::IsNullOrEmpty($input) -and $Default -ne $null) {
        return $Default
    }

    return $input
}
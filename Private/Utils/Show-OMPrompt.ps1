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
        [switch]$NoNewline
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

    # If caller wants no newline, render prompt text and then call Read-Host without -Prompt
    if ($NoNewline) {
        # Render prompt text without newline
        Write-Host -NoNewline $fullPrompt
        $input = Read-Host
    }
    else {
        $input = Read-Host -Prompt $fullPrompt
    }

    if ([string]::IsNullOrEmpty($input) -and $Default -ne $null) {
        return $Default
    }

    return $input
}
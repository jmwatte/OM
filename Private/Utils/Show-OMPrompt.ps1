function Show-OMPrompt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prompt,

        [Parameter(Mandatory = $false)]
        [string[]]$ContextualActions
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

    # Build the final prompt string to show the user
    $actionString = $allActions -join ', '
    $fullPrompt = "$Prompt ($actionString):"

    # Get the user's input and return it
    # For now, the main script will still handle parsing the input.
    # This change just standardizes the prompt's appearance.
    return Read-Host -Prompt $fullPrompt
}
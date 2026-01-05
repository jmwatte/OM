function Prompt-PressEnter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)][scriptblock]$InputReader,
        [Parameter(Mandatory=$false)][object]$Context
    )

    $reader = if ($InputReader) { $InputReader } elseif ($Context -and $Context.InputReader) { $Context.InputReader } else { { param($prompt) Read-Host -Prompt $prompt } }
    return & $reader "Press Enter to continue..."
}
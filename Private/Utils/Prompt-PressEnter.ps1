function Prompt-PressEnter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)][scriptblock]$InputReader
    )

    $reader = if ($InputReader) { $InputReader } else { { param($prompt) Read-Host -Prompt $prompt } }
    return & $reader "Press Enter to continue..."
}
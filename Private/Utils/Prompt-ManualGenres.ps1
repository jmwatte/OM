function Prompt-ManualGenres {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)][string]$Provider,
        [Parameter(Mandatory=$false)][scriptblock]$InputReader
    )

    $reader = if ($InputReader) { $InputReader } else { { param($prompt) Read-Host -Prompt $prompt } }

    $choice = & $reader "Do you want to (s)kip or (e)nter genres manually? [s]: "
    if ($choice -eq 'e') {
        $manual = & $reader "Enter genres (comma-separated): "
        if (-not $manual) { return @() }
        return @($manual -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    }

    return $null
}
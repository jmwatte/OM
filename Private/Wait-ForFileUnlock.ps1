function Wait-ForFileUnlock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [int]$RetryIntervalSeconds = 1,
        [Parameter(Mandatory = $false)][object]$Context
    )

    while ($true) {
        if (-not (Test-Path -LiteralPath $Path)) {
            Write-Warning "File not found: $Path"
            return @{Unlocked = $false; Action = 'skip' }
        }

        if (-not (Assert-FileLocked -Path $Path)) {
            return @{ Unlocked = $true; Action = 'proceed' }
        }

        Write-Warning "File appears to be in use: $Path"
        $choice = Show-OMPrompt -Prompt "Close the app using the file and press Enter to retry, type 'skip' to skip this file, or 'force' to attempt saving anyway" -Context $Context

        switch ($choice.ToLowerInvariant()) {
            '' { Start-Sleep -Seconds $RetryIntervalSeconds; continue }  # retry
            'skip' { return @{ Unlocked = $false; Action = 'skip' } }
            'force' { return @{ Unlocked = $false; Action = 'force' } }
            default { Write-Host "Unknown option. Press Enter to retry, 'skip' or 'force'."; continue }
        }
    }
}
try {
    # Set a strict error preference for this script
    $ErrorActionPreference = 'Stop'

    Write-Output "--- Starting Module Verification ---"

    # 1. Test Module Import
    Write-Output "Step 1: Importing module..."
    Import-Module .\OM.psd1 -Force
    Write-Output "✓ Module import successful."

    # 2. Test Non-Interactive Execution
    Write-Output "Step 2: Running Start-OM in NonInteractive/WhatIf mode..."
    # Define parameters for a test run
    $testPath = ".\testfiles\The Beatles\1965 - Help! (Remastered)"
    if (-not (Test-Path $testPath)) {
        # Fallback for different test environments if needed
        $altTestPath = "testfiles\The Beatles\1965 - Help! (Remastered)"
        if (Test-Path $altTestPath) {
            $testPath = $altTestPath
        } else {
            throw "Test path not found: $testPath"
        }
    }

    $params = @{
        Path           = $testPath
        NonInteractive = $true
        WhatIf         = $true
        Provider       = 'Spotify'
    }

    # Run the command and capture output. We only care if it throws a terminating error.
    Start-OM @params | Out-Null

    Write-Output "✓ Start-OM NonInteractive/WhatIf execution successful."
    Write-Output ""
    Write-Output "--- VERIFICATION SUCCEEDED ---"

} catch {
    Write-Error "--- VERIFICATION FAILED ---"
    Write-Error "Caught an exception:"
    Write-Error ($_.ToString())
    Write-Error "---"
    Write-Error "Exception Details:"
    Write-Error (($_.Exception | Format-List * -Force | Out-String))
    exit 1
}


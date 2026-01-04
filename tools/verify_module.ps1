try {
    # Set a strict error preference for this script
    $ErrorActionPreference = 'Stop'

    Write-Host "--- Starting Module Verification ---"

    # 1. Test Module Import
    Write-Host "Step 1: Importing module..."
    Import-Module .\OM.psd1 -Force
    Write-Host "✓ Module import successful."

    # 2. Test Non-Interactive Execution
    Write-Host "Step 2: Running Start-OM in NonInteractive/WhatIf mode..."
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

    Write-Host "✓ Start-OM NonInteractive/WhatIf execution successful."
    Write-Host ""
    Write-Host "--- VERIFICATION SUCCEEDED ---" -ForegroundColor Green

} catch {
    Write-Host ""
    Write-Host "--- VERIFICATION FAILED ---" -ForegroundColor Red
    Write-Host "Caught an exception:" -ForegroundColor Red
    Write-Host ($_.ToString()) -ForegroundColor Red
    Write-Host "---" -ForegroundColor Red
    Write-Host "Exception Details:" -ForegroundColor Red
    Write-Host (($_.Exception | Format-List * -Force | Out-String)) -ForegroundColor Red
    exit 1
}

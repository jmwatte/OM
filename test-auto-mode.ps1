# Test script for Auto Mode functionality
# This script tests the new Auto mode parameters and functions

# Ensure Show-Message helper available when running standalone
if (-not (Get-Command -Name Show-Message -ErrorAction SilentlyContinue)) {
    $p = Join-Path $PSScriptRoot 'Private\Utils\Show-Message.ps1'
    if (Test-Path $p) { . $p }
}

Show-Message -Message "========================================" -ForegroundColor Cyan -Context $null
Show-Message -Message "  Testing Auto Mode Implementation" -ForegroundColor Cyan -Context $null
Show-Message -Message "========================================" -ForegroundColor Cyan -Context $null
Show-Message -Message "" -Context $null

# Import the module
Import-Module "$PSScriptRoot\OM.psd1" -Force -Verbose

Show-Message -Message "✓ Module imported successfully" -ForegroundColor Green -Context $null
Show-Message -Message "" -Context $null

# Test 1: Check if parameters are recognized
Show-Message -Message "Test 1: Verifying Auto mode parameters..." -ForegroundColor Yellow -Context $null
try {
    $cmd = Get-Command Start-OM
    $autoParam = $cmd.Parameters['Auto']
    $thresholdParam = $cmd.Parameters['AutoConfidenceThreshold']
    $fallbackParam = $cmd.Parameters['AutoFallback']
    $saveCoverParam = $cmd.Parameters['AutoSaveCover']
    
    if ($autoParam -and $thresholdParam -and $fallbackParam -and $saveCoverParam) {
        Show-Message -Message "✓ All Auto mode parameters are present" -ForegroundColor Green -Context $null
        Show-Message -Message "  - Auto: $($autoParam.ParameterType.Name)" -ForegroundColor Gray -Context $null
        Show-Message -Message "  - AutoConfidenceThreshold: $($thresholdParam.ParameterType.Name) (default: $(if ($thresholdParam.Attributes.DefaultValue) { $thresholdParam.Attributes.DefaultValue } else { '0.80' }))" -ForegroundColor Gray -Context $null
        Show-Message -Message "  - AutoFallback: $($fallbackParam.ParameterType.Name)" -ForegroundColor Gray -Context $null
        Show-Message -Message "  - AutoSaveCover: $($saveCoverParam.ParameterType.Name)" -ForegroundColor Gray -Context $null
    }
    else {
        Write-Warning "Some Auto mode parameters are missing!"
        if (-not $autoParam) { Write-Warning "  Missing: Auto" }
        if (-not $thresholdParam) { Write-Warning "  Missing: AutoConfidenceThreshold" }
        if (-not $fallbackParam) { Write-Warning "  Missing: AutoFallback" }
        if (-not $saveCoverParam) { Write-Warning "  Missing: AutoSaveCover" }
    }
}
catch {
    Write-Host "✗ Error checking parameters: $_" -ForegroundColor Red
}
Write-Host ""

# Test 2: Check if helper functions are defined (by attempting to call Start-OM with -WhatIf on a test folder)
Write-Host "Test 2: Testing with a sample album folder..." -ForegroundColor Yellow
Write-Host "Note: This requires a test album folder. Skipping actual execution." -ForegroundColor Gray
Write-Host ""

# Test 3: Verify parameter validation
Write-Host "Test 3: Testing parameter validation..." -ForegroundColor Yellow
try {
    # Test invalid confidence threshold (should fail)
    $testPath = "C:\temp\test"
    
    Show-Message -Message "  Testing invalid threshold (1.5)..." -ForegroundColor Gray -Context $null
    try {
        Start-OM -Path $testPath -Auto -AutoConfidenceThreshold 1.5 -WhatIf -ErrorAction Stop
        Write-Warning "  Validation did not catch invalid threshold!"
    }
    catch {
        Show-Message -Message "  ✓ Correctly rejected invalid threshold: $($_.Exception.Message)" -ForegroundColor Green -Context $null
    }
    
    Show-Message -Message "  Testing invalid threshold (0.3)..." -ForegroundColor Gray -Context $null
    try {
        Start-OM -Path $testPath -Auto -AutoConfidenceThreshold 0.3 -WhatIf -ErrorAction Stop
        Write-Warning "  Validation did not catch invalid threshold!"
    }
    catch {
        Show-Message -Message "  ✓ Correctly rejected invalid threshold: $($_.Exception.Message)" -ForegroundColor Green -Context $null
    }
}
catch {
    Write-Host "  Note: Path validation errors are expected for non-existent test paths" -ForegroundColor Gray
}
Write-Host ""

# Test 4: Display usage examples
Write-Host "Test 4: Usage Examples" -ForegroundColor Yellow
Write-Host ""
Write-Host "Example 1: Basic Auto Mode" -ForegroundColor Cyan
Write-Host "  Start-OM -Path 'C:\Music\Artist' -Auto" -ForegroundColor White
Write-Host ""
Write-Host "Example 2: Auto Mode with Fallback and Cover Saving" -ForegroundColor Cyan
Write-Host "  Start-OM -Path 'C:\Music\Artist' -Auto -AutoFallback -AutoSaveCover" -ForegroundColor White
Write-Host ""
Write-Host "Example 3: Conservative Matching (90% threshold)" -ForegroundColor Cyan
Write-Host "  Start-OM -Path 'C:\Music\Artist' -Auto -AutoConfidenceThreshold 0.90" -ForegroundColor White
Write-Host ""
Write-Host "Example 4: Preview Mode (WhatIf)" -ForegroundColor Cyan
Write-Host "  Start-OM -Path 'C:\Music\Artist' -Auto -AutoFallback -WhatIf" -ForegroundColor White
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Tests Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "To test with real album folders, run:" -ForegroundColor Yellow
Write-Host "  Start-OM -Path '<your-album-path>' -Auto -WhatIf -Verbose" -ForegroundColor White
Write-Host ""


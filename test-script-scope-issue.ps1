# Test: Script scope variable access in scriptblock with StrictMode
# Demonstrates the pairedTracks scope issue

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Ensure Show-Message helper available when running standalone
if (-not (Get-Command -Name Show-Message -ErrorAction SilentlyContinue)) {
    $p = Join-Path $PSScriptRoot 'Private\Utils\Show-Message.ps1'
    if (Test-Path $p) { . $p }
}

Show-Message -Message "`n=== Test: Script Scope Variable Access ===" -ForegroundColor Cyan -Context $null

# Simulate Start-OM structure: local variable in function
function Test-ScopeIssue {
    [CmdletBinding()]
    param()
    
    Set-StrictMode -Version Latest
    
    # This is how Start-OM declares pairedTracks (local scope)
    $pairedTracks = @(
        [PSCustomObject]@{ Name = "Track 1" },
        [PSCustomObject]@{ Name = "Track 2" }
    )
    
    Show-Message -Message "Local pairedTracks initialized: $($pairedTracks.Count) items" -ForegroundColor Green -Context $null
    
    # Scriptblock that tries to access $script:pairedTracks
    $testScriptblock = {
        param($testName)
        
        Show-Message -Message "`n--- $testName ---" -ForegroundColor Yellow -Context $null
        
        # This will FAIL with StrictMode if $script:pairedTracks doesn't exist
        try {
            if ($script:pairedTracks -and $script:pairedTracks.Count -gt 0) {
                Show-Message -Message "✓ script:pairedTracks exists: $($script:pairedTracks.Count) items" -ForegroundColor Green -Context $null
            } else {
                Show-Message -Message "script:pairedTracks is null or empty" -ForegroundColor Gray -Context $null
            }
        }
        catch {
            Show-Message -Message "❌ ERROR accessing script:pairedTracks: $($_.Exception.Message)" -ForegroundColor Red -Context $null
            return $false
        }
        return $true
    }
    
    # Test 1: Invoke scriptblock with local variable only
    Show-Message -Message "`nTest 1: Local `$pairedTracks only (no script scope)" -ForegroundColor Cyan -Context $null
    $result1 = & $testScriptblock "Access script:pairedTracks"
    
    # Test 2: Now create script-scope variable and try again
    Show-Message -Message "`nTest 2: After creating `$script:pairedTracks" -ForegroundColor Cyan -Context $null
    $script:pairedTracks = $pairedTracks
    $result2 = & $testScriptblock "Access script:pairedTracks (now exists)"
    
    return @{
        Test1Passed = $result1
        Test2Passed = $result2
    }
}

# Run test
$results = Test-ScopeIssue

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Test 1 (local only): $(if ($results.Test1Passed) { '✅ PASSED' } else { '❌ FAILED' })"
Write-Host "Test 2 (script scope): $(if ($results.Test2Passed) { '✅ PASSED' } else { '❌ FAILED' })"

if (-not $results.Test1Passed -and $results.Test2Passed) {
    Write-Host "`n✅ Test proves the issue: script:variable fails with StrictMode when not initialized at script scope" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n❌ Unexpected test result" -ForegroundColor Red
    exit 1
}


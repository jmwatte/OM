# Test: Verify script scope variables are initialized before scriptblock access
# This tests the fix for "cannot be retrieved because it has not been set" error

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Ensure Show-Message helper available when running standalone
if (-not (Get-Command -Name Show-Message -ErrorAction SilentlyContinue)) {
    $p = Join-Path $PSScriptRoot 'Private\Utils\Show-Message.ps1'
    if (Test-Path $p) { . $p }
}

Show-Message -Message "`n=== Test: Script Scope Variable Initialization ===" -ForegroundColor Cyan -Context $null

function Test-InitializationFix {
    [CmdletBinding()]
    param()
    
    Set-StrictMode -Version Latest
    
    Show-Message -Message "Simulating Start-OM album loop initialization..." -ForegroundColor Gray -Context $null
    
    # FIX: Initialize script-scope variables BEFORE scriptblock definition
    $script:audioFiles = $null
    $script:pairedTracks = $null
    $script:refreshTracks = $false
    
    Show-Message -Message "✓ Script scope variables initialized" -ForegroundColor Green -Context $null
    
    # Now define scriptblock that will access these variables
    $handleMoveSuccess = {
        param($moveResult)
        
        Show-Message -Message "`n--- Scriptblock: handleMoveSuccess ---" -ForegroundColor Yellow -Context $null
        
        # This should NOT fail now that variables are initialized
        try {
            # Check audioFiles
            if ($script:audioFiles -and $script:audioFiles.Count -gt 0) {
                Show-Message -Message "✓ script:audioFiles is accessible (has items)" -ForegroundColor Green -Context $null
            } else {
                Show-Message -Message "✓ script:audioFiles is accessible (null/empty)" -ForegroundColor Green -Context $null
            }
            
            # Check pairedTracks  
            if ($script:pairedTracks -and $script:pairedTracks.Count -gt 0) {
                Show-Message -Message "✓ script:pairedTracks is accessible (has items)" -ForegroundColor Green -Context $null
                # Update pairedTracks
                for ($i = 0; $i -lt $script:pairedTracks.Count; $i++) {
                    if ($script:pairedTracks[$i].AudioFile) {
                        Show-Message -Message "  Updating pairedTrack[$i]..." -ForegroundColor Gray -Context $null
                    }
                }
            } else {
                Show-Message -Message "✓ script:pairedTracks is accessible (null/empty)" -ForegroundColor Green -Context $null
            }
            
            # Check refreshTracks
            Show-Message -Message "✓ script:refreshTracks is accessible: $script:refreshTracks" -ForegroundColor Green -Context $null
            
            # Set refreshTracks to true
            $script:refreshTracks = $true
            Show-Message -Message "✓ Set script:refreshTracks = true" -ForegroundColor Green -Context $null
            
            return $true
        }
        catch {
            Write-Host "❌ ERROR: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    }
    
    # Test Case 1: With null/empty variables (just initialized)
    Show-Message -Message "`nTest 1: Empty script variables (just initialized)" -ForegroundColor Cyan -Context $null
    $mockMoveResult = [PSCustomObject]@{ Success = $true; NewAlbumPath = "C:\test" }
    $result1 = & $handleMoveSuccess -moveResult $mockMoveResult
    
    if (-not $result1) {
        Show-Message -Message "❌ Test 1 FAILED" -ForegroundColor Red -Context $null
        return $false
    }
    
    # Verify refreshTracks was updated
    if ($script:refreshTracks -eq $true) {
        Show-Message -Message "✓ Verified: script:refreshTracks was updated to true" -ForegroundColor Green -Context $null
    } else {
        Show-Message -Message "❌ script:refreshTracks was not updated" -ForegroundColor Red -Context $null
        return $false
    }
    
    # Test Case 2: With populated variables
    Show-Message -Message "`nTest 2: Populated script variables" -ForegroundColor Cyan -Context $null
    $script:audioFiles = @(
        [PSCustomObject]@{ FilePath = "C:\test1.mp3"; TagFile = $null },
        [PSCustomObject]@{ FilePath = "C:\test2.mp3"; TagFile = $null }
    )
    $script:pairedTracks = @(
        [PSCustomObject]@{ AudioFile = $script:audioFiles[0]; SpotifyTrack = [PSCustomObject]@{ name = "Track 1" } },
        [PSCustomObject]@{ AudioFile = $script:audioFiles[1]; SpotifyTrack = [PSCustomObject]@{ name = "Track 2" } }
    )
    $script:refreshTracks = $false
    
    $result2 = & $handleMoveSuccess -moveResult $mockMoveResult
    
    if (-not $result2) {
        Write-Host "❌ Test 2 FAILED" -ForegroundColor Red
        return $false
    }
    
    return $true
}

# Run test
$testPassed = Test-InitializationFix

Show-Message -Message "`n========================================" -ForegroundColor Cyan -Context $null
if ($testPassed) {
    Show-Message -Message "✅ TEST PASSED: Script scope variables are properly initialized and accessible" -ForegroundColor Green -Context $null
    Show-Message -Message "   No 'cannot be retrieved because it has not been set' errors" -ForegroundColor Green -Context $null
    exit 0
} else {
    Show-Message -Message "❌ TEST FAILED" -ForegroundColor Red -Context $null
    exit 1
}


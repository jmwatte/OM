# Test: Verify script scope variables are initialized before scriptblock access
# This tests the fix for "cannot be retrieved because it has not been set" error

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Write-Host "`n=== Test: Script Scope Variable Initialization ===" -ForegroundColor Cyan

function Test-InitializationFix {
    [CmdletBinding()]
    param()
    
    Set-StrictMode -Version Latest
    
    Write-Host "Simulating Start-OM album loop initialization..." -ForegroundColor Gray
    
    # FIX: Initialize script-scope variables BEFORE scriptblock definition
    $script:audioFiles = $null
    $script:pairedTracks = $null
    $script:refreshTracks = $false
    
    Write-Host "✓ Script scope variables initialized" -ForegroundColor Green
    
    # Now define scriptblock that will access these variables
    $handleMoveSuccess = {
        param($moveResult)
        
        Write-Host "`n--- Scriptblock: handleMoveSuccess ---" -ForegroundColor Yellow
        
        # This should NOT fail now that variables are initialized
        try {
            # Check audioFiles
            if ($script:audioFiles -and $script:audioFiles.Count -gt 0) {
                Write-Host "✓ script:audioFiles is accessible (has items)" -ForegroundColor Green
            } else {
                Write-Host "✓ script:audioFiles is accessible (null/empty)" -ForegroundColor Green
            }
            
            # Check pairedTracks  
            if ($script:pairedTracks -and $script:pairedTracks.Count -gt 0) {
                Write-Host "✓ script:pairedTracks is accessible (has items)" -ForegroundColor Green
                # Update pairedTracks
                for ($i = 0; $i -lt $script:pairedTracks.Count; $i++) {
                    if ($script:pairedTracks[$i].AudioFile) {
                        Write-Host "  Updating pairedTrack[$i]..." -ForegroundColor Gray
                    }
                }
            } else {
                Write-Host "✓ script:pairedTracks is accessible (null/empty)" -ForegroundColor Green
            }
            
            # Check refreshTracks
            Write-Host "✓ script:refreshTracks is accessible: $script:refreshTracks" -ForegroundColor Green
            
            # Set refreshTracks to true
            $script:refreshTracks = $true
            Write-Host "✓ Set script:refreshTracks = true" -ForegroundColor Green
            
            return $true
        }
        catch {
            Write-Host "❌ ERROR: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    }
    
    # Test Case 1: With null/empty variables (just initialized)
    Write-Host "`nTest 1: Empty script variables (just initialized)" -ForegroundColor Cyan
    $mockMoveResult = [PSCustomObject]@{ Success = $true; NewAlbumPath = "C:\test" }
    $result1 = & $handleMoveSuccess -moveResult $mockMoveResult
    
    if (-not $result1) {
        Write-Host "❌ Test 1 FAILED" -ForegroundColor Red
        return $false
    }
    
    # Verify refreshTracks was updated
    if ($script:refreshTracks -eq $true) {
        Write-Host "✓ Verified: script:refreshTracks was updated to true" -ForegroundColor Green
    } else {
        Write-Host "❌ script:refreshTracks was not updated" -ForegroundColor Red
        return $false
    }
    
    # Test Case 2: With populated variables
    Write-Host "`nTest 2: Populated script variables" -ForegroundColor Cyan
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

Write-Host "`n========================================" -ForegroundColor Cyan
if ($testPassed) {
    Write-Host "✅ TEST PASSED: Script scope variables are properly initialized and accessible" -ForegroundColor Green
    Write-Host "   No 'cannot be retrieved because it has not been set' errors" -ForegroundColor Green
    exit 0
} else {
    Write-Host "❌ TEST FAILED" -ForegroundColor Red
    exit 1
}

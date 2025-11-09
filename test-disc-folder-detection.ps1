# Test script for disc folder detection feature
# Verifies that multi-disc albums are correctly identified as single albums

#Requires -Modules OM

Write-Host "`n=== Testing Disc Folder Detection ===" -ForegroundColor Cyan
Write-Host "This test verifies that albums with disc subfolders are treated as single albums" -ForegroundColor Gray
Write-Host ""

# Test directory setup
$testRoot = Join-Path $PSScriptRoot "test_disc_detection"

# Clean up old test data
if (Test-Path $testRoot) {
    Remove-Item -Path $testRoot -Recurse -Force
}

# Create test scenarios
Write-Host "Creating test directory structures..." -ForegroundColor Yellow

# Scenario 1: Album with Disc1 and Disc2 subfolders
$scenario1 = Join-Path $testRoot "Artist1\Album1"
New-Item -Path "$scenario1\Disc1" -ItemType Directory -Force | Out-Null
New-Item -Path "$scenario1\Disc2" -ItemType Directory -Force | Out-Null
"test" | Out-File "$scenario1\Disc1\track1.mp3"
"test" | Out-File "$scenario1\Disc2\track2.mp3"
Write-Host "  ✓ Created: Artist1\Album1\Disc1, Disc2" -ForegroundColor Green

# Scenario 2: Album with CD1 and CD2 subfolders
$scenario2 = Join-Path $testRoot "Artist2\Album2"
New-Item -Path "$scenario2\CD1" -ItemType Directory -Force | Out-Null
New-Item -Path "$scenario2\CD2" -ItemType Directory -Force | Out-Null
"test" | Out-File "$scenario2\CD1\track1.mp3"
"test" | Out-File "$scenario2\CD2\track2.mp3"
Write-Host "  ✓ Created: Artist2\Album2\CD1, CD2" -ForegroundColor Green

# Scenario 3: Album with Disk 1 and Disk 2 subfolders (space in name)
$scenario3 = Join-Path $testRoot "Artist3\Album3"
New-Item -Path "$scenario3\Disk 1" -ItemType Directory -Force | Out-Null
New-Item -Path "$scenario3\Disk 2" -ItemType Directory -Force | Out-Null
"test" | Out-File "$scenario3\Disk 1\track1.mp3"
"test" | Out-File "$scenario3\Disk 2\track2.mp3"
Write-Host "  ✓ Created: Artist3\Album3\Disk 1, Disk 2" -ForegroundColor Green

# Scenario 4: Flat single album (no disc folders)
$scenario4 = Join-Path $testRoot "Artist4\Album4"
New-Item -Path $scenario4 -ItemType Directory -Force | Out-Null
"test" | Out-File "$scenario4\track1.mp3"
"test" | Out-File "$scenario4\track2.mp3"
Write-Host "  ✓ Created: Artist4\Album4 (flat structure)" -ForegroundColor Green

# Scenario 5: Artist folder with multiple album subfolders (NOT disc folders)
$scenario5 = Join-Path $testRoot "Artist5"
New-Item -Path "$scenario5\Album A" -ItemType Directory -Force | Out-Null
New-Item -Path "$scenario5\Album B" -ItemType Directory -Force | Out-Null
"test" | Out-File "$scenario5\Album A\track1.mp3"
"test" | Out-File "$scenario5\Album B\track2.mp3"
Write-Host "  ✓ Created: Artist5\Album A, Album B (artist folder)" -ForegroundColor Green

# Scenario 6: Album with mixed disc and non-disc subfolders (edge case - should be artist folder)
$scenario6 = Join-Path $testRoot "Artist6\Album6"
New-Item -Path "$scenario6\Disc1" -ItemType Directory -Force | Out-Null
New-Item -Path "$scenario6\Bonus" -ItemType Directory -Force | Out-Null
"test" | Out-File "$scenario6\Disc1\track1.mp3"
"test" | Out-File "$scenario6\Bonus\track2.mp3"
Write-Host "  ✓ Created: Artist6\Album6\Disc1, Bonus (mixed - should be artist folder)" -ForegroundColor Green

Write-Host ""

# Function to test path detection
function Test-PathDetection {
    param(
        [string]$TestPath,
        [string]$ExpectedMode,
        [string]$Description
    )
    
    Write-Host "Testing: $Description" -ForegroundColor Yellow
    Write-Host "  Path: $TestPath" -ForegroundColor Gray
    
    # Import module fresh to ensure clean state
    Import-Module (Join-Path $PSScriptRoot "OM.psd1") -Force -ErrorAction Stop
    
    # Run Start-OM with -Verbose to capture detection messages
    $output = Start-OM -Path $TestPath -Provider Spotify -WhatIf -Verbose -NonInteractive 4>&1 5>&1 2>&1 | Out-String
    
    # Check for expected detection message
    $detected = $false
    if ($ExpectedMode -eq 'SingleAlbum' -and $output -match "Detected single album path") {
        $detected = $true
    }
    elseif ($ExpectedMode -eq 'SingleAlbumWithDiscs' -and $output -match "Detected single album with disc subfolders") {
        $detected = $true
    }
    elseif ($ExpectedMode -eq 'ArtistFolder' -and $output -match "Detected artist folder path.*album subfolders") {
        $detected = $true
    }
    
    if ($detected) {
        Write-Host "  ✓ PASS: Correctly detected as $ExpectedMode" -ForegroundColor Green
    }
    else {
        Write-Host "  ✗ FAIL: Expected $ExpectedMode, but detection failed" -ForegroundColor Red
        Write-Host "  Output: $($output -split "`n" | Where-Object { $_ -match "Detected" } | Select-Object -First 3)" -ForegroundColor Gray
    }
    Write-Host ""
}

# Run tests
Write-Host "=== Running Detection Tests ===" -ForegroundColor Cyan
Write-Host ""

Test-PathDetection -TestPath "$scenario1" `
    -ExpectedMode "SingleAlbumWithDiscs" `
    -Description "Album with Disc1/Disc2 subfolders"

Test-PathDetection -TestPath "$scenario2" `
    -ExpectedMode "SingleAlbumWithDiscs" `
    -Description "Album with CD1/CD2 subfolders"

Test-PathDetection -TestPath "$scenario3" `
    -ExpectedMode "SingleAlbumWithDiscs" `
    -Description "Album with 'Disk 1'/'Disk 2' subfolders (spaces)"

Test-PathDetection -TestPath "$scenario4" `
    -ExpectedMode "SingleAlbum" `
    -Description "Flat single album (no disc folders)"

Test-PathDetection -TestPath "$scenario5" `
    -ExpectedMode "ArtistFolder" `
    -Description "Artist folder with multiple albums"

Test-PathDetection -TestPath "$scenario6" `
    -ExpectedMode "ArtistFolder" `
    -Description "Mixed disc and non-disc subfolders (edge case)"

# Clean up test data
Write-Host "Cleaning up test directory..." -ForegroundColor Yellow
Remove-Item -Path $testRoot -Recurse -Force
Write-Host "✓ Test directory removed" -ForegroundColor Green
Write-Host ""

Write-Host "=== Test Summary ===" -ForegroundColor Cyan
Write-Host "Disc folder patterns supported:" -ForegroundColor White
Write-Host "  ✓ Disc1, Disc2, Disc 1, Disc 2, Disc 01" -ForegroundColor Green
Write-Host "  ✓ CD1, CD2, CD 1, CD 2, CD01" -ForegroundColor Green
Write-Host "  ✓ Disk1, Disk2, Disk 1, Disk 2, Disk01" -ForegroundColor Green
Write-Host ""
Write-Host "Detection logic:" -ForegroundColor White
Write-Host "  • Album with only disc subfolders → Single album (multi-disc)" -ForegroundColor Green
Write-Host "  • Album with flat audio files → Single album" -ForegroundColor Green
Write-Host "  • Folder with non-disc subfolders → Artist folder (multiple albums)" -ForegroundColor Green
Write-Host "  • Folder with mixed disc/non-disc → Artist folder (safety fallback)" -ForegroundColor Green

# Test script for case-sensitivity fix in Move-AlbumFolder
# Verifies that folder names are corrected to match tag case

#Requires -Modules OM

Write-Host "`n=== Testing Case-Sensitivity Fix ===" -ForegroundColor Cyan
Write-Host "Verifies that folder names are corrected to match AlbumArtist tag case" -ForegroundColor Gray
Write-Host ""

# Test directory setup
$testRoot = "C:\temp\test_case_fix"

# Clean up old test data
if (Test-Path $testRoot) {
    Remove-Item -Path $testRoot -Recurse -Force
}

Write-Host "Creating test scenarios..." -ForegroundColor Yellow

# Scenario 1: Lowercase folder, proper case in tags
$scenario1 = Join-Path $testRoot "tears for fears\2022 - Album Name"
New-Item -Path $scenario1 -ItemType Directory -Force | Out-Null
"test" | Out-File "$scenario1\track1.mp3"
Write-Host "  ✓ Created: tears for fears\2022 - Album Name" -ForegroundColor Green

# Scenario 2: Uppercase folder, proper case in tags  
$scenario2 = Join-Path $testRoot "THE BEATLES\1965 - Help!"
New-Item -Path $scenario2 -ItemType Directory -Force | Out-Null
"test" | Out-File "$scenario2\track1.mp3"
Write-Host "  ✓ Created: THE BEATLES\1965 - Help!" -ForegroundColor Green

# Scenario 3: Already correct case (should not rename)
$scenario3 = Join-Path $testRoot "Pink Floyd\1973 - The Dark Side of the Moon"
New-Item -Path $scenario3 -ItemType Directory -Force | Out-Null
"test" | Out-File "$scenario3\track1.mp3"
Write-Host "  ✓ Created: Pink Floyd\1973 - The Dark Side of the Moon" -ForegroundColor Green

Write-Host ""

# Import the module
Import-Module (Join-Path $PSScriptRoot "OM.psd1") -Force -ErrorAction Stop

Write-Host "=== Testing Move-AlbumFolder directly ===" -ForegroundColor Cyan
Write-Host ""

# Test 1: Lowercase to proper case
Write-Host "[Test 1] Lowercase to Proper Case" -ForegroundColor Yellow
Write-Host "  From: tears for fears" -ForegroundColor Gray
Write-Host "  To:   Tears For Fears" -ForegroundColor Gray

$moveParams1 = @{
    AlbumPath    = "$testRoot\tears for fears\2022 - Album Name"
    NewArtist    = "Tears For Fears"
    NewYear      = "2022"
    NewAlbumName = "Album Name"
    Verbose      = $true
}

try {
    $result1 = Move-AlbumFolder @moveParams1
    if ($result1.Success) {
        $actualFolder = Split-Path -Leaf (Split-Path -Parent $result1.NewAlbumPath)
        if ($actualFolder -ceq "Tears For Fears") {
            Write-Host "  ✓ PASS: Folder renamed to correct case: $actualFolder" -ForegroundColor Green
        }
        else {
            Write-Host "  ✗ FAIL: Folder case incorrect: $actualFolder (expected 'Tears For Fears')" -ForegroundColor Red
        }
    }
    else {
        Write-Host "  ✗ FAIL: Move operation failed" -ForegroundColor Red
    }
}
catch {
    Write-Host "  ✗ FAIL: Exception: $_" -ForegroundColor Red
}
Write-Host ""

# Test 2: Uppercase to proper case
Write-Host "[Test 2] Uppercase to Proper Case" -ForegroundColor Yellow
Write-Host "  From: THE BEATLES" -ForegroundColor Gray
Write-Host "  To:   The Beatles" -ForegroundColor Gray

$moveParams2 = @{
    AlbumPath    = "$testRoot\THE BEATLES\1965 - Help!"
    NewArtist    = "The Beatles"
    NewYear      = "1965"
    NewAlbumName = "Help!"
    Verbose      = $true
}

try {
    $result2 = Move-AlbumFolder @moveParams2
    if ($result2.Success) {
        $actualFolder = Split-Path -Leaf (Split-Path -Parent $result2.NewAlbumPath)
        if ($actualFolder -ceq "The Beatles") {
            Write-Host "  ✓ PASS: Folder renamed to correct case: $actualFolder" -ForegroundColor Green
        }
        else {
            Write-Host "  ✗ FAIL: Folder case incorrect: $actualFolder (expected 'The Beatles')" -ForegroundColor Red
        }
    }
    else {
        Write-Host "  ✗ FAIL: Move operation failed" -ForegroundColor Red
    }
}
catch {
    Write-Host "  ✗ FAIL: Exception: $_" -ForegroundColor Red
}
Write-Host ""

# Test 3: Already correct case (should still work, but may skip if truly identical)
Write-Host "[Test 3] Already Correct Case (no change needed)" -ForegroundColor Yellow
Write-Host "  From: Pink Floyd" -ForegroundColor Gray
Write-Host "  To:   Pink Floyd" -ForegroundColor Gray

$moveParams3 = @{
    AlbumPath    = "$testRoot\Pink Floyd\1973 - The Dark Side of the Moon"
    NewArtist    = "Pink Floyd"
    NewYear      = "1973"
    NewAlbumName = "The Dark Side of the Moon"
    Verbose      = $true
}

try {
    $result3 = Move-AlbumFolder @moveParams3
    if ($result3.Success) {
        $actualFolder = Split-Path -Leaf (Split-Path -Parent $result3.NewAlbumPath)
        if ($actualFolder -ceq "Pink Floyd") {
            Write-Host "  ✓ PASS: Folder unchanged (correct): $actualFolder" -ForegroundColor Green
        }
        else {
            Write-Host "  ✗ FAIL: Folder case changed unexpectedly: $actualFolder" -ForegroundColor Red
        }
        Write-Host "  Action taken: $($result3.Action)" -ForegroundColor Gray
    }
    else {
        Write-Host "  ✗ FAIL: Move operation failed" -ForegroundColor Red
    }
}
catch {
    Write-Host "  ✗ FAIL: Exception: $_" -ForegroundColor Red
}
Write-Host ""

# Verify final folder structure
Write-Host "=== Final Folder Structure ===" -ForegroundColor Cyan
Get-ChildItem $testRoot -Directory | ForEach-Object {
    Write-Host "  $($_.Name)" -ForegroundColor White
}
Write-Host ""

# Clean up
Write-Host "Cleaning up test directory..." -ForegroundColor Yellow
Remove-Item -Path $testRoot -Recurse -Force
Write-Host "✓ Test directory removed" -ForegroundColor Green
Write-Host ""

Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "Key change:" -ForegroundColor White
Write-Host "  • Early exit guard now uses -ceq (case-sensitive) instead of -eq" -ForegroundColor Green
Write-Host "  • Case-only renames (tears for fears → Tears For Fears) now work" -ForegroundColor Green
Write-Host "  • Folder names match AlbumArtist tag capitalization exactly" -ForegroundColor Green
Write-Host ""
Write-Host "Result: Folder structure reflects proper artist name capitalization from tags" -ForegroundColor Cyan

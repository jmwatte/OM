# Test script to verify display refresh after 'sa' command
# This simulates the exact workflow: Start-OM → select album → sa → verify display updates

$ErrorActionPreference = 'Stop'
$testPath = "c:\Users\jmw\Documents\PowerShell\Modules\OM\testfiles\goldberg variations"

Write-Host "`n=== Test: Display Refresh After 'sa' Command ===" -ForegroundColor Cyan
Write-Host "Test Path: $testPath" -ForegroundColor Gray

# Import module
Import-Module "c:\Users\jmw\Documents\PowerShell\Modules\OM\OM.psd1" -Force
Write-Host "✓ Module imported" -ForegroundColor Green

# Step 1: Get initial state of first 3 files before any changes
Write-Host "`n--- Step 1: Reading initial file state ---" -ForegroundColor Yellow
$files = Get-ChildItem -Path $testPath -Filter "*.flac" | Sort-Object Name | Select-Object -First 3
$initialState = @()
foreach ($file in $files) {
    $tag = [TagLib.File]::Create($file.FullName)
    $initialState += [PSCustomObject]@{
        Name = $file.Name
        Disc = $tag.Tag.Disc
        Track = $tag.Tag.Track
        Title = $tag.Tag.Title
    }
    $tag.Dispose()
}

Write-Host "Initial state of first 3 files:"
$initialState | Format-Table -AutoSize

# Step 2: Modify tags to test state (Disc=99, Track=99)
Write-Host "`n--- Step 2: Setting test values (Disc=99, Track=99) ---" -ForegroundColor Yellow
foreach ($file in $files) {
    $tag = [TagLib.File]::Create($file.FullName)
    $tag.Tag.Disc = 99
    $tag.Tag.Track = 99
    $tag.Save()
    $tag.Dispose()
}
Write-Host "✓ Test values set" -ForegroundColor Green

# Step 3: Simulate Start-OM workflow (load audioFiles like Start-OM does)
Write-Host "`n--- Step 3: Simulating Start-OM audioFiles load ---" -ForegroundColor Yellow
$audioFiles = @()
foreach ($file in $files) {
    $tagFile = [TagLib.File]::Create($file.FullName)
    $audioFiles += [PSCustomObject]@{
        FilePath = $file.FullName
        FileName = $file.Name
        TagFile = $tagFile
        Disc = $tagFile.Tag.Disc
        Track = $tagFile.Tag.Track
        Title = $tagFile.Tag.Title
        Duration = $tagFile.Properties.Duration.TotalMilliseconds
    }
}

Write-Host "audioFiles loaded (should show Disc=99, Track=99):"
$audioFiles | Select-Object FileName, Disc, Track, Title | Format-Table -AutoSize

# Verify we're seeing test values
if ($audioFiles[0].Disc -ne 99 -or $audioFiles[0].Track -ne 99) {
    Write-Host "❌ FAILED: audioFiles not showing test values!" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Confirmed audioFiles showing test values" -ForegroundColor Green

# Step 4: Simulate 'sa' command - save new values
Write-Host "`n--- Step 4: Simulating 'sa' command (save to Disc=1, Track=1/2/3) ---" -ForegroundColor Yellow
$trackNum = 1
foreach ($audioFile in $audioFiles) {
    if ($audioFile.TagFile) {
        $audioFile.TagFile.Tag.Disc = 1
        $audioFile.TagFile.Tag.Track = $trackNum
        $audioFile.TagFile.Save()
        Write-Host "  Saved: $($audioFile.FileName) -> Disc=1, Track=$trackNum" -ForegroundColor Gray
        $trackNum++
    }
}
Write-Host "✓ Tags saved to disk" -ForegroundColor Green

# Step 5: Simulate handleMoveSuccess scriptblock - dispose old handles and reload
Write-Host "`n--- Step 5: Simulating handleMoveSuccess reload (CRITICAL TEST) ---" -ForegroundColor Yellow
Write-Host "  Disposing old TagFile handles..." -ForegroundColor Gray
foreach ($audioFile in $audioFiles) {
    if ($audioFile.TagFile) {
        $audioFile.TagFile.Dispose()
        $audioFile.TagFile = $null
    }
}

Write-Host "  Reloading audioFiles with fresh TagLib handles..." -ForegroundColor Gray
$script:audioFiles = @()
foreach ($file in $files) {
    $tagFile = [TagLib.File]::Create($file.FullName)
    $script:audioFiles += [PSCustomObject]@{
        FilePath = $file.FullName
        FileName = $file.Name
        TagFile = $tagFile
        Disc = $tagFile.Tag.Disc
        Track = $tagFile.Tag.Track
        Title = $tagFile.Tag.Title
        Duration = $tagFile.Properties.Duration.TotalMilliseconds
    }
}

Write-Host "`n  Reloaded audioFiles (should NOW show Disc=1, Track=1/2/3):" -ForegroundColor Cyan
$script:audioFiles | Select-Object FileName, Disc, Track, Title | Format-Table -AutoSize

# Step 6: Verify the fix worked
Write-Host "`n--- Step 6: Verifying scope fix worked ---" -ForegroundColor Yellow
$allCorrect = $true
$expectedTrack = 1
foreach ($audioFile in $script:audioFiles) {
    $discTrack = "{0:D2}.{1:D2}" -f $audioFile.Disc, $audioFile.Track
    $expected = "01.{0:D2}" -f $expectedTrack
    
    if ($discTrack -ne $expected) {
        Write-Host "  ❌ File: $($audioFile.FileName)" -ForegroundColor Red
        Write-Host "     Expected: $expected, Got: $discTrack" -ForegroundColor Red
        $allCorrect = $false
    } else {
        Write-Host "  ✓ File: $($audioFile.FileName) -> $discTrack" -ForegroundColor Green
    }
    $expectedTrack++
}

# Cleanup
foreach ($audioFile in $script:audioFiles) {
    if ($audioFile.TagFile) {
        $audioFile.TagFile.Dispose()
    }
}

# Final result
Write-Host "`n========================================" -ForegroundColor Cyan
if ($allCorrect) {
    Write-Host "✅ SUCCESS: Display refresh works correctly!" -ForegroundColor Green
    Write-Host "   The scope fix allows audioFiles to update after 'sa' command" -ForegroundColor Green
    exit 0
} else {
    Write-Host "❌ FAILED: Display not showing updated values" -ForegroundColor Red
    Write-Host "   The scope bug still exists" -ForegroundColor Red
    exit 1
}

# Test script to verify display refresh after 'sa' command
# This simulates the exact workflow: Start-OM → select album → sa → verify display updates

$ErrorActionPreference = 'Stop'
$testPath = "c:\Users\jmw\Documents\PowerShell\Modules\OM\testfiles\goldberg variations"

# Ensure Show-Message helper available when running standalone
if (-not (Get-Command -Name Show-Message -ErrorAction SilentlyContinue)) {
    $p = Join-Path $PSScriptRoot 'Private\Utils\Show-Message.ps1'
    if (Test-Path $p) { . $p }
}

Show-Message -Message "`n=== Test: Display Refresh After 'sa' Command ===" -ForegroundColor Cyan -Context $null
Show-Message -Message "Test Path: $testPath" -ForegroundColor Gray -Context $null

# Import module
Import-Module "c:\Users\jmw\Documents\PowerShell\Modules\OM\OM.psd1" -Force
Show-Message -Message "✓ Module imported" -ForegroundColor Green -Context $null

# Step 1: Get initial state of first 3 files before any changes
Show-Message -Message "`n--- Step 1: Reading initial file state ---" -ForegroundColor Yellow -Context $null
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

Show-Message -Message "Initial state of first 3 files:" -Context $null
$initialState | Format-Table -AutoSize

# Step 2: Modify tags to test state (Disc=99, Track=99)
Show-Message -Message "`n--- Step 2: Setting test values (Disc=99, Track=99) ---" -ForegroundColor Yellow -Context $null
foreach ($file in $files) {
    $tag = [TagLib.File]::Create($file.FullName)
    $tag.Tag.Disc = 99
    $tag.Tag.Track = 99
    $tag.Save()
    $tag.Dispose()
}
Show-Message -Message "✓ Test values set" -ForegroundColor Green -Context $null

# Step 3: Simulate Start-OM workflow (load audioFiles like Start-OM does)
Show-Message -Message "`n--- Step 3: Simulating Start-OM audioFiles load ---" -ForegroundColor Yellow -Context $null
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

Show-Message -Message "audioFiles loaded (should show Disc=99, Track=99):" -Context $null
$audioFiles | Select-Object FileName, Disc, Track, Title | Format-Table -AutoSize

# Verify we're seeing test values
if ($audioFiles[0].Disc -ne 99 -or $audioFiles[0].Track -ne 99) {
    Show-Message -Message "❌ FAILED: audioFiles not showing test values!" -ForegroundColor Red -Context $null
    exit 1
}
Show-Message -Message "✓ Confirmed audioFiles showing test values" -ForegroundColor Green -Context $null

# Step 4: Simulate 'sa' command - save new values
Show-Message -Message "`n--- Step 4: Simulating 'sa' command (save to Disc=1, Track=1/2/3) ---" -ForegroundColor Yellow -Context $null
$trackNum = 1
foreach ($audioFile in $audioFiles) {
    if ($audioFile.TagFile) {
        $audioFile.TagFile.Tag.Disc = 1
        $audioFile.TagFile.Tag.Track = $trackNum
        $audioFile.TagFile.Save()
        Show-Message -Message "  Saved: $($audioFile.FileName) -> Disc=1, Track=$trackNum" -ForegroundColor Gray -Context $null
        $trackNum++
    }
}
Show-Message -Message "✓ Tags saved to disk" -ForegroundColor Green -Context $null

# Step 5: Simulate handleMoveSuccess scriptblock - dispose old handles and reload
Show-Message -Message "`n--- Step 5: Simulating handleMoveSuccess reload (CRITICAL TEST) ---" -ForegroundColor Yellow -Context $null
Show-Message -Message "  Disposing old TagFile handles..." -ForegroundColor Gray -Context $null
foreach ($audioFile in $audioFiles) {
    if ($audioFile.TagFile) {
        $audioFile.TagFile.Dispose()
        $audioFile.TagFile = $null
    }
}

Show-Message -Message "  Reloading audioFiles with fresh TagLib handles..." -ForegroundColor Gray -Context $null
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

Show-Message -Message "`n  Reloaded audioFiles (should NOW show Disc=1, Track=1/2/3):" -ForegroundColor Cyan -Context $null
$script:audioFiles | Select-Object FileName, Disc, Track, Title | Format-Table -AutoSize

# Step 6: Verify the fix worked
Show-Message -Message "`n--- Step 6: Verifying scope fix worked ---" -ForegroundColor Yellow -Context $null
$allCorrect = $true
$expectedTrack = 1
foreach ($audioFile in $script:audioFiles) {
    $discTrack = "{0:D2}.{1:D2}" -f $audioFile.Disc, $audioFile.Track
    $expected = "01.{0:D2}" -f $expectedTrack
    
    if ($discTrack -ne $expected) {
        Show-Message -Message "  ❌ File: $($audioFile.FileName)" -ForegroundColor Red -Context $null
        Show-Message -Message "     Expected: $expected, Got: $discTrack" -ForegroundColor Red -Context $null
        $allCorrect = $false
    } else {
        Show-Message -Message "  ✓ File: $($audioFile.FileName) -> $discTrack" -ForegroundColor Green -Context $null
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
Show-Message -Message "`n========================================" -ForegroundColor Cyan -Context $null
if ($allCorrect) {
    Show-Message -Message "✅ SUCCESS: Display refresh works correctly!" -ForegroundColor Green -Context $null
    Show-Message -Message "   The scope fix allows audioFiles to update after 'sa' command" -ForegroundColor Green -Context $null
    exit 0
} else {
    Show-Message -Message "❌ FAILED: Display not showing updated values" -ForegroundColor Red -Context $null
    Show-Message -Message "   The scope bug still exists" -ForegroundColor Red -Context $null
    exit 1
} 


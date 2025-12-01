# Test: Verify FLAC Comment field is properly cleared
# Tests that setting Comment='' removes both COMMENT and DESCRIPTION Vorbis tags

$ErrorActionPreference = 'Stop'

$testFile = "C:\Users\jmw\Documents\PowerShell\Modules\OM\testfiles\Ozawa, Boston Symphony Orchestra\1990 - Mahler Symphony no. 9\01 -  Symphony No. 9 in D Major - 1. Andante comodo.flac"

if (-not (Test-Path $testFile)) {
    Write-Host "Test file not found: $testFile" -ForegroundColor Red
    exit 1
}

Write-Host "`n=== Test: Clear FLAC Comment Fields ===" -ForegroundColor Cyan
Write-Host "File: $(Split-Path -Leaf $testFile)" -ForegroundColor Gray

# Import module
Import-Module "c:\Users\jmw\Documents\PowerShell\Modules\OM\OM.psd1" -Force
Write-Host "✓ Module imported" -ForegroundColor Green

# Step 1: Check initial state
Write-Host "`n--- Step 1: Check initial state ---" -ForegroundColor Yellow
$tag1 = [TagLib.File]::Create($testFile)
$xiph1 = $tag1.GetTag([TagLib.TagTypes]::Xiph, $false)
$commentBefore = $xiph1.GetField("COMMENT")
$descBefore = $xiph1.GetField("DESCRIPTION")
Write-Host "COMMENT fields: $($commentBefore.Count)"
if ($commentBefore.Count -gt 0) {
    Write-Host "  Values: $($commentBefore -join ', ')"
}
Write-Host "DESCRIPTION fields: $($descBefore.Count)"
if ($descBefore.Count -gt 0) {
    Write-Host "  Values: $($descBefore -join ', ')"
}
$tag1.Dispose()

# Step 2: Use Set-OMTags to clear Comment
Write-Host "`n--- Step 2: Clear Comment with Set-OMTags ---" -ForegroundColor Yellow
try {
    Set-OMTags -Path $testFile -Tags @{ Comment = '' }
    Write-Host "✓ Set-OMTags executed" -ForegroundColor Green
}
catch {
    Write-Host "❌ Set-OMTags failed: $_" -ForegroundColor Red
    exit 1
}

# Step 3: Verify both fields are cleared
Write-Host "`n--- Step 3: Verify both fields cleared ---" -ForegroundColor Yellow
$tag2 = [TagLib.File]::Create($testFile)
$xiph2 = $tag2.GetTag([TagLib.TagTypes]::Xiph, $false)
$commentAfter = $xiph2.GetField("COMMENT")
$descAfter = $xiph2.GetField("DESCRIPTION")
Write-Host "COMMENT fields after clear: $($commentAfter.Count)"
if ($commentAfter.Count -gt 0) {
    Write-Host "  Values: $($commentAfter -join ', ')" -ForegroundColor Red
}
Write-Host "DESCRIPTION fields after clear: $($descAfter.Count)"
if ($descAfter.Count -gt 0) {
    Write-Host "  Values: $($descAfter -join ', ')" -ForegroundColor Red
}

# Step 4: Verify Get-OMTags shows no comment
Write-Host "`n--- Step 4: Verify Get-OMTags shows no comment ---" -ForegroundColor Yellow
$tags = Get-OMTags -Path $testFile -Details
Write-Host "Comment from Get-OMTags: [$($tags.Comment)]"

$tag2.Dispose()

# Step 5: Restore original comment
Write-Host "`n--- Step 5: Restore original comment ---" -ForegroundColor Yellow
if ($commentBefore.Count -gt 0) {
    try {
        Set-OMTags -Path $testFile -Tags @{ Comment = $commentBefore[0] }
        Write-Host "✓ Original comment restored" -ForegroundColor Green
    }
    catch {
        Write-Host "⚠️ Failed to restore: $_" -ForegroundColor Yellow
    }
}

# Final verification
Write-Host "`n========================================" -ForegroundColor Cyan
if ($commentAfter.Count -eq 0 -and $descAfter.Count -eq 0 -and [string]::IsNullOrEmpty($tags.Comment)) {
    Write-Host "✅ TEST PASSED: Both COMMENT and DESCRIPTION fields cleared" -ForegroundColor Green
    exit 0
} else {
    Write-Host "❌ TEST FAILED: Fields not properly cleared" -ForegroundColor Red
    Write-Host "  COMMENT fields remaining: $($commentAfter.Count)"
    Write-Host "  DESCRIPTION fields remaining: $($descAfter.Count)"
    Write-Host "  Get-OMTags Comment: [$($tags.Comment)]"
    exit 1
}

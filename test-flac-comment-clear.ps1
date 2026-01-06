# Test: Verify FLAC Comment field is properly cleared
# Tests that setting Comment='' removes both COMMENT and DESCRIPTION Vorbis tags

$ErrorActionPreference = 'Stop'

$testFile = "C:\Users\jmw\Documents\PowerShell\Modules\OM\testfiles\Ozawa, Boston Symphony Orchestra\1990 - Mahler Symphony no. 9\01 -  Symphony No. 9 in D Major - 1. Andante comodo.flac"

if (-not (Test-Path $testFile)) {
    Show-Message -Message "Test file not found: $testFile" -ForegroundColor Red -Context $null
    exit 1
}

# Ensure Show-Message helper available when running standalone
if (-not (Get-Command -Name Show-Message -ErrorAction SilentlyContinue)) {
    $p = Join-Path $PSScriptRoot 'Private\Utils\Show-Message.ps1'
    if (Test-Path $p) { . $p }
}

Show-Message -Message "`n=== Test: Clear FLAC Comment Fields ===" -ForegroundColor Cyan -Context $null
Show-Message -Message "File: $(Split-Path -Leaf $testFile)" -ForegroundColor Gray -Context $null

# Import module
Import-Module "c:\Users\jmw\Documents\PowerShell\Modules\OM\OM.psd1" -Force
Show-Message -Message "✓ Module imported" -ForegroundColor Green -Context $null

# Step 1: Check initial state
Show-Message -Message "`n--- Step 1: Check initial state ---" -ForegroundColor Yellow -Context $null
$tag1 = [TagLib.File]::Create($testFile)
$xiph1 = $tag1.GetTag([TagLib.TagTypes]::Xiph, $false)
$commentBefore = $xiph1.GetField("COMMENT")
$descBefore = $xiph1.GetField("DESCRIPTION")
Show-Message -Message "COMMENT fields: $($commentBefore.Count)" -Context $null
if ($commentBefore.Count -gt 0) {
    Show-Message -Message "  Values: $($commentBefore -join ', ')" -Context $null
}
Show-Message -Message "DESCRIPTION fields: $($descBefore.Count)" -Context $null
if ($descBefore.Count -gt 0) {
    Show-Message -Message "  Values: $($descBefore -join ', ')" -Context $null
}
$tag1.Dispose()

# Step 2: Use Set-OMTags to clear Comment
Show-Message -Message "`n--- Step 2: Clear Comment with Set-OMTags ---" -ForegroundColor Yellow -Context $null
try {
    Set-OMTags -Path $testFile -Tags @{ Comment = '' }
    Show-Message -Message "✓ Set-OMTags executed" -ForegroundColor Green -Context $null
}
catch {
    Show-Message -Message "❌ Set-OMTags failed: $_" -ForegroundColor Red -Context $null
    exit 1
}

# Step 3: Verify both fields are cleared
Show-Message -Message "`n--- Step 3: Verify both fields cleared ---" -ForegroundColor Yellow -Context $null
$tag2 = [TagLib.File]::Create($testFile)
$xiph2 = $tag2.GetTag([TagLib.TagTypes]::Xiph, $false)
$commentAfter = $xiph2.GetField("COMMENT")
$descAfter = $xiph2.GetField("DESCRIPTION")
Show-Message -Message "COMMENT fields after clear: $($commentAfter.Count)" -Context $null
if ($commentAfter.Count -gt 0) {
    Show-Message -Message "  Values: $($commentAfter -join ', ')" -ForegroundColor Red -Context $null
}
Show-Message -Message "DESCRIPTION fields after clear: $($descAfter.Count)" -Context $null
if ($descAfter.Count -gt 0) {
    Show-Message -Message "  Values: $($descAfter -join ', ')" -ForegroundColor Red -Context $null
}

# Step 4: Verify Get-OMTags shows no comment
Show-Message -Message "`n--- Step 4: Verify Get-OMTags shows no comment ---" -ForegroundColor Yellow -Context $null
$tags = Get-OMTags -Path $testFile -Details
Show-Message -Message "Comment from Get-OMTags: [$($tags.Comment)]" -Context $null

$tag2.Dispose()

# Step 5: Restore original comment
Show-Message -Message "`n--- Step 5: Restore original comment ---" -ForegroundColor Yellow -Context $null
if ($commentBefore.Count -gt 0) {
    try {
        Set-OMTags -Path $testFile -Tags @{ Comment = $commentBefore[0] }
        Show-Message -Message "✓ Original comment restored" -ForegroundColor Green -Context $null
    }
    catch {
        Show-Message -Message "⚠️ Failed to restore: $_" -ForegroundColor Yellow -Context $null
    }
}

# Final verification
Show-Message -Message "`n========================================" -ForegroundColor Cyan -Context $null
if ($commentAfter.Count -eq 0 -and $descAfter.Count -eq 0 -and [string]::IsNullOrEmpty($tags.Comment)) {
    Show-Message -Message "✅ TEST PASSED: Both COMMENT and DESCRIPTION fields cleared" -ForegroundColor Green -Context $null
    exit 0
} else {
    Show-Message -Message "❌ TEST FAILED: Fields not properly cleared" -ForegroundColor Red -Context $null
    Show-Message -Message "  COMMENT fields remaining: $($commentAfter.Count)" -Context $null
    Show-Message -Message "  DESCRIPTION fields remaining: $($descAfter.Count)" -Context $null
    Show-Message -Message "  Get-OMTags Comment: [$($tags.Comment)]" -Context $null
    exit 1
}


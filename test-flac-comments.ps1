# Test: Diagnose FLAC comment/description fields
# Check if file has multiple comment fields

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

Show-Message -Message "`n=== FLAC Comment Field Diagnostics ===" -ForegroundColor Cyan -Context $null
Show-Message -Message "File: $(Split-Path -Leaf $testFile)" -ForegroundColor Gray -Context $null

# Load with TagLib
$tag = [TagLib.File]::Create($testFile)

Show-Message -Message "`n--- TagLib Standard Properties ---" -ForegroundColor Yellow -Context $null
Show-Message -Message "Comment: [$($tag.Tag.Comment)]" -Context $null
Show-Message -Message "Description: [$($tag.Tag.Description)]" -Context $null

# Access the underlying Vorbis comment block directly
if ($tag -is [TagLib.Flac.File]) {
    Show-Message -Message "`n--- FLAC Vorbis Comment Block ---" -ForegroundColor Yellow -Context $null
    
    # Get all tags from the Vorbis comment
    $xiph = $tag.GetTag([TagLib.TagTypes]::Xiph, $false)
    if ($xiph) {
        Show-Message -Message "Xiph/Vorbis tag found" -ForegroundColor Green -Context $null
        
        # Check for COMMENT field (Vorbis standard)
        $commentFields = $xiph.GetField("COMMENT")
        if ($commentFields -and $commentFields.Count -gt 0) {
            Show-Message -Message "`nCOMMENT fields ($($commentFields.Count)):" -ForegroundColor Cyan -Context $null
            for ($i = 0; $i -lt $commentFields.Count; $i++) {
                Show-Message -Message "  [$i]: $($commentFields[$i])" -Context $null
            }
        } else {
            Show-Message -Message "No COMMENT fields found" -ForegroundColor Gray -Context $null
        }
        
        # Check for DESCRIPTION field (alternative field name)
        $descFields = $xiph.GetField("DESCRIPTION")
        if ($descFields -and $descFields.Count -gt 0) {
            Show-Message -Message "`nDESCRIPTION fields ($($descFields.Count)):" -ForegroundColor Cyan -Context $null
            for ($i = 0; $i -lt $descFields.Count; $i++) {
                Show-Message -Message "  [$i]: $($descFields[$i])" -Context $null
            }
        } else {
            Show-Message -Message "No DESCRIPTION fields found" -ForegroundColor Gray -Context $null
        }
        
        # List ALL vorbis comment fields
        Show-Message -Message "`n--- All Vorbis Comment Fields ---" -ForegroundColor Yellow -Context $null
        $allFields = $xiph.FieldNames
        foreach ($fieldName in $allFields) {
            $values = $xiph.GetField($fieldName)
            if ($values.Count -eq 1) {
                Show-Message -Message "$fieldName = $($values[0])" -Context $null
            } else {
                Show-Message -Message "$fieldName = [" -NoNewline -Context $null
                Show-Message -Message ($values -join ", ") -NoNewline -Context $null
                Show-Message -Message "]" -Context $null
            }
        }
    } else {
        Show-Message -Message "No Xiph/Vorbis comment block found" -ForegroundColor Red -Context $null
    }
}

# Now test clearing the comment
Show-Message -Message "`n`n=== Test: Clear Comment Field ===" -ForegroundColor Cyan -Context $null

Show-Message -Message "Before clear:" -Context $null
Show-Message -Message "  Comment: [$($tag.Tag.Comment)]" -Context $null
Show-Message -Message "  Description: [$($tag.Tag.Description)]" -Context $null

# Clear both fields
$tag.Tag.Comment = $null
$tag.Tag.Description = $null
Show-Message -Message "`nSet Comment and Description to null" -Context $null

Show-Message -Message "`nAfter setting to null (before save):" -Context $null
Show-Message -Message "  Comment: [$($tag.Tag.Comment)]" -Context $null
Show-Message -Message "  Description: [$($tag.Tag.Description)]" -Context $null
# Check Vorbis fields
if ($tag -is [TagLib.Flac.File]) {
    $xiph = $tag.GetTag([TagLib.TagTypes]::Xiph, $false)
    if ($xiph) {
        $commentFields = $xiph.GetField("COMMENT")
        $descFields = $xiph.GetField("DESCRIPTION")
        Show-Message -Message "  Vorbis COMMENT fields: $($commentFields.Count)" -Context $null
        Show-Message -Message "  Vorbis DESCRIPTION fields: $($descFields.Count)" -Context $null
    }
}

# Don't actually save, just dispose
$tag.Dispose()

Show-Message -Message "`n✓ Diagnostic complete (file not modified)" -ForegroundColor Green -Context $null


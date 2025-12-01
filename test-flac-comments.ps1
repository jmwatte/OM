# Test: Diagnose FLAC comment/description fields
# Check if file has multiple comment fields

$ErrorActionPreference = 'Stop'

$testFile = "C:\Users\jmw\Documents\PowerShell\Modules\OM\testfiles\Ozawa, Boston Symphony Orchestra\1990 - Mahler Symphony no. 9\01 -  Symphony No. 9 in D Major - 1. Andante comodo.flac"

if (-not (Test-Path $testFile)) {
    Write-Host "Test file not found: $testFile" -ForegroundColor Red
    exit 1
}

Write-Host "`n=== FLAC Comment Field Diagnostics ===" -ForegroundColor Cyan
Write-Host "File: $(Split-Path -Leaf $testFile)" -ForegroundColor Gray

# Load with TagLib
$tag = [TagLib.File]::Create($testFile)

Write-Host "`n--- TagLib Standard Properties ---" -ForegroundColor Yellow
Write-Host "Comment: [$($tag.Tag.Comment)]"
Write-Host "Description: [$($tag.Tag.Description)]"

# Access the underlying Vorbis comment block directly
if ($tag -is [TagLib.Flac.File]) {
    Write-Host "`n--- FLAC Vorbis Comment Block ---" -ForegroundColor Yellow
    
    # Get all tags from the Vorbis comment
    $xiph = $tag.GetTag([TagLib.TagTypes]::Xiph, $false)
    if ($xiph) {
        Write-Host "Xiph/Vorbis tag found" -ForegroundColor Green
        
        # Check for COMMENT field (Vorbis standard)
        $commentFields = $xiph.GetField("COMMENT")
        if ($commentFields -and $commentFields.Count -gt 0) {
            Write-Host "`nCOMMENT fields ($($commentFields.Count)):" -ForegroundColor Cyan
            for ($i = 0; $i -lt $commentFields.Count; $i++) {
                Write-Host "  [$i]: $($commentFields[$i])"
            }
        } else {
            Write-Host "No COMMENT fields found" -ForegroundColor Gray
        }
        
        # Check for DESCRIPTION field (alternative field name)
        $descFields = $xiph.GetField("DESCRIPTION")
        if ($descFields -and $descFields.Count -gt 0) {
            Write-Host "`nDESCRIPTION fields ($($descFields.Count)):" -ForegroundColor Cyan
            for ($i = 0; $i -lt $descFields.Count; $i++) {
                Write-Host "  [$i]: $($descFields[$i])"
            }
        } else {
            Write-Host "No DESCRIPTION fields found" -ForegroundColor Gray
        }
        
        # List ALL vorbis comment fields
        Write-Host "`n--- All Vorbis Comment Fields ---" -ForegroundColor Yellow
        $allFields = $xiph.FieldNames
        foreach ($fieldName in $allFields) {
            $values = $xiph.GetField($fieldName)
            if ($values.Count -eq 1) {
                Write-Host "$fieldName = $($values[0])"
            } else {
                Write-Host "$fieldName = [" -NoNewline
                Write-Host ($values -join ", ") -NoNewline
                Write-Host "]"
            }
        }
    } else {
        Write-Host "No Xiph/Vorbis comment block found" -ForegroundColor Red
    }
}

# Now test clearing the comment
Write-Host "`n`n=== Test: Clear Comment Field ===" -ForegroundColor Cyan

Write-Host "Before clear:"
Write-Host "  Comment: [$($tag.Tag.Comment)]"
Write-Host "  Description: [$($tag.Tag.Description)]"

# Clear both fields
$tag.Tag.Comment = $null
$tag.Tag.Description = $null
Write-Host "`nSet Comment and Description to null"

Write-Host "`nAfter setting to null (before save):"
Write-Host "  Comment: [$($tag.Tag.Comment)]"
Write-Host "  Description: [$($tag.Tag.Description)]"

# Check Vorbis fields
if ($tag -is [TagLib.Flac.File]) {
    $xiph = $tag.GetTag([TagLib.TagTypes]::Xiph, $false)
    if ($xiph) {
        $commentFields = $xiph.GetField("COMMENT")
        $descFields = $xiph.GetField("DESCRIPTION")
        Write-Host "  Vorbis COMMENT fields: $($commentFields.Count)"
        Write-Host "  Vorbis DESCRIPTION fields: $($descFields.Count)"
    }
}

# Don't actually save, just dispose
$tag.Dispose()

Write-Host "`n✓ Diagnostic complete (file not modified)" -ForegroundColor Green

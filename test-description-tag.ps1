# Test script to examine DESCRIPTION tag in FLAC files
Import-Module c:\Users\jmw\Documents\PowerShell\Modules\OM\OM.psd1 -Force

$testFile = Get-ChildItem "C:\Users\jmw\Documents\PowerShell\Modules\OM\testfiles\goldberg variations" -Filter *.flac | Select-Object -First 1

Write-Host "Testing file: $($testFile.Name)" -ForegroundColor Cyan
Write-Host ""

$file = [TagLib.File]::Create($testFile.FullName)

Write-Host "Standard TagLib properties:" -ForegroundColor Yellow
Write-Host "  Comment: '$($file.Tag.Comment)'"
Write-Host "  Description: '$($file.Tag.Description)'"
Write-Host ""

Write-Host "Xiph/Vorbis comments (FLAC uses these):" -ForegroundColor Yellow
$xiph = $file.GetTag([TagLib.TagTypes]::Xiph)

if ($xiph) {
    Write-Host "  COMMENT: '$($xiph.GetFirstField("COMMENT"))'"
    Write-Host "  DESCRIPTION: '$($xiph.GetFirstField("DESCRIPTION"))'"
    
    Write-Host ""
    Write-Host "All Xiph fields:" -ForegroundColor Yellow
    foreach ($field in $xiph.GetEnumerator()) {
        Write-Host "  $($field.Key): $($field.Value -join '; ')"
    }
} else {
    Write-Host "  No Xiph tag found"
}

$file.Dispose()

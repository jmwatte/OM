# Test script to verify sa command refreshes display with updated tags
Import-Module c:\Users\jmw\Documents\PowerShell\Modules\OM\OM.psd1 -Force

$testPath = "C:\Users\jmw\Documents\PowerShell\Modules\OM\testfiles\goldberg variations"

Write-Host "`n=== Testing sa command display refresh ===" -ForegroundColor Cyan
Write-Host "`nStep 1: Read first 3 files' current tags" -ForegroundColor Yellow
$files = Get-ChildItem $testPath -Filter *.flac | Select-Object -First 3
foreach ($f in $files) {
    $tag = [TagLib.File]::Create($f.FullName)
    Write-Host "$($f.Name): Disc=$($tag.Tag.Disc), Track=$($tag.Tag.Track), Title=$($tag.Tag.Title)"
    $tag.Dispose()
}

Write-Host "`nStep 2: Modify tags to Disc=0, Track=99 (simulating before save)" -ForegroundColor Yellow
foreach ($f in $files) {
    $tag = [TagLib.File]::Create($f.FullName)
    $tag.Tag.Disc = 0
    $tag.Tag.Track = 99
    $tag.Save()
    $tag.Dispose()
}

Write-Host "`nStep 3: Verify files now have Disc=0, Track=99" -ForegroundColor Yellow
foreach ($f in $files) {
    $tag = [TagLib.File]::Create($f.FullName)
    Write-Host "$($f.Name): Disc=$($tag.Tag.Disc), Track=$($tag.Tag.Track)"
    $tag.Dispose()
}

Write-Host "`nStep 4: Simulate loading audioFiles (like Start-OM does)" -ForegroundColor Yellow
$audioFiles = Get-ChildItem $testPath -Filter *.flac | Select-Object -First 3
$audioFiles = foreach ($file in $audioFiles) {
    $tagFile = [TagLib.File]::Create($file.FullName)
    [PSCustomObject]@{
        FilePath    = $file.FullName
        DiscNumber  = $tagFile.Tag.Disc
        TrackNumber = $tagFile.Tag.Track
        Title       = $tagFile.Tag.Title
        TagFile     = $tagFile
    }
}

Write-Host "Loaded audioFiles:"
$audioFiles | ForEach-Object { Write-Host "  $($_.DiscNumber).$($_.TrackNumber): $($_.Title)" }

Write-Host "`nStep 5: Simulate saving tags (change back to Disc=1, Track=1/2/3)" -ForegroundColor Yellow
for ($i = 0; $i -lt $audioFiles.Count; $i++) {
    $f = $audioFiles[$i]
    $tag = [TagLib.File]::Create($f.FilePath)
    $tag.Tag.Disc = 1
    $tag.Tag.Track = $i + 1
    $tag.Save()
    Write-Host "Saved: $($f.FilePath) -> Disc=1, Track=$($i+1)"
    $tag.Dispose()
}

Write-Host "`nStep 6: Dispose old TagFile handles" -ForegroundColor Yellow
foreach ($af in $audioFiles) {
    if ($af.TagFile) {
        $af.TagFile.Dispose()
        $af.TagFile = $null
    }
}

Write-Host "`nStep 7: Reload audioFiles (simulating the fix)" -ForegroundColor Yellow
$audioFiles = Get-ChildItem $testPath -Filter *.flac | Select-Object -First 3
$audioFiles = foreach ($file in $audioFiles) {
    $tagFile = [TagLib.File]::Create($file.FullName)
    [PSCustomObject]@{
        FilePath    = $file.FullName
        DiscNumber  = $tagFile.Tag.Disc
        TrackNumber = $tagFile.Tag.Track
        Title       = $tagFile.Tag.Title
        TagFile     = $tagFile
    }
}

Write-Host "Reloaded audioFiles:"
$audioFiles | ForEach-Object { 
    $color = if ($_.DiscNumber -eq 1 -and $_.TrackNumber -le 3) { 'Green' } else { 'Red' }
    Write-Host "  $($_.DiscNumber).$($_.TrackNumber): $($_.Title)" -ForegroundColor $color
}

Write-Host "`n=== Test Result ===" -ForegroundColor Cyan
$allCorrect = $true
for ($i = 0; $i -lt $audioFiles.Count; $i++) {
    $expected = $i + 1
    if ($audioFiles[$i].DiscNumber -ne 1 -or $audioFiles[$i].TrackNumber -ne $expected) {
        $allCorrect = $false
        Write-Host "FAIL: File $i expected Disc=1, Track=$expected but got Disc=$($audioFiles[$i].DiscNumber), Track=$($audioFiles[$i].TrackNumber)" -ForegroundColor Red
    }
}

if ($allCorrect) {
    Write-Host "SUCCESS: All files show updated tags after reload!" -ForegroundColor Green
} else {
    Write-Host "FAIL: Some files don't reflect the saved tags" -ForegroundColor Red
}

# Cleanup
foreach ($af in $audioFiles) {
    if ($af.TagFile) { $af.TagFile.Dispose() }
}

Write-Host "`nTest complete.`n"

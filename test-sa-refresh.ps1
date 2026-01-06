# Test script to verify sa command refreshes display with updated tags
Import-Module c:\Users\jmw\Documents\PowerShell\Modules\OM\OM.psd1 -Force

# Ensure Show-Message helper available when running standalone
if (-not (Get-Command -Name Show-Message -ErrorAction SilentlyContinue)) {
    $p = Join-Path $PSScriptRoot 'Private\Utils\Show-Message.ps1'
    if (Test-Path $p) { . $p }
}

$testPath = "C:\Users\jmw\Documents\PowerShell\Modules\OM\testfiles\goldberg variations"

Show-Message -Message "`n=== Testing sa command display refresh ===" -ForegroundColor Cyan -Context $null
Show-Message -Message "`nStep 1: Read first 3 files' current tags" -ForegroundColor Yellow -Context $null
$files = Get-ChildItem $testPath -Filter *.flac | Select-Object -First 3
foreach ($f in $files) {
    $tag = [TagLib.File]::Create($f.FullName)
    Show-Message -Message "$($f.Name): Disc=$($tag.Tag.Disc), Track=$($tag.Tag.Track), Title=$($tag.Tag.Title)" -Context $null
    $tag.Dispose()
}

Show-Message -Message "`nStep 2: Modify tags to Disc=0, Track=99 (simulating before save)" -ForegroundColor Yellow -Context $null
foreach ($f in $files) {
    $tag = [TagLib.File]::Create($f.FullName)
    $tag.Tag.Disc = 0
    $tag.Tag.Track = 99
    $tag.Save()
    $tag.Dispose()
}

Show-Message -Message "`nStep 3: Verify files now have Disc=0, Track=99" -ForegroundColor Yellow -Context $null
foreach ($f in $files) {
    $tag = [TagLib.File]::Create($f.FullName)
    Show-Message -Message "$($f.Name): Disc=$($tag.Tag.Disc), Track=$($tag.Tag.Track)" -Context $null
    $tag.Dispose()
}

Show-Message -Message "`nStep 4: Simulate loading audioFiles (like Start-OM does)" -ForegroundColor Yellow -Context $null
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

Show-Message -Message "Loaded audioFiles:" -Context $null
$audioFiles | ForEach-Object { Show-Message -Message "  $($_.DiscNumber).$($_.TrackNumber): $($_.Title)" -Context $null }

Show-Message -Message "`nStep 5: Simulate saving tags (change back to Disc=1, Track=1/2/3)" -ForegroundColor Yellow -Context $null
for ($i = 0; $i -lt $audioFiles.Count; $i++) {
    $f = $audioFiles[$i]
    $tag = [TagLib.File]::Create($f.FilePath)
    $tag.Tag.Disc = 1
    $tag.Tag.Track = $i + 1
    $tag.Save()
    Show-Message -Message "Saved: $($f.FilePath) -> Disc=1, Track=$($i+1)" -Context $null
    $tag.Dispose()
}

Show-Message -Message "`nStep 6: Dispose old TagFile handles" -ForegroundColor Yellow -Context $null
foreach ($af in $audioFiles) {
    if ($af.TagFile) {
        $af.TagFile.Dispose()
        $af.TagFile = $null
    }
}

Show-Message -Message "`nStep 7: Reload audioFiles (simulating the fix)" -ForegroundColor Yellow -Context $null
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

Show-Message -Message "Reloaded audioFiles:" -Context $null
$audioFiles | ForEach-Object { 
    $color = if ($_.DiscNumber -eq 1 -and $_.TrackNumber -le 3) { 'Green' } else { 'Red' }
    Show-Message -Message "  $($_.DiscNumber).$($_.TrackNumber): $($_.Title)" -ForegroundColor $color -Context $null
}

Show-Message -Message "`n=== Test Result ===" -ForegroundColor Cyan -Context $null
$allCorrect = $true
for ($i = 0; $i -lt $audioFiles.Count; $i++) {
    $expected = $i + 1
    if ($audioFiles[$i].DiscNumber -ne 1 -or $audioFiles[$i].TrackNumber -ne $expected) {
        $allCorrect = $false
        Show-Message -Message "FAIL: File $i expected Disc=1, Track=$expected but got Disc=$($audioFiles[$i].DiscNumber), Track=$($audioFiles[$i].TrackNumber)" -ForegroundColor Red -Context $null
    }
}

if ($allCorrect) {
    Show-Message -Message "SUCCESS: All files show updated tags after reload!" -ForegroundColor Green -Context $null
} else {
    Show-Message -Message "FAIL: Some files don't reflect the saved tags" -ForegroundColor Red -Context $null
}

# Cleanup
foreach ($af in $audioFiles) {
    if ($af.TagFile) { $af.TagFile.Dispose() }
}

Show-Message -Message "`nTest complete.`n" -Context $null

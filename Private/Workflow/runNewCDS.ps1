
$f= dir "C:\Users\jmw\Downloads\newmusic\*.zip"
$HD="H:"
$fresh ="$HD\__Fresh"
$checked ="$HD\__checkedAudio"
$to="$HD\music"
#$AddGenre="Music For Sonic Installations In The Cavern Of Your Skull"

$f | % {
    $p = $_.BaseName -split " - ", 2
    $artist = $p[1].Trim()   # swap [0]/[1] for qqdl naming

    # Extract into artist folder only — the zip's own root folder becomes the album folder
    $dest = "$fresh\$artist"
    New-Item -Path $dest -ItemType Directory -Force | Out-Null
    & "C:\Program Files\7-Zip\7z.exe" x $_.FullName -o"$dest" -y

    Repair-AudioFileExtensions -Path $dest -Recurse
    #got $dest -Details | sot -ParseFilename "{AlbumArtists} - {Album} - {disc}-{track} {title}" -PassThru
    got $dest -Details | sot -ParseFilename "{Track} - {AlbumArtists} - {title}" -PassThru
    if ($AddGenre){ got $dest -Details | SOT -Transform { $_.Genres = @($_.Genres) + $AddGenre } -PassThru }
}
$zips = $f.Count

$dirs = Get-ChildItem -Path $fresh -Directory | Select-Object -ExpandProperty FullName
foreach ($dir in $dirs) {
    Write-Host "`n`n=== Processing: $dir ===" -ForegroundColor Cyan
    Start-OM -Path $dir -Provider Qobuz -GenreMode Merge -Auto -AutoWait -AutoFallback -AutoSaveCover -TargetFolder $checked
    if (-not $?) { Write-Host "Failed on $dir" -ForegroundColor Red }
}

got $checked -Details | Format-Genres -PassThru | sot

$dirs = gci -Directory $checked
$dirs | Where-Object { $_.GetFileSystemInfos().Count -eq 0 } | Remove-Item -Recurse
$dirs = gci -Directory $checked
$inChecked = (gci -Directory $checked -Recurse).Count
$dirs | % { gci $_ -Directory | % { Add-OMDiscNumbers -ForceDiscs -ForceTracks $_ } }
$dirs | % { gci $_ -Directory | % { Move-OMTags $_.FullName $to -PassThru } }

$dirs | Where-Object { $_.GetFileSystemInfos().Count -eq 0 } | Remove-Item -Recurse
Write-Host "$zips zips / $inChecked in Checked"

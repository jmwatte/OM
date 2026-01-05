. 'Private\Utils\Invoke-StageB-HandleSelection.ps1'
function Get-OMConfig { [PSCustomObject]@{ CoverArt = @{ FolderImageSize = 300; TagImageSize = 200 } } }
function Save-CoverArt { param($CoverUrl,$AlbumPath,$Action,$MaxSize,$WhatIf) Write-Host "CALL_SAVE $CoverUrl"; return [PSCustomObject]@{ Success = $true } }
$albums = @([PSCustomObject]@{ name='A'; cover_url='http://a' }, [PSCustomObject]@{ name='B'; cover_url='http://b' })
$r = Invoke-StageB-HandleSelection -Action 'SaveToFolder' -RangeText '1..2' -AlbumCandidates $albums -AlbumPath 'C:\tmp' -UseWhatIf:$true
$r | Format-List

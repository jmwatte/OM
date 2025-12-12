<#
.SYNOPSIS
    Helper script to find and download cover art for folders missing artwork.

.DESCRIPTION
    Searches recursively for folders containing audio files but no artwork,
    then uses Save-OMCoverArt to download cover art from the specified provider.

.PARAMETER RootPath
    Root path to search for folders (e.g., "D:\")

.PARAMETER Provider
    Provider to fetch artwork from (Spotify, Qobuz, Discogs, MusicBrainz)

.PARAMETER WhatIf
    Preview which folders would be processed without actually downloading

.EXAMPLE
    .\Find-FoldersWithoutArtwork.ps1 -RootPath "D:\" -Provider Qobuz

.EXAMPLE
    .\Find-FoldersWithoutArtwork.ps1 -RootPath "D:\Music" -WhatIf
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [string]$RootPath,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet('Spotify', 'Qobuz', 'Discogs', 'MusicBrainz')]
    [string]$Provider = 'Qobuz'
)

Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  Finding folders without artwork..." -ForegroundColor Yellow
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

# Find folders with audio files but no artwork
$foldersToProcess = Get-ChildItem -Path $RootPath -Recurse -Directory -ErrorAction SilentlyContinue | 
    Where-Object { 
        $files = Get-ChildItem $_.FullName -File -ErrorAction SilentlyContinue
        
        # Has audio files
        $hasAudio = $files | Where-Object { $_.Extension -match '\.(mp3|flac|wav|m4a|aac|ogg)$' }
        
        # No artwork files
        $hasArtwork = $files | Where-Object { $_.Extension -match '\.(jpg|jpeg|png|gif|bmp)$' }
        
        $hasAudio -and -not $hasArtwork
    } | 
    Select-Object -ExpandProperty FullName

if (-not $foldersToProcess -or $foldersToProcess.Count -eq 0) {
    Write-Host "`n✓ No folders without artwork found!" -ForegroundColor Green
    return
}

Write-Host "`nFound $($foldersToProcess.Count) folder(s) without artwork:" -ForegroundColor Yellow
$foldersToProcess | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }

if ($WhatIfPreference) {
    Write-Host "`nWhatIf: Would process $($foldersToProcess.Count) folders" -ForegroundColor Cyan
    return
}

Write-Host "`nStarting artwork download..." -ForegroundColor Cyan
Write-Host "Provider: $Provider" -ForegroundColor Gray
Write-Host ""

# Process each folder
$processed = 0
$successful = 0
$failed = 0

foreach ($folder in $foldersToProcess) {
    $processed++
    Write-Host "[$processed/$($foldersToProcess.Count)] " -NoNewline -ForegroundColor Gray
    
    try {
        Save-OMCoverArt -Path $folder -Provider $Provider -ErrorAction Stop
        $successful++
    }
    catch {
        Write-Warning "Failed: $folder - $_"
        $failed++
    }
}

Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  Summary:" -ForegroundColor Yellow
Write-Host "    Processed:  $processed" -ForegroundColor Gray
Write-Host "    Successful: $successful" -ForegroundColor Green
Write-Host "    Failed:     $failed" -ForegroundColor $(if ($failed -gt 0) { 'Red' } else { 'Gray' })
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

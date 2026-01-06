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
    [string]$Provider = 'Qobuz',
    [Parameter(Mandatory = $false)][object]$Context
)

# Ensure Show-Message helper available when dot-sourced
if (-not (Get-Command -Name Show-Message -ErrorAction SilentlyContinue)) {
    $candidates = @()
    if ($PSScriptRoot) { $candidates += Join-Path $PSScriptRoot '..\Private\Utils\Show-Message.ps1' }
    if ($MyInvocation.MyCommand.Path) { $candidates += Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\Private\Utils\Show-Message.ps1' }
    $candidates += Join-Path (Get-Location) 'Private\Utils\Show-Message.ps1'
    foreach ($path in $candidates) { if (Test-Path $path) { . $path; break } }
}

Show-Message -Message "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan -Context $Context
Show-Message -Message "  Finding folders without artwork..." -ForegroundColor Yellow -Context $Context
Show-Message -Message "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan -Context $Context

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
    Show-Message -Message "`n✓ No folders without artwork found!" -ForegroundColor Green -Context $Context
    return
}

Show-Message -Message "`nFound $($foldersToProcess.Count) folder(s) without artwork:" -ForegroundColor Yellow -Context $Context
$foldersToProcess | ForEach-Object { Show-Message -Message "  $_" -ForegroundColor Gray -Context $Context }

if ($WhatIfPreference) {
    Show-Message -Message "`nWhatIf: Would process $($foldersToProcess.Count) folders" -ForegroundColor Cyan -Context $Context
    return
}

Show-Message -Message "`nStarting artwork download..." -ForegroundColor Cyan -Context $Context
Show-Message -Message "Provider: $Provider" -ForegroundColor Gray -Context $Context
Show-Message -Message "" -Context $Context

# Process each folder
$processed = 0
$successful = 0
$failed = 0

foreach ($folder in $foldersToProcess) {
    $processed++
    Show-Message -Message "[$processed/$($foldersToProcess.Count)] " -NoNewline -ForegroundColor Gray -Context $Context
    
    try {
        Save-OMCoverArt -Path $folder -Provider $Provider -ErrorAction Stop
        $successful++
    }
    catch {
        Write-Warning "Failed: $folder - $_"
        $failed++
    }
}

Show-Message -Message "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan -Context $Context
Show-Message -Message "  Summary:" -ForegroundColor Yellow -Context $Context
Show-Message -Message "    Processed:  $processed" -ForegroundColor Gray -Context $Context
Show-Message -Message "    Successful: $successful" -ForegroundColor Green -Context $Context
Show-Message -Message "    Failed:     $failed" -ForegroundColor $(if ($failed -gt 0) { 'Red' } else { 'Gray' }) -Context $Context
Show-Message -Message "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan -Context $Context


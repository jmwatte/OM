function Show-OMHeader {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Provider,
        [Parameter(Mandatory=$true)]
        [string]$Artist,
        [Parameter(Mandatory=$true)]
        [string]$AlbumName,
        [int]$TrackCount = 0,
        [string]$QobuzUrlLocale = $null, # Added as parameter
        [object]$ScriptAlbum = $null     # Added as parameter
    )
    Write-Host ""
    Write-Host "🎵 ═══════════════════════════════════════════════════════════" -ForegroundColor DarkCyan
    Write-Host "🔍 Provider: " -NoNewline -ForegroundColor Magenta
    
    # Add locale for Qobuz provider (use cached value from parent scope)
    if ($Provider -eq 'Qobuz' -and $QobuzUrlLocale) {
        Write-Host "$Provider ($QobuzUrlLocale)" -ForegroundColor Cyan
    } else {
        Write-Host $Provider -ForegroundColor Cyan
    }
    
    Write-Host "👤 Original Artist: " -NoNewline -ForegroundColor Yellow
    Write-Host $Artist -ForegroundColor White
    Write-Host "💿 Original Album: " -NoNewline -ForegroundColor Green
    
    # Try to extract year from folder name (e.g., "2011 - Bach Cello Suites")
    $folderYear = ""
    if ($ScriptAlbum -and $ScriptAlbum.Name) {
        if ($ScriptAlbum.Name -match '^(\d{4})\s*-\s*') {
            $folderYear = "$($matches[1]) - "
        }
    }
    
    Write-Host "$folderYear$AlbumName" -NoNewline -ForegroundColor White
    if ($TrackCount -gt 0) {
        Write-Host " ($TrackCount tracks)" -ForegroundColor White
    }
    else {
        Write-Host ""  # Ensure newline
    }
    
    # Display original path (folder only)
    if ($ScriptAlbum -and $ScriptAlbum.FullName) {
        Write-Host "📁 Original Path: " -NoNewline -ForegroundColor Cyan
        Write-Host $ScriptAlbum.FullName -ForegroundColor White
    }
    
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor DarkCyan
    Write-Host ""
}


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
        [object]$ScriptAlbum = $null,    # Added as parameter
        [object]$Context = $null         # Optional context for Show-Message
    )

    # Ensure Show-Message helper available when dot-sourced in tests
    if (-not (Get-Command -Name Show-Message -ErrorAction SilentlyContinue)) {
        $candidates = @()
        if ($PSScriptRoot) { $candidates += Join-Path $PSScriptRoot 'Show-Message.ps1' }
        if ($MyInvocation.MyCommand.Path) { $candidates += Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'Show-Message.ps1' }
        $candidates += Join-Path (Get-Location) 'Private\Utils\Show-Message.ps1'
        foreach ($p in $candidates) { if (Test-Path $p) { . $p; break } }
    }

    # Avoid printing an entirely empty header (occurs in some flows) — treat as no-op
    if ([string]::IsNullOrWhiteSpace($Provider) -and [string]::IsNullOrWhiteSpace($Artist) -and [string]::IsNullOrWhiteSpace($AlbumName)) {
        Write-Verbose "Show-OMHeader: empty Provider/Artist/AlbumName — skipping"
        return
    }

    # Use Show-Message everywhere so output is consistent and testable (honors Context.DisplayWriter)
    Show-Message -Message "" -Context $Context
    Show-Message -Message "🎵 ═══════════════════════════════════════════════════════════" -ForegroundColor DarkCyan -Context $Context
    Show-Message -Message "🔍 Provider: " -ForegroundColor Magenta -NoNewline -Context $Context

    # Add locale for Qobuz provider (use provided value)
    if ($Provider -eq 'Qobuz' -and $QobuzUrlLocale) {
        Show-Message -Message "$Provider ($QobuzUrlLocale)" -ForegroundColor Cyan -Context $Context
    } else {
        Show-Message -Message $Provider -ForegroundColor Cyan -Context $Context
    }

    Show-Message -Message "👤 Original Artist: " -ForegroundColor Yellow -NoNewline -Context $Context
    Show-Message -Message $Artist -ForegroundColor White -Context $Context
    Show-Message -Message "💿 Original Album: " -ForegroundColor Green -NoNewline -Context $Context

    # Try to extract year from folder name (e.g., "2011 - Bach Cello Suites")
    $folderYear = ""
    if ($ScriptAlbum -and $ScriptAlbum.Name) {
        if ($ScriptAlbum.Name -match '^(\d{4})\s*-\s*') {
            $folderYear = "$($matches[1]) - "
        }
    }

    Show-Message -Message "$folderYear$AlbumName" -ForegroundColor White -NoNewline -Context $Context
    if ($TrackCount -gt 0) {
        Show-Message -Message " ($TrackCount tracks)" -ForegroundColor White -Context $Context
    }
    else {
        Show-Message -Message "" -Context $Context  # Ensure newline
    }

    # Display original path (folder only)
    if ($ScriptAlbum -and $ScriptAlbum.FullName) {
        Show-Message -Message "📁 Original Path: " -NoNewline -ForegroundColor Cyan -Context $Context
        Show-Message -Message $ScriptAlbum.FullName -ForegroundColor White -Context $Context
    }

    Show-Message -Message "═══════════════════════════════════════════════════════════" -ForegroundColor DarkCyan -Context $Context
    Show-Message -Message "" -Context $Context
}


<#
Debug helper for Search-QAlbum
Runs a quick search for Paul Weller - Heavy Soul and prints results
#>

#Set-Location -Path $PSScriptRoot
#import module om force
# Load the search function
if (-not (Get-Command -Name Search-QAlbum -ErrorAction SilentlyContinue)) {
    . "$PSScriptRoot\Search-QAlbum.ps1"
}

# Ensure latest OM module is loaded (helpers)
#Import-Module OM -Force -ErrorAction SilentlyContinue

# Show verbose messages from the function
$VerbosePreference = 'Continue'

 # Debug: show invocation values so we can see how the VS Code debugger launches the script
 Write-Verbose ("MyInvocation.InvocationName = '{0}'" -f $MyInvocation.InvocationName)
 Write-Verbose ("MyInvocation.MyCommand.Path = '{0}'" -f $MyInvocation.MyCommand.Path)
 Write-Verbose ("PSCommandPath = '{0}'" -f $PSCommandPath)

# If running inside VS Code, set a script-line breakpoint on Test-SearchQAlbum
# so the debugger reliably stops at the start of the function and you can step in.
$inVSCode = ($Host.Name -match 'Visual Studio Code') -or ([bool]$env:VSCODE_PID)
if ($inVSCode) {
    Write-Verbose "Debugger environment detected. Installing script-line breakpoint for Test-SearchQAlbum"
    $scriptPath = $MyInvocation.MyCommand.Path
    try {
        $match = Select-String -Path $scriptPath -Pattern 'function\s+Test-SearchQAlbum' -Quiet:$false -ErrorAction SilentlyContinue | Select-Object -First 1
    } catch {
        $match = $null
    }
    if ($match) {
        $line = $match.LineNumber + 1
        if (-not (Get-PSBreakpoint | Where-Object { $_.Script -eq $scriptPath -and $_.Line -eq $line })) {
            Set-PSBreakpoint -Script $scriptPath -Line $line | Out-Null
        }
    }
    else {
        # Fallback: set a command breakpoint if we couldn't find the function signature
        if (-not (Get-PSBreakpoint | Where-Object { $_.Command -eq 'Test-SearchQAlbum' })) {
            Set-PSBreakpoint -Command 'Test-SearchQAlbum' | Out-Null
        }
    }
    Write-Verbose "Sleeping 2s to allow debugger to attach/propagate breakpoints"
    Start-Sleep -Seconds 2
}

# try {
#     $artist = 'paul weller'
#     $album = 'Heavy soul'

#     Write-Host "Searching Qobuz for '$artist' - '$album'..." -ForegroundColor Cyan
#     $results = Search-QAlbum -ArtistName $artist -AlbumName $album -Verbose

#     if (-not $results -or $results.Count -eq 0) {
#         Write-Host "No results found." -ForegroundColor Yellow
#         exit 0
#     }

#     Write-Host "`nFound $($results.Count) album(s):`n" -ForegroundColor Green
#     $results | Select-Object name, artist, release_date, track_count, genre, id, url | Format-Table -AutoSize

#     Write-Host "`nFull JSON output:`n" -ForegroundColor Cyan
#     $results | ConvertTo-Json -Depth 5
# }
# catch {
#     Write-Error "Search failed: $_"
# }
function Test-SearchQAlbum {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false, Position=0)]
        [string]$Album = "Help",

        [Parameter(Mandatory=$false, Position=1)]
        [string]$Artist = 'the beatles'
    )

    try {
        # Ensure OM helpers are loaded. Import here so we don't cause recursion when the module dot-sources this file.
        try { Import-Module OM -Force -ErrorAction SilentlyContinue } catch { Write-Verbose "Import-Module OM failed: $_" }
        Write-Host "Searching Qobuz for '$Artist' - '$Album'..." -ForegroundColor Cyan
        $results = Search-QAlbum -ArtistName $Artist -AlbumName $Album -Verbose

        if (-not $results -or $results.Count -eq 0) {
            Write-Host "No results found." -ForegroundColor Yellow
            return @()
        }

        Write-Host "`nFound $($results.Count) album(s):`n" -ForegroundColor Green
        $results | Select-Object name, artist, release_date, track_count, genre, id, url | Format-Table -AutoSize

        Write-Host "`nFull JSON output:`n" -ForegroundColor Cyan
        $results | ConvertTo-Json -Depth 5
        return $results
    }
    catch {
        Write-Error "Search failed: $_"
        return @()
    }
}

# If script executed directly, call the helper with defaults or provided args
# Use MyCommand.Path vs PSCommandPath to be robust when the script is launched
# from the debugger or when it is dot-sourced by the module during module import.
if ($MyInvocation.MyCommand.Path -eq $PSCommandPath) {
    Test-SearchQAlbum @args
}


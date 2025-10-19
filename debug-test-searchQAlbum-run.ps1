param(
    [Parameter(Position = 0)]
    [string]$Album = 'help',
    [Parameter(Position = 1)]
    [string]$Artist = 'the beatles'
)

$VerbosePreference = 'Continue'

Write-Verbose "Debug harness starting: Album=$Album Artist=$Artist"

try {
    Import-Module OM -Force -ErrorAction Stop -Verbose
}
catch {
    Write-Error "Failed to import OM module: $_"
    throw
}

Write-Verbose "Installing command breakpoints for Search-QAlbum and Test-SearchQAlbum"
try {
    Set-PSBreakpoint -Command 'Search-QAlbum' -ErrorAction SilentlyContinue | Out-Null
    Set-PSBreakpoint -Command 'Test-SearchQAlbum' -ErrorAction SilentlyContinue | Out-Null
}
catch {
    Write-Warning "Failed to create PS breakpoints: $_"
}

Write-Verbose "Breakpoints installed; sleeping briefly to allow IDE to propagate"
Start-Sleep -Seconds 1

Write-Verbose "Executing Test-SearchQAlbum"
# The module intentionally skips 'test-' scripts; load the test helper directly
. "$PSScriptRoot\Private\Providers\Qobuz\test-searchQAlbum.ps1"
Test-SearchQAlbum -Album $Album -Artist $Artist -Verbose

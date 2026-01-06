# Test automatic sort method selection

# Ensure Show-Message helper available when running standalone
if (-not (Get-Command -Name Show-Message -ErrorAction SilentlyContinue)) {
    $p = Join-Path $PSScriptRoot 'Private\Utils\Show-Message.ps1'
    if (Test-Path $p) { . $p }
}

Show-Message -Message "Testing automatic sort method selection..." -ForegroundColor Cyan -Context $null
Show-Message -Message "" -Context $null

# Setup test album path
$testPath = "C:\Users\jmw\Documents\PowerShell\Modules\OM\testfiles\The Beatles\1965 - Help!"

if (-not (Test-Path $testPath)) {
    Write-Warning "Test path not found: $testPath"
    Show-Message -Message "Looking for alternative test folders..." -Context $null
    $alternatives = Get-ChildItem "C:\Users\jmw\Documents\PowerShell\Modules\OM\testfiles" -Directory -Recurse -Depth 2 | 
                    Where-Object { (Get-ChildItem $_.FullName -File -Filter *.mp3 -ErrorAction SilentlyContinue).Count -gt 0 } |
                    Select-Object -First 5
    
    if ($alternatives) {
        Show-Message -Message "Available test folders:" -ForegroundColor Yellow -Context $null
        $alternatives | ForEach-Object { Show-Message -Message "  - $($_.FullName)" -ForegroundColor Gray -Context $null }
        $testPath = $alternatives[0].FullName
        Show-Message -Message "`nUsing: $testPath" -ForegroundColor Green -Context $null
    } else {
        Write-Error "No test folders with audio files found!"
        exit
    }
}

# Import module fresh
Remove-Module OM -ErrorAction SilentlyContinue
Import-Module C:\Users\jmw\Documents\PowerShell\Modules\OM -Force

Show-Message -Message "Test album: $testPath" -ForegroundColor Green -Context $null
Show-Message -Message "" -Context $null
Show-Message -Message "Starting OM with auto-sort selection..." -ForegroundColor Yellow -Context $null
Show-Message -Message "Watch for '🔍 Auto-selecting best sort method' messages in verbose output" -ForegroundColor Cyan -Context $null
Show-Message -Message "" -Context $null

# Run Start-OM with verbose to see auto-selection in action
Start-OM -Path $testPath -Provider Spotify -Verbose

Show-Message -Message "`nTest complete!" -ForegroundColor Green -Context $null


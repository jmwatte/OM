# Test automatic sort method selection

Write-Host "Testing automatic sort method selection..." -ForegroundColor Cyan
Write-Host ""

# Setup test album path
$testPath = "C:\Users\jmw\Documents\PowerShell\Modules\OM\testfiles\The Beatles\1965 - Help!"

if (-not (Test-Path $testPath)) {
    Write-Warning "Test path not found: $testPath"
    Write-Host "Looking for alternative test folders..."
    $alternatives = Get-ChildItem "C:\Users\jmw\Documents\PowerShell\Modules\OM\testfiles" -Directory -Recurse -Depth 2 | 
                    Where-Object { (Get-ChildItem $_.FullName -File -Filter *.mp3 -ErrorAction SilentlyContinue).Count -gt 0 } |
                    Select-Object -First 5
    
    if ($alternatives) {
        Write-Host "Available test folders:" -ForegroundColor Yellow
        $alternatives | ForEach-Object { Write-Host "  - $($_.FullName)" -ForegroundColor Gray }
        $testPath = $alternatives[0].FullName
        Write-Host "`nUsing: $testPath" -ForegroundColor Green
    } else {
        Write-Error "No test folders with audio files found!"
        exit
    }
}

# Import module fresh
Remove-Module OM -ErrorAction SilentlyContinue
Import-Module C:\Users\jmw\Documents\PowerShell\Modules\OM -Force

Write-Host "Test album: $testPath" -ForegroundColor Green
Write-Host ""
Write-Host "Starting OM with auto-sort selection..." -ForegroundColor Yellow
Write-Host "Watch for '🔍 Auto-selecting best sort method' messages in verbose output" -ForegroundColor Cyan
Write-Host ""

# Run Start-OM with verbose to see auto-selection in action
Start-OM -Path $testPath -Provider Spotify -Verbose

Write-Host "`nTest complete!" -ForegroundColor Green

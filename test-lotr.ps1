Import-Module c:\Users\resto\Documents\PowerShell\Modules\OM\OM.psd1 -Force

# Run Start-OM with automated input
$path = 'c:\Users\resto\Documents\PowerShell\Modules\OM\testdata\2005 - The Lord of the Rings_ The Fellowship of the Ring - the Complete Recordings'

Write-Host "Testing LOTR album with automated selection..." -ForegroundColor Cyan

# Use -InformationAction to suppress prompts if possible, or just run and see what happens
try {
    # This will still prompt, but we can see if it reaches the track selection stage
    Start-OM -Path $path -Verbose 2>&1 | Tee-Object -Variable output | Where-Object {
        $_ -match "rawTracks|Received|About|WARNING|Unable to index"
    }
    
    Write-Host "`nTest completed!" -ForegroundColor Green
} catch {
    Write-Host "`nError occurred: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Yellow
}

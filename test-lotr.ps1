Import-Module c:\Users\resto\Documents\PowerShell\Modules\OM\OM.psd1 -Force

# Ensure Show-Message helper available when running standalone
if (-not (Get-Command -Name Show-Message -ErrorAction SilentlyContinue)) {
    $p = Join-Path $PSScriptRoot 'Private\Utils\Show-Message.ps1'
    if (Test-Path $p) { . $p }
}

# Run Start-OM with automated input
$path = 'c:\Users\resto\Documents\PowerShell\Modules\OM\testdata\2005 - The Lord of the Rings_ The Fellowship of the Ring - the Complete Recordings'

Show-Message -Message "Testing LOTR album with automated selection..." -ForegroundColor Cyan -Context $null

# Use -InformationAction to suppress prompts if possible, or just run and see what happens
try {
    # This will still prompt, but we can see if it reaches the track selection stage
    Start-OM -Path $path -Verbose 2>&1 | Tee-Object -Variable output | Where-Object {
        $_ -match "rawTracks|Received|About|WARNING|Unable to index"
    }
    
    Show-Message -Message "`nTest completed!" -ForegroundColor Green -Context $null
} catch {
    Show-Message -Message "`nError occurred: $_" -ForegroundColor Red -Context $null
    Show-Message -Message $_.ScriptStackTrace -ForegroundColor Yellow -Context $null
}

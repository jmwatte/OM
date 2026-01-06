# Test APE file duration reading with TagLib
# Usage: test-ape-duration.ps1 <path-to-ape-file>
param(
    [Parameter(Mandatory=$false)]
    [string]$ApeFilePath
)

Import-Module "$PSScriptRoot\OM.psm1" -Force

# Ensure Show-Message helper available when running standalone
if (-not (Get-Command -Name Show-Message -ErrorAction SilentlyContinue)) {
    $p = Join-Path $PSScriptRoot 'Private\Utils\Show-Message.ps1'
    if (Test-Path $p) { . $p }
}

if ($ApeFilePath) {
    $apeFile = Get-Item $ApeFilePath
}
else {
    # Find an APE file in testfiles
    $apeFile = Get-ChildItem -Path "$PSScriptRoot\testfiles" -Filter "*.ape" -Recurse | Select-Object -First 1
}

nif (-not $apeFile) {
    Show-Message -Message "❌ No APE file specified or found" -ForegroundColor Red -Context $null
    Show-Message -Message "Usage: test-ape-duration.ps1 <path-to-ape-file>" -ForegroundColor Gray -Context $null
    exit
}

Show-Message -Message "Testing APE file: $($apeFile.Name)" -ForegroundColor Cyan -Context $null
Show-Message -Message "Path: $($apeFile.FullName)" -ForegroundColor Gray -Context $null
Show-Message -Message "" -Context $null

try {
    $tagFile = [TagLib.File]::Create($apeFile.FullName)
    
    Show-Message -Message "TagLib File Type:" -ForegroundColor Yellow -Context $null
    Show-Message -Message "  MimeType: $($tagFile.MimeType)" -Context $null
    Show-Message -Message "  Type: $($tagFile.GetType().FullName)" -Context $null
    Show-Message -Message "" -Context $null
    
    Show-Message -Message "Properties Object:" -ForegroundColor Yellow -Context $null
    Show-Message -Message "  Type: $($tagFile.Properties.GetType().FullName)" -Context $null
    Show-Message -Message "  Duration: $($tagFile.Properties.Duration)" -Context $null
    Show-Message -Message "  Duration.TotalMilliseconds: $($tagFile.Properties.Duration.TotalMilliseconds)" -Context $null
    Show-Message -Message "  Duration.TotalSeconds: $($tagFile.Properties.Duration.TotalSeconds)" -Context $null
    Show-Message -Message "" -Context $null
    
    Show-Message -Message "Audio Properties:" -ForegroundColor Yellow -Context $null
    Show-Message -Message "  AudioBitrate: $($tagFile.Properties.AudioBitrate)" -Context $null
    Show-Message -Message "  AudioSampleRate: $($tagFile.Properties.AudioSampleRate)" -Context $null
    Show-Message -Message "  AudioChannels: $($tagFile.Properties.AudioChannels)" -Context $null
    Show-Message -Message "  BitsPerSample: $($tagFile.Properties.BitsPerSample)" -Context $null
    
    # Check if APE-specific properties exist
    if ($tagFile -is [TagLib.Ape.File]) {
        Show-Message -Message "`nAPE-Specific Properties:" -ForegroundColor Yellow -Context $null
        Show-Message -Message "  File Type: APE (Monkey's Audio)" -Context $null
        
        # Try to get header information
        if ($tagFile.PSObject.Properties['Header']) {
            Show-Message -Message "  Header: $($tagFile.Header.GetType().FullName)" -Context $null
            $tagFile.Header | Get-Member -MemberType Property | ForEach-Object {
                Show-Message -Message "    $($_.Name): $($tagFile.Header.$($_.Name))" -Context $null
            }
        }
    }
    Show-Message -Message "" -Context $null
    
    Show-Message -Message "File Size Information:" -ForegroundColor Yellow -Context $null
    $fileInfo = Get-Item $apeFile.FullName
    Show-Message -Message "  File Size: $($fileInfo.Length) bytes ($([Math]::Round($fileInfo.Length / 1MB, 2)) MB)" -Context $null
    Show-Message -Message "" -Context $null    
    # Calculate expected duration from file size and bitrate
    if ($tagFile.Properties.AudioBitrate -gt 0) {
        $bitrateKbps = $tagFile.Properties.AudioBitrate
        $fileSizeBits = $fileInfo.Length * 8
        $expectedDurationSeconds = $fileSizeBits / ($bitrateKbps * 1000)
        $expectedDuration = [TimeSpan]::FromSeconds($expectedDurationSeconds)
        Show-Message -Message "Calculated Duration (from file size / bitrate):" -ForegroundColor Yellow -Context $null
        Show-Message -Message "  Expected: $($expectedDuration.ToString('mm\:ss'))" -Context $null
        Show-Message -Message "  TagLib reports: $($tagFile.Properties.Duration.ToString('mm\:ss'))" -Context $null
        Show-Message -Message "  Difference: $([Math]::Abs($expectedDurationSeconds - $tagFile.Properties.Duration.TotalSeconds)) seconds" -Context $null
    }
    Show-Message -Message "" -Context $null
    
    Show-Message -Message "All Properties Members:" -ForegroundColor Yellow -Context $null
    $tagFile.Properties | Get-Member -MemberType Property | ForEach-Object {
        Show-Message -Message "  $($_.Name): $($tagFile.Properties.$($_.Name))" -Context $null
    }
    
    $tagFile.Dispose()
}
catch {
    Show-Message -Message "❌ Error reading APE file: $($_.Exception.Message)" -ForegroundColor Red -Context $null
    Show-Message -Message $_.Exception.GetType().FullName -ForegroundColor Gray -Context $null
    Show-Message -Message $_.ScriptStackTrace -ForegroundColor Gray -Context $null
}


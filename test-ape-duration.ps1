# Test APE file duration reading with TagLib
# Usage: test-ape-duration.ps1 <path-to-ape-file>
param(
    [Parameter(Mandatory=$false)]
    [string]$ApeFilePath
)

Import-Module "$PSScriptRoot\OM.psm1" -Force

if ($ApeFilePath) {
    $apeFile = Get-Item $ApeFilePath
}
else {
    # Find an APE file in testfiles
    $apeFile = Get-ChildItem -Path "$PSScriptRoot\testfiles" -Filter "*.ape" -Recurse | Select-Object -First 1
}

if (-not $apeFile) {
    Write-Host "❌ No APE file specified or found" -ForegroundColor Red
    Write-Host "Usage: test-ape-duration.ps1 <path-to-ape-file>" -ForegroundColor Gray
    exit
}

Write-Host "Testing APE file: $($apeFile.Name)" -ForegroundColor Cyan
Write-Host "Path: $($apeFile.FullName)" -ForegroundColor Gray
Write-Host ""

try {
    $tagFile = [TagLib.File]::Create($apeFile.FullName)
    
    Write-Host "TagLib File Type:" -ForegroundColor Yellow
    Write-Host "  MimeType: $($tagFile.MimeType)"
    Write-Host "  Type: $($tagFile.GetType().FullName)"
    Write-Host ""
    
    Write-Host "Properties Object:" -ForegroundColor Yellow
    Write-Host "  Type: $($tagFile.Properties.GetType().FullName)"
    Write-Host "  Duration: $($tagFile.Properties.Duration)"
    Write-Host "  Duration.TotalMilliseconds: $($tagFile.Properties.Duration.TotalMilliseconds)"
    Write-Host "  Duration.TotalSeconds: $($tagFile.Properties.Duration.TotalSeconds)"
    Write-Host ""
    
    Write-Host "Audio Properties:" -ForegroundColor Yellow
    Write-Host "  AudioBitrate: $($tagFile.Properties.AudioBitrate)"
    Write-Host "  AudioSampleRate: $($tagFile.Properties.AudioSampleRate)"
    Write-Host "  AudioChannels: $($tagFile.Properties.AudioChannels)"
    Write-Host "  BitsPerSample: $($tagFile.Properties.BitsPerSample)"
    
    # Check if APE-specific properties exist
    if ($tagFile -is [TagLib.Ape.File]) {
        Write-Host "`nAPE-Specific Properties:" -ForegroundColor Yellow
        Write-Host "  File Type: APE (Monkey's Audio)"
        
        # Try to get header information
        if ($tagFile.PSObject.Properties['Header']) {
            Write-Host "  Header: $($tagFile.Header.GetType().FullName)"
            $tagFile.Header | Get-Member -MemberType Property | ForEach-Object {
                Write-Host "    $($_.Name): $($tagFile.Header.$($_.Name))"
            }
        }
    }
    Write-Host ""
    
    Write-Host "File Size Information:" -ForegroundColor Yellow
    $fileInfo = Get-Item $apeFile.FullName
    Write-Host "  File Size: $($fileInfo.Length) bytes ($([Math]::Round($fileInfo.Length / 1MB, 2)) MB)"
    Write-Host ""
    
    # Calculate expected duration from file size and bitrate
    if ($tagFile.Properties.AudioBitrate -gt 0) {
        $bitrateKbps = $tagFile.Properties.AudioBitrate
        $fileSizeBits = $fileInfo.Length * 8
        $expectedDurationSeconds = $fileSizeBits / ($bitrateKbps * 1000)
        $expectedDuration = [TimeSpan]::FromSeconds($expectedDurationSeconds)
        Write-Host "Calculated Duration (from file size / bitrate):" -ForegroundColor Yellow
        Write-Host "  Expected: $($expectedDuration.ToString('mm\:ss'))"
        Write-Host "  TagLib reports: $($tagFile.Properties.Duration.ToString('mm\:ss'))"
        Write-Host "  Difference: $([Math]::Abs($expectedDurationSeconds - $tagFile.Properties.Duration.TotalSeconds)) seconds"
    }
    Write-Host ""
    
    Write-Host "All Properties Members:" -ForegroundColor Yellow
    $tagFile.Properties | Get-Member -MemberType Property | ForEach-Object {
        Write-Host "  $($_.Name): $($tagFile.Properties.$($_.Name))"
    }
    
    $tagFile.Dispose()
}
catch {
    Write-Host "❌ Error reading APE file: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.Exception.GetType().FullName -ForegroundColor Gray
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
}

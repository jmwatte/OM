function Repair-AudioFileExtensions {
    <#
    .SYNOPSIS
        Detects and fixes audio files whose extension doesn't match their actual format.

    .DESCRIPTION
        Reads the magic bytes (file signature) of each audio file in a folder to determine
        the real format. If the extension doesn't match, the file is renamed.
        Common scenario: files named .flac that are actually MP4/M4A containers.

    .PARAMETER Path
        The folder path containing audio files to check.

    .PARAMETER Recurse
        Check files in subfolders too.

    .EXAMPLE
        Repair-AudioFileExtensions -Path "H:\__Fresh\Atom TM\Liedgut"
        Checks all audio files and renames any with wrong extensions.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [switch]$Recurse
    )

    $audioExtensions = @('.mp3', '.flac', '.m4a', '.wav', '.ogg', '.ape', '.aac', '.wma')

    $getParams = @{ LiteralPath = $Path; File = $true; ErrorAction = 'SilentlyContinue' }
    if ($Recurse) { $getParams['Recurse'] = $true }
    $files = Get-ChildItem @getParams | Where-Object { $audioExtensions -contains $_.Extension.ToLower() }

    if (-not $files) { return }

    $renamed = 0
    foreach ($file in $files) {
        $detected = Get-AudioFormatFromMagicBytes -FilePath $file.FullName
        if (-not $detected) { continue }

        $currentExt = $file.Extension.ToLower()
        if ($currentExt -eq $detected) { continue }

        $newName = [System.IO.Path]::ChangeExtension($file.Name, $detected)
        $newPath = Join-Path $file.DirectoryName $newName

        if (Test-Path -LiteralPath $newPath) {
            Write-Warning "Cannot rename '$($file.Name)' to '$newName': target already exists"
            continue
        }

        if ($PSCmdlet.ShouldProcess($file.Name, "Rename to '$newName' (detected format: $detected)")) {
            Rename-Item -LiteralPath $file.FullName -NewName $newName
            Write-Host "Renamed: $($file.Name) -> $newName" -ForegroundColor Yellow
            $renamed++
        }
    }

    if ($renamed -gt 0) {
        Write-Host "$renamed file(s) renamed to correct extension" -ForegroundColor Green
    }
}

function Get-AudioFormatFromMagicBytes {
    <#
    .SYNOPSIS
        Detects audio file format by reading magic bytes (file signature).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )

    try {
        $bytes = [byte[]]::new(12)
        $stream = [System.IO.File]::OpenRead($FilePath)
        try {
            $read = $stream.Read($bytes, 0, 12)
            if ($read -lt 4) { return $null }
        }
        finally {
            $stream.Dispose()
        }

        # FLAC: starts with "fLaC"
        if ($bytes[0] -eq 0x66 -and $bytes[1] -eq 0x4C -and $bytes[2] -eq 0x61 -and $bytes[3] -eq 0x43) {
            return '.flac'
        }

        # MP4/M4A: bytes 4-7 are "ftyp"
        if ($read -ge 8 -and $bytes[4] -eq 0x66 -and $bytes[5] -eq 0x74 -and $bytes[6] -eq 0x79 -and $bytes[7] -eq 0x70) {
            return '.m4a'
        }

        # MP3: starts with "ID3" (ID3v2 tag) or sync word 0xFF 0xFB/F3/F2/E0
        if ($bytes[0] -eq 0x49 -and $bytes[1] -eq 0x44 -and $bytes[2] -eq 0x33) {
            return '.mp3'
        }
        if ($bytes[0] -eq 0xFF -and ($bytes[1] -band 0xE0) -eq 0xE0) {
            return '.mp3'
        }

        # OGG: starts with "OggS"
        if ($bytes[0] -eq 0x4F -and $bytes[1] -eq 0x67 -and $bytes[2] -eq 0x67 -and $bytes[3] -eq 0x53) {
            return '.ogg'
        }

        # WAV: starts with "RIFF"
        if ($bytes[0] -eq 0x52 -and $bytes[1] -eq 0x49 -and $bytes[2] -eq 0x46 -and $bytes[3] -eq 0x46) {
            return '.wav'
        }

        # APE: starts with "MAC "
        if ($bytes[0] -eq 0x4D -and $bytes[1] -eq 0x41 -and $bytes[2] -eq 0x43 -and $bytes[3] -eq 0x20) {
            return '.ape'
        }

        return $null
    }
    catch {
        Write-Verbose "Failed to read magic bytes from '$FilePath': $_"
        return $null
    }
}

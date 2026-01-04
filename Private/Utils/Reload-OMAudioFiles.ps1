function Get-OMTagFile {
    param([string]$FilePath)
    # wrapper for TagLib file creation to allow mocking in tests
    return [TagLib.File]::Create($FilePath)
}

function Reload-OMAudioFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$AlbumPath,
        [string[]]$Extensions = @('.mp3','.flac','.wav','.m4a','.aac','.ogg','.ape'),
        [switch]$Trace
    )

    if (-not (Test-Path -LiteralPath $AlbumPath -PathType Container)) {
        throw "Album folder not found: $AlbumPath"
    }

    if ($Trace) { Write-Host "[Reload] Starting reload for: $AlbumPath" }

    $extsNormalized = @($Extensions) | ForEach-Object { $_.ToLower() }
    $files = Get-ChildItem -LiteralPath $AlbumPath -File -Recurse |
        Where-Object { $extsNormalized -contains $_.Extension.ToLower() } |
        Sort-Object { [regex]::Replace($_.Name, '(\d+)', { $args[0].Value.PadLeft(10, '0') }) }

    if ($Trace) { Write-Host "[Reload] Found files: $($files.Count)" }

    $result = @()
    foreach ($f in $files) {
        if ($Trace) { Write-Host "[Reload] Processing: $($f.FullName)" }
        try {
            $ext = $f.Extension.ToLower()
            if ($ext -eq '.ape') {
                if ($Trace) { Write-Host "[Reload] Calling Get-ApeDuration for $($f.Name)" }
                $duration = Get-ApeDuration -FilePath $f.FullName
                $tagFile = $null
                if ($Trace) { Write-Host "[Reload] Get-ApeDuration returned $duration" }
            }
            else {
                if ($Trace) { Write-Host "[Reload] Calling Get-OMTagFile for $($f.Name)" }
                $tagFile = Get-OMTagFile -FilePath $f.FullName
                if ($Trace) { Write-Host "[Reload] Get-OMTagFile returned"; $null = $tagFile }
                $duration = $tagFile.Properties.Duration.TotalMilliseconds
                if ($Trace) { Write-Host "[Reload] Duration: $duration" }
            }

            $obj = [PSCustomObject]@{
                FilePath    = $f.FullName
                DiscNumber  = if ($tagFile -and $tagFile.Tag.Disc) { $tagFile.Tag.Disc } else { 0 }
                TrackNumber = if ($tagFile -and $tagFile.Tag.Track) { $tagFile.Tag.Track } else { 0 }
                Title       = if ($tagFile -and $tagFile.Tag.Title) { $tagFile.Tag.Title } else { $f.BaseName }
                TagFile     = if ($tagFile) { $tagFile } else { $null }
                Composer    = if ($tagFile -and $tagFile.Tag.Composers) { $tagFile.Tag.Composers -join '; ' } else { 'Unknown Composer' }
                Artist      = if ($tagFile -and $tagFile.Tag.Performers) { $tagFile.Tag.Performers -join '; ' } else { 'Unknown Artist' }
                Name        = if ($tagFile -and $tagFile.Tag.Title) { $tagFile.Tag.Title } else { $f.BaseName }
                Duration    = $duration
            }
            $result += $obj
            if ($Trace) { Write-Host "[Reload] Added object for: $($f.Name)" }
        }
        catch {
            Write-Warning "Skipping corrupted or invalid audio file: $($f.FullName) - Error: $($_.Exception.Message)"
            if ($Trace) { Write-Host "[Reload] Caught error for $($f.Name): $($_.Exception.Message)" }
            continue
        }
    }

    if ($Trace) { Write-Host "[Reload] Completed reload; returning $($result.Count) items" }
    return $result
}
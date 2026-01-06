function Get-OMAudioFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        [string[]]$Extensions = @('.mp3','.flac','.wav','.m4a','.aac','.ogg','.ape'),
        [ValidateSet('byFilesystem','alphabetical')]
        [string]$SortMethod = 'byFilesystem',
        [switch]$ReturnPathsOnly,
        [switch]$Trace
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "Album folder not found: $Path"
    }

    $extsNormalized = @($Extensions) | ForEach-Object { $_.ToLower() }

    $files = Get-ChildItem -LiteralPath $Path -File -Recurse |
        Where-Object { $extsNormalized -contains $_.Extension.ToLower() }

    if ($SortMethod -eq 'alphabetical') {
        $files = $files | Sort-Object { [regex]::Replace($_.Name, '(\d+)', { $args[0].Value.PadLeft(10, '0') }) }
    }

    if ($ReturnPathsOnly) {
        return $files.FullName
    }

    $result = @()
    foreach ($f in $files) {
        try {
            $ext = $f.Extension.ToLower()
            if ($ext -eq '.ape') {
                $duration = Get-ApeDuration -FilePath $f.FullName
                $tagFile = $null
            }
            else {
                $tagFile = Get-OMTagFile -FilePath $f.FullName
                $duration = $tagFile.Properties.Duration.TotalMilliseconds
            }

            # Normalize track and disc numbers with fallbacks for textual FLAC track tags
            $trackNum = if ($tagFile -and $tagFile.Tag.Track) { $tagFile.Tag.Track } else { 0 }
            $discNum = if ($tagFile -and $tagFile.Tag.Disc) { $tagFile.Tag.Disc } else { 0 }

            if (-not $trackNum -or $trackNum -eq 0) {
                try {
                    if ($tagFile -is [TagLib.Flac.File]) {
                        $vorbisTag = $tagFile.GetTag([TagLib.TagTypes]::Xiph)
                        if ($vorbisTag) {
                            $trackText = $vorbisTag.GetFirstField("TRACKNUMBER")
                            if ($trackText -and $trackText -match '^(\d+)') {
                                $trackNum = [int]$matches[1]
                                Write-Verbose "Extracted track $trackNum from text tag '$trackText'"
                            }
                        }
                    }
                } catch {
                    Write-Verbose "Could not extract text-based track number: $_"
                }
            }

            $obj = [PSCustomObject]@{
                FilePath    = $f.FullName
                DiscNumber  = $discNum
                TrackNumber = $trackNum
                Title       = if ($tagFile -and $tagFile.Tag.Title) { $tagFile.Tag.Title } else { $f.BaseName }
                TagFile     = if ($tagFile) { $tagFile } else { $null }
                Composer    = if ($tagFile -and $tagFile.Tag.Composers) { $tagFile.Tag.Composers -join '; ' } else { 'Unknown Composer' }
                Artist      = if ($tagFile -and $tagFile.Tag.Performers) { $tagFile.Tag.Performers -join '; ' } else { 'Unknown Artist' }
                Name        = if ($tagFile -and $tagFile.Tag.Title) { $tagFile.Tag.Title } else { $f.BaseName }
                Duration    = $duration
            }
            $result += $obj
        }
        catch {
            Write-Warning "Skipping corrupted or invalid audio file: $($f.FullName) - Error: $($_.Exception.Message)"
            continue
        }
    }

    if ($Trace) {
        if (Get-Command -Name Show-Message -ErrorAction SilentlyContinue) {
            Show-Message -Message "[Get-OMAudioFile] Returning $($result.Count) files" -ForegroundColor Yellow
        }
        else {
            Write-Verbose "[Get-OMAudioFile] Returning $($result.Count) files"
        }
    }
    return $result
}
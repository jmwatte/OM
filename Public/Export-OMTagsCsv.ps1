function Export-OMTagsCsv {
    <#
    .SYNOPSIS
        Export local audio tags to a CSV file.

    .DESCRIPTION
        Reads tags from one or more files/folders using Get-OMTags and exports
        a single CSV with fixed columns suitable for spreadsheet import.

    .PARAMETER Path
        One or more file/folder paths to export tags from. Accepts pipeline input.

    .PARAMETER OutputPath
        Destination folder for the CSV file.
        If omitted, defaults to the input folder root (or parent folder for file input).

    .PARAMETER FileName
        CSV file name. Defaults to audio-tags.csv.
        If a file already exists at the target path, a timestamp suffix is added.

    .PARAMETER PassThru
        Return the final CSV path to the pipeline.

    .EXAMPLE
        Export-OMTagsCsv -Path "D:\Music\Artist\2024 - Album"

    .EXAMPLE
        "D:\Music\Artist\2024 - Album" | Export-OMTagsCsv -OutputPath "D:\Exports"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object]$Path,

        [Parameter()]
        [string]$OutputPath,

        [Parameter()]
        [string]$FileName = 'audio-tags.csv',

        [Parameter()]
        [switch]$PassThru
    )

    begin {
        $inputPaths = New-Object System.Collections.Generic.List[string]
    }

    process {
        if ($null -eq $Path) {
            return
        }

        if ($Path -is [string]) {
            if (-not [string]::IsNullOrWhiteSpace($Path)) {
                $inputPaths.Add($Path)
            }
            return
        }

        if ($Path -is [System.Collections.IEnumerable] -and -not ($Path -is [string])) {
            foreach ($p in $Path) {
                if ($null -ne $p -and -not [string]::IsNullOrWhiteSpace([string]$p)) {
                    $inputPaths.Add([string]$p)
                }
            }
            return
        }

        $inputPaths.Add([string]$Path)
    }

    end {
        if ($inputPaths.Count -eq 0) {
            Write-Warning 'No input paths provided.'
            return
        }

        $allTags = @()
        foreach ($p in $inputPaths) {
            $tags = Get-OMTags -Path $p -Details
            if ($tags) {
                $allTags += @($tags)
            }
        }

        if ($allTags.Count -eq 0) {
            Write-Warning 'No tag data found to export.'
            return
        }

        $firstInput = $inputPaths[0]
        if (-not $OutputPath) {
            if (Test-Path -LiteralPath $firstInput -PathType Container) {
                $OutputPath = $firstInput
            } elseif (Test-Path -LiteralPath $firstInput -PathType Leaf) {
                $OutputPath = Split-Path -Parent $firstInput
            } else {
                $OutputPath = (Get-Location).Path
            }
        }

        if (-not (Test-Path -LiteralPath $OutputPath)) {
            New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
        }

        if ([System.IO.Path]::GetExtension($FileName) -ne '.csv') {
            $FileName = "$FileName.csv"
        }

        $csvPath = Join-Path $OutputPath $FileName
        if (Test-Path -LiteralPath $csvPath) {
            $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
            $extension = [System.IO.Path]::GetExtension($FileName)
            $csvPath = Join-Path $OutputPath ("{0}-{1}{2}" -f $baseName, $stamp, $extension)
        }

        $rows = foreach ($tag in $allTags) {
            $artists = if ($tag.Artists -is [array]) { $tag.Artists -join '; ' } elseif ($tag.Artists) { [string]$tag.Artists } else { '' }
            $albumArtists = if ($tag.AlbumArtists -is [array]) { $tag.AlbumArtists -join '; ' } elseif ($tag.AlbumArtists) { [string]$tag.AlbumArtists } else { '' }
            $genres = if ($tag.Genres -is [array]) { $tag.Genres -join '; ' } elseif ($tag.Genres) { [string]$tag.Genres } else { '' }
            $composers = if ($tag.Composers -is [array]) { $tag.Composers -join '; ' } elseif ($tag.Composers) { [string]$tag.Composers } else { '' }

            $dateAdded = ''
            if ($tag.Path -and (Test-Path -LiteralPath $tag.Path -PathType Leaf)) {
                $dateAdded = (Get-Item -LiteralPath $tag.Path).CreationTime.ToString('yyyy-MM-ddTHH:mm:ss')
            }

            [PSCustomObject][ordered]@{
                'Full Path'    = if ($tag.Path) { [string]$tag.Path } else { '' }
                'Title'        = if ($tag.Title) { [string]$tag.Title } else { '' }
                'Artist'       = $artists
                'Album Artist' = $albumArtists
                'Album'        = if ($tag.Album) { [string]$tag.Album } else { '' }
                'Tracknumber'  = if ($null -ne $tag.Track) { [string]$tag.Track } else { '' }
                'Discnumber'   = if ($null -ne $tag.Disc) { [string]$tag.Disc } else { '' }
                'Year'         = if ($null -ne $tag.Year) { [string]$tag.Year } else { '' }
                'Genre'        = $genres
                'Composer'     = $composers
                'Date Added'   = $dateAdded
            }
        }

        $rows | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8
        Write-Host "Exported $($rows.Count) tracks to $csvPath" -ForegroundColor Green

        if ($PassThru) {
            return $csvPath
        }

        return $csvPath
    }
}
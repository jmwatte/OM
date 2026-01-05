function Get-CoverArtTempFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [array]$AlbumList,
        [Parameter(Mandatory=$false)]
        [string]$Size = 'large',
        [Parameter(Mandatory=$false)]
        [string]$Provider
    )

    $tempFiles = @()

    foreach ($album in $AlbumList) {
        $coverUrl = Get-IfExists $album 'cover_url'
        if (-not $coverUrl) { continue }

        $downloadUrl = if ($Provider) { Get-CoverArtUrl -CoverUrl $coverUrl -Provider $Provider -Size $Size } else { $coverUrl }
        try {
            $tempFile = Join-Path $env:TEMP ([guid]::NewGuid().ToString() + '.jpg')
            $response = Invoke-WebRequest -Uri $downloadUrl -Method Get -UseBasicParsing -ErrorAction Stop
            [System.IO.File]::WriteAllBytes($tempFile, $response.Content)
            $tempFiles += $tempFile
        }
        catch {
            Write-Verbose "Failed to download cover: $($_.Exception.Message)"
            continue
        }
    }

    return $tempFiles
}
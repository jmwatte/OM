function Get-ArtistNameForFolder {
    <#
    .SYNOPSIS
        Determine artist name for folder rename.
    .DESCRIPTION
        Priority: 1) ManualAlbumArtist  2) AlbumArtist from saved tags  3) ProviderAlbum.album_artist
                  4) ProviderArtist.name  5) Album name as last resort
    #>
    param(
        $AudioFiles,
        $ProviderAlbum,
        $ProviderArtist,
        [string]$AlbumNameFallback,
        [string]$ManualAlbumArtist,
        [switch]$SkipTagReading
    )

    $artistNameForFolder = $null

    # 1. ManualAlbumArtist if set (highest priority)
    if ($ManualAlbumArtist) {
        Write-Verbose "Using ManualAlbumArtist for folder name: $ManualAlbumArtist"
        $artistNameForFolder = $ManualAlbumArtist
    }
    # 2. Read AlbumArtist from first audio file's saved tags
    elseif (-not $SkipTagReading -and $AudioFiles -and $AudioFiles.Count -gt 0) {
        try {
            $firstFilePath = if ($AudioFiles[0].FilePath) { $AudioFiles[0].FilePath } else { $null }
            if ($firstFilePath) {
                if ($AudioFiles[0].TagFile) {
                    try { $AudioFiles[0].TagFile.Dispose() } catch { }
                }
                $tempTag = [TagLib.File]::Create($firstFilePath)
                try {
                    if ($tempTag.Tag.AlbumArtists -and $tempTag.Tag.AlbumArtists.Count -gt 0) {
                        $artistNameForFolder = $tempTag.Tag.AlbumArtists[0]
                        Write-Verbose "Read AlbumArtist from saved tags: $artistNameForFolder"
                    }
                    elseif ($tempTag.Tag.FirstAlbumArtist) {
                        $artistNameForFolder = $tempTag.Tag.FirstAlbumArtist
                        Write-Verbose "Read FirstAlbumArtist from saved tags: $artistNameForFolder"
                    }
                }
                finally {
                    $tempTag.Dispose()
                }
            }
        }
        catch {
            Write-Verbose "Failed to read AlbumArtist from saved tags: $($_.Exception.Message)"
        }
    }

    # 3. ProviderAlbum.album_artist (only if steps 1-2 didn't produce a result)
    if (-not $ManualAlbumArtist -and -not $artistNameForFolder) {
        $albumArtistFromMetadata = Get-IfExists $ProviderAlbum 'album_artist'
        if ($albumArtistFromMetadata) {
            $artistNameForFolder = $albumArtistFromMetadata
            Write-Verbose "Using ProviderAlbum.album_artist from track metadata: $artistNameForFolder"
        }
    }

    # 4/5. Fallback to ProviderArtist.name or album name
    if (-not $artistNameForFolder -or $artistNameForFolder -match '^[A-Z]:\\?$') {
        $providerArtistName = Get-IfExists $ProviderArtist 'name'
        if ($providerArtistName -and $providerArtistName -notmatch '^[A-Z]:\\?$') {
            $artistNameForFolder = $providerArtistName
            Write-Verbose "Using ProviderArtist.name as fallback: $artistNameForFolder"
        }
        else {
            $artistNameForFolder = $AlbumNameFallback
            Write-Verbose "No valid artist found, using album name as fallback: $artistNameForFolder"
        }
    }

    return $artistNameForFolder
}

function Get-OMArtistNameForFolder {
    <#
    .SYNOPSIS
        Determines the artist name to use for album folder naming.
    
    .DESCRIPTION
        Implements a priority-based algorithm to determine the artist name for folder renaming:
        1. ManualAlbumArtist (highest priority - explicitly set by user)
        2. AlbumArtist from audio file tags
        3. ProviderAlbum.album_artist (from provider metadata)
        4. ProviderArtist.name (if not a drive letter)
        5. Album name (last resort fallback)
    
    .PARAMETER ManualAlbumArtist
        The manually set album artist (highest priority).
    
    .PARAMETER AudioFiles
        Array of audio file objects with TagFile or FilePath properties.
    
    .PARAMETER ProviderAlbum
        The provider album object containing album_artist property.
    
    .PARAMETER ProviderArtist
        The provider artist object containing name property.
    
    .PARAMETER AlbumName
        The album name to use as fallback if no artist can be determined.
    
    .PARAMETER ReloadTags
        If specified, reloads tags from disk instead of using cached TagFile handles.
        Use when tags have just been saved.
    
    .OUTPUTS
        String - The artist name for folder naming (not yet path-sanitized).
    
    .EXAMPLE
        $artist = Get-OMArtistNameForFolder -ManualAlbumArtist 'Various Artists' -AlbumName 'Compilation'
        # Returns 'Various Artists'
    
    .EXAMPLE
        $artist = Get-OMArtistNameForFolder -AudioFiles $audioFiles -ProviderAlbum $album -ProviderArtist $artist -AlbumName 'My Album'
        # Returns artist name based on priority order
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [string]$ManualAlbumArtist,
        
        [Parameter()]
        [array]$AudioFiles,
        
        [Parameter()]
        [object]$ProviderAlbum,
        
        [Parameter()]
        [object]$ProviderArtist,
        
        [Parameter()]
        [string]$AlbumName,
        
        [Parameter()]
        [switch]$ReloadTags
    )
    
    $artistNameForFolder = $null
    
    # Priority 1: ManualAlbumArtist (highest priority)
    if ($ManualAlbumArtist) {
        Write-Verbose "Using ManualAlbumArtist for folder name: $ManualAlbumArtist"
        return $ManualAlbumArtist
    }
    
    # Priority 2: AlbumArtist from audio file tags
    if ($AudioFiles -and $AudioFiles.Count -gt 0) {
        try {
            $firstFile = $AudioFiles[0]
            $tagFile = $null
            
            if ($ReloadTags) {
                # Reload tags from disk (use when tags were just saved)
                $filePath = if ($firstFile.FilePath) { $firstFile.FilePath } else { $firstFile }
                if (Test-Path $filePath) {
                    $tagFile = [TagLib.File]::Create($filePath)
                }
            }
            elseif ($firstFile.TagFile) {
                $tagFile = $firstFile.TagFile
            }
            elseif ($firstFile.FilePath -and (Test-Path $firstFile.FilePath)) {
                $tagFile = [TagLib.File]::Create($firstFile.FilePath)
            }
            
            if ($tagFile) {
                if ($tagFile.Tag.AlbumArtists -and $tagFile.Tag.AlbumArtists.Count -gt 0) {
                    $artistNameForFolder = $tagFile.Tag.AlbumArtists[0]
                    Write-Verbose "Read AlbumArtist from tags: $artistNameForFolder"
                }
                elseif ($tagFile.Tag.FirstAlbumArtist) {
                    $artistNameForFolder = $tagFile.Tag.FirstAlbumArtist
                    Write-Verbose "Read FirstAlbumArtist from tags: $artistNameForFolder"
                }
                
                # Dispose if we created a new TagFile
                if ($ReloadTags -or (-not $firstFile.TagFile)) {
                    $tagFile.Dispose()
                }
            }
        }
        catch {
            Write-Verbose "Failed to read AlbumArtist from tags: $($_.Exception.Message)"
        }
    }
    
    # Priority 3: ProviderAlbum.album_artist (from provider metadata)
    if (-not $artistNameForFolder) {
        $albumArtistFromMetadata = Get-IfExists $ProviderAlbum 'album_artist'
        if ($albumArtistFromMetadata) {
            $artistNameForFolder = $albumArtistFromMetadata
            Write-Verbose "Using ProviderAlbum.album_artist from metadata: $artistNameForFolder"
        }
    }
    
    # Priority 4: ProviderArtist.name (if not a drive letter)
    if (-not $artistNameForFolder -or $artistNameForFolder -match '^[A-Z]:\\?$') {
        $providerArtistName = Get-IfExists $ProviderArtist 'name'
        if ($providerArtistName -and $providerArtistName -notmatch '^[A-Z]:\\?$') {
            $artistNameForFolder = $providerArtistName
            Write-Verbose "Using ProviderArtist.name as fallback: $artistNameForFolder"
        }
    }
    
    # Priority 5: Album name (last resort)
    if (-not $artistNameForFolder -or $artistNameForFolder -match '^[A-Z]:\\?$') {
        if ($AlbumName) {
            $artistNameForFolder = $AlbumName
            Write-Verbose "No valid artist found, using album name as fallback: $artistNameForFolder"
        }
        else {
            $artistNameForFolder = 'Unknown Artist'
            Write-Verbose "No artist information available, using 'Unknown Artist'"
        }
    }
    
    return $artistNameForFolder
}

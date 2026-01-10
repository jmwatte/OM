function New-OMPlaylistFromSongbook {
<#
.SYNOPSIS
    Creates an M3U playlist by matching songbook entries against your music library.

.DESCRIPTION
    Takes songs from Get-SongsByKey (harmonica songbook) and finds matching files
    in your foobar2000 library, creating a playlist you can load in your player.

.PARAMETER Key
    Musical key to filter songs (A, B, C, D, E, F, G, etc.)

.PARAMETER LibraryFile
    Path to foobar2000 export file. Default: C:\Users\jmw\Desktop\SongsFromFoobar.txt

.PARAMETER OutputFile
    Path for the output M3U playlist.

.PARAMETER Threshold
    Minimum match score (0.0-1.0). Default: 0.6

.PARAMETER Genre
    Genre tag for the playlist. Default: "Blues"

.PARAMETER AllKeys
    Process all songs regardless of key.

.EXAMPLE
    New-OMPlaylistFromSongbook -Key 'A' -OutputFile "C:\Playlists\blues-key-A.m3u8"
    
    Creates a playlist of all Key of A blues songs found in your library.

.EXAMPLE
    New-OMPlaylistFromSongbook -AllKeys -OutputFile "C:\Playlists\all-harmonica-songs.m3u8"
    
    Creates a playlist from all songs in the songbook.

.EXAMPLE
    New-OMPlaylistFromSongbook -Key 'E' -Threshold 0.8 -OutputFile "C:\Playlists\key-E-strict.m3u8"
    
    Only include high-confidence matches (80%+).
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByKey')]
        [string]$Key,
        
        [Parameter(ParameterSetName = 'AllKeys')]
        [switch]$AllKeys,
        
        [string]$LibraryFile = "C:\Users\jmw\Desktop\SongsFromFoobar.txt",
        
        [Parameter(Mandatory)]
        [string]$OutputFile,
        
        [ValidateRange(0.0, 1.0)]
        [double]$Threshold = 0.6,
        
        [string]$Genre = "Blues",
        
        [switch]$ShowNotFound
    )
    
    # Get songs from songbook
    if ($AllKeys) {
        Write-Host "Loading all songs from songbook..." -ForegroundColor Cyan
        $songs = Get-Songs
    } else {
        Write-Host "Loading songs in key '$Key' from songbook..." -ForegroundColor Cyan
        $songs = Get-SongsByKey -Key $Key
    }
    
    if (-not $songs -or $songs.Count -eq 0) {
        Write-Warning "No songs found in songbook"
        return
    }
    
    Write-Host "Found $($songs.Count) songs in songbook" -ForegroundColor Green
    
    # Create temp file with Artist - Title format
    $tempFile = [System.IO.Path]::GetTempFileName()
    try {
        $songs | ForEach-Object { "$($_.Artist) - $($_.Title)" } | Out-File $tempFile -Encoding utf8
        
        # Load library and search
        $lib = Import-OMLibraryIndex -Path $LibraryFile
        
        $result = Find-OMPlaylistTracks -InputFile $tempFile -Library $lib -OutputFormat M3U -Genre $Genre -Threshold $Threshold -OutputFile $OutputFile
        
        # Summary
        Write-Host "`n═══ Playlist Created ═══" -ForegroundColor Green
        Write-Host "Output: $OutputFile" -ForegroundColor Cyan
        
    } finally {
        Remove-Item $tempFile -ErrorAction SilentlyContinue
    }
}

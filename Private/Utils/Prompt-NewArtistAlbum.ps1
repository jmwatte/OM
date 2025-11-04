function Read-ArtistAlbum {
    <#
    .SYNOPSIS
        Read artist and album from user input (accepts defaults on Enter).

    .PARAMETER DefaultArtist
        The default artist string to show in the prompt (used when user presses Enter).

    .PARAMETER DefaultAlbum
        The default album string to show in the prompt (used when user presses Enter).

    .OUTPUTS PSCustomObject
        Returns an object with properties: Artist, Album, ChangedArtist, ChangedAlbum
    #>
    param(
        [string]$DefaultArtist = '',
        [string]$DefaultAlbum = ''
    )

    # Prompt for artist (show default in brackets)
    $promptArtist = if ($DefaultArtist) { "Artist [$DefaultArtist]: " } else { 'Artist: ' }
    $artistInput = Read-Host -Prompt $promptArtist
    if ($null -eq $artistInput -or $artistInput -eq '') {
        $artist = $DefaultArtist
        $changedArtist = $false
    }
    else {
        $artist = $artistInput.Trim()
        $changedArtist = $true
    }

    # Prompt for album (show default in brackets)
    $promptAlbum = if ($DefaultAlbum) { "Album [$DefaultAlbum]: " } else { 'Album: ' }
    $albumInput = Read-Host -Prompt $promptAlbum
    if ($null -eq $albumInput -or $albumInput -eq '') {
        $album = $DefaultAlbum
        $changedAlbum = $false
    }
    else {
        $album = $albumInput.Trim()
        $changedAlbum = $true
    }

    return [PSCustomObject]@{
        Artist = $artist
        Album = $album
        ChangedArtist = $changedArtist
        ChangedAlbum = $changedAlbum
    }
}

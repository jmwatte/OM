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

    # Prompt for artist (use centralized prompt helper)
    $artistInput = Show-OMPrompt -Prompt 'Artist' -Default $DefaultArtist -NoNewline
    if ([string]::IsNullOrEmpty($artistInput)) {
        $artist = $DefaultArtist
        $changedArtist = $false
    }
    else {
        $artist = $artistInput.Trim()
        $changedArtist = $true
    }

    # Prompt for album (use centralized prompt helper)
    $albumInput = Show-OMPrompt -Prompt 'Album' -Default $DefaultAlbum -NoNewline
    if ([string]::IsNullOrEmpty($albumInput)) {
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

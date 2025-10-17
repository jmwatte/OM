function Invoke-ProviderGetTracks {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Spotify', 'Qobuz', 'Discogs', 'MusicBrainz')]
        [string]$Provider,

        [Parameter(Mandatory)]
        [string]$AlbumId
    )

    switch ($Provider) {
        'Spotify'     { Get-AlbumTracks -Id $AlbumId }
        'Qobuz'       { Get-QAlbumTracks -Id $AlbumId }
        'Discogs'     { Get-DAlbumTracks -Id $AlbumId }
        'MusicBrainz' { Get-MBAlbumTracks -Id $AlbumId }
    }
}
function Invoke-ProviderGetAlbums {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Spotify', 'Qobuz', 'Discogs', 'MusicBrainz')]
        [string]$Provider,

        [Parameter(Mandatory)]
        [string]$ArtistId,  # For Spotify: ID; for Qobuz: full href; for Discogs: numeric ID; for MusicBrainz: MBID

        [Parameter()]
        [string]$AlbumType = 'Album',  # For Spotify compatibility

        [Parameter()]
        [switch]$MastersOnly,  # Discogs: Only master releases

        [Parameter()]
        [switch]$IncludeSingles,  # Discogs: Include singles

        [Parameter()]
        [switch]$IncludeCompilations  # Discogs: Include compilations
    )

    switch ($Provider) {
        'Spotify' { Get-SArtistAlbums -Id $ArtistId -AlbumType $AlbumType }
        'Qobuz' { Get-QArtistAlbums -Id $ArtistId }  # $ArtistId is $href
        'Discogs' { 
            $discogsParams = @{
                ArtistId            = $ArtistId
                MastersOnly         = $MastersOnly
                IncludeSingles      = $IncludeSingles
                IncludeCompilations = $IncludeCompilations
            }
            Get-DArtistAlbums @discogsParams
        }
        'MusicBrainz' { Get-MBArtistAlbums -ArtistId $ArtistId }
    }
}
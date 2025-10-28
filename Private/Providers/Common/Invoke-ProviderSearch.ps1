function Invoke-ProviderSearch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Spotify', 'Qobuz', 'Discogs', 'MusicBrainz')]
        [string]$Provider,

        [Parameter(Mandatory)]
        [string]$Query,

        [Parameter(Mandatory)]
        [ValidateSet('artist', 'album')]
        [string]$Type
    )

    switch ($Provider) {
        'Spotify'      { Search-SItem -Query $Query -Type $Type }
        'Qobuz'        { Search-QItem -Query $Query -Type $Type }
        'Discogs'      { Search-DItem -Query $Query -Type $Type }
        'MusicBrainz'  { Search-MBItem -Query $Query -Type $Type }
    }
}
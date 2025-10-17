function Invoke-ProviderSearch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Spotify', 'Qobuz', 'Discogs', 'MusicBrainz')]
        [string]$Provider,

        [Parameter(Mandatory)]
        [string]$Query,

        [Parameter(Mandatory)]
        [ValidateSet('artist')]
        [string]$Type
    )

    switch ($Provider) {
        'Spotify'      { Search-Item -Query $Query -Type $Type }
        'Qobuz'        { Search-QItem -Query $Query -Type $Type }
        'Discogs'      { Search-DItem -Query $Query -Type $Type }
        'MusicBrainz'  { 
            # MusicBrainz returns array directly, wrap it to match Spotify structure
            $artists = Search-MBArtist -Query $Query
            return [PSCustomObject]@{
                artists = [PSCustomObject]@{
                    items = $artists
                }
            }
        }
    }
}
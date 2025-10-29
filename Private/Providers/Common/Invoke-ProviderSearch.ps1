function Invoke-ProviderSearch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Spotify', 'Qobuz', 'Discogs', 'MusicBrainz')]
        [string]$Provider,

        [Parameter(Mandatory = $false)]
        [string]$Query,

        [Parameter(Mandatory = $false)]
        [string]$Album,

        [Parameter(Mandatory = $false)]
        [string]$Artist,

        [Parameter(Mandatory)]
        [ValidateSet('artist', 'album')]
        [string]$Type
    )

    switch ($Provider) {
        'Spotify' {
            $searchQuery = if ($Album -and $Artist) { "$Artist $Album" } elseif ($Query) { $Query } else { throw "Query or Album/Artist required for Spotify search" }
            Search-SItem -Query $searchQuery -Type $Type
        }
        'Qobuz' {
            $searchQuery = if ($Album -and $Artist) { "$Album $Artist" } elseif ($Query) { $Query } else { throw "Query or Album/Artist required for Qobuz search" }
            Search-QItem -Query $searchQuery -Type $Type
        }
        'Discogs' {
            $searchQuery = if ($Album -and $Artist) { "$Artist $Album" } elseif ($Query) { $Query } else { throw "Query or Album/Artist required for Discogs search" }
            Search-DItem -Query $searchQuery -Type $Type
        }
        'MusicBrainz' {
            if ($Type -eq 'artist') {
                if (-not $Query) { throw "Query required for MusicBrainz artist search" }
                Search-MBItem -Query $Query -Type $Type
            } else {
                if ($Album -and $Artist) {
                    Search-MBItem -Album $Album -Artist $Artist -Type $Type
                } elseif ($Query) {
                    Search-MBItem -Query $Query -Type $Type
                } else {
                    throw "Query or Album/Artist required for MusicBrainz album search"
                }
            }
        }
    }
}
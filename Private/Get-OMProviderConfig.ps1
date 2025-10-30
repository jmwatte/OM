function Get-OMProviderConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Spotify', 'Qobuz', 'Discogs', 'MusicBrainz')]
        [string]$Provider
    )

    $config = @{}

    switch ($Provider) {
        'Spotify' {
            $config.SearchUri = 'https://api.spotify.com/v1/search?q={query}&type={type}'
            $config.GetTracksUri = 'https://api.spotify.com/v1/albums/{albumId}/tracks'
            $config.Headers = @{ }
            $config.TransformFunction = {
                param($response)
                return $response
            }
        }
        'Qobuz' {
            $config.SearchUri = 'https://www.qobuz.com/api.json/0.2/artist/search?query={query}'
            $config.GetTracksUri = 'https://www.qobuz.com/api.json/0.2/album/get?album_id={albumId}'
            $config.Headers = @{ "X-App-Id" = (Get-OMConfig -Provider Qobuz).AppId }
            $config.TransformFunction = {
                param($response)
                $items = @()
                foreach ($track in $response.tracks.items) {
                    $items += [PSCustomObject]@{
                        name = $track.title
                        id = $track.id
                        track_number = $track.track_number
                        disc_number = $track.media_number
                        duration_ms = $track.duration * 1000
                        artists = $track.performer
                    }
                }
                return $items
            }
        }
        'Discogs' {
            $config.SearchUri = 'https://api.discogs.com/database/search?q={query}&type={type}'
            $config.GetTracksUri = 'https://api.discogs.com/releases/{albumId}'
            $config.Headers = @{ "Authorization" = "Discogs token=$((Get-OMConfig -Provider Discogs).Token)" }
            $config.TransformFunction = {
                param($response)
                $items = @()
                foreach ($track in $response.tracklist) {
                    $items += [PSCustomObject]@{
                        name = $track.title
                        id = $track.position
                        track_number = $track.position
                        disc_number = 1
                        duration_ms = 0
                        artists = $track.artists.name
                    }
                }
                return $items
            }
        }
        'MusicBrainz' {
            $config.SearchUri = 'https://musicbrainz.org/ws/2/artist/?query={query}&fmt=json'
            $config.GetTracksUri = 'https://musicbrainz.org/ws/2/release/{albumId}?inc=recordings+artist-credits&fmt=json'
            $config.Headers = @{ "User-Agent" = "OM/1.0 (https://github.com/jmwatte/OM)" }
            $config.TransformFunction = {
                param($response)
                $items = @()
                foreach ($track in $response.media.tracks) {
                    $items += [PSCustomObject]@{
                        name = $track.title
                        id = $track.id
                        track_number = $track.number
                        disc_number = $track.position
                        duration_ms = $track.length
                        artists = $track.recording.'artist-credit'.name
                    }
                }
                return $items
            }
        }
    }

    return $config
}

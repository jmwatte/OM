function Normalize-AlbumResult {
    <#
    .SYNOPSIS
        Normalize various provider album result shapes to a canonical album object.
    .PARAMETER Raw
        Raw album object as returned from a provider-specific parser.
    .OUTPUTS PSCustomObject
        Canonical album object with fields: id, url, name, artists (array of objects {name}), genres (array), cover_url, track_count, disc_count, release_date
    #>
    param(
        [Parameter(Mandatory = $true)]
        $Raw
    )

    # Helper to ensure array of simple artist objects
    $artists = @()
    # Prefer explicit helper Get-IfExists to avoid property-not-found errors
    $rawArtists = Get-IfExists -target $Raw -path 'artists'
    $rawArtist = Get-IfExists -target $Raw -path 'artist'

    if ($rawArtists) {
        if ($rawArtists -is [array]) {
            foreach ($a in $rawArtists) {
                if ($a -is [string]) { $artists += [PSCustomObject]@{ name = $a } }
                elseif ($a -is [PSCustomObject] -or $a -is [hashtable]) {
                    $n = Get-IfExists -target $a -path 'name'
                    if (-not $n) { $n = Get-IfExists -target $a -path 'artist' }
                    $artists += [PSCustomObject]@{ name = if ($n) { $n } else { $a.ToString() } }
                } else {
                    $artists += [PSCustomObject]@{ name = $a.ToString() }
                }
            }
        } else {
            # single artist string/object
            if ($rawArtists -is [string]) { $artists = @([PSCustomObject]@{ name = $rawArtists }) }
            else {
                $n = Get-IfExists -target $rawArtists -path 'name'
                if (-not $n) { $n = Get-IfExists -target $rawArtists -path 'artist' }
                $artists = @([PSCustomObject]@{ name = if ($n) { $n } else { $rawArtists.ToString() } })
            }
        }
    } elseif ($rawArtist) {
        $artists = @([PSCustomObject]@{ name = $rawArtist })
    }

    # Genres - normalize to array
    $genres = @()
    $rawGenres = Get-IfExists -target $Raw -path 'genres'
    if ($rawGenres) {
        if ($rawGenres -is [array]) { $genres = $rawGenres } else { $genres = @($rawGenres) }
    }

    # Determine id/url
    $id = Get-IfExists -target $Raw -path 'id'
    $url = Get-IfExists -target $Raw -path 'url'
    if (-not $url -and $id -and $id -match '^https?://') { $url = $id }

    # Track/disc counts
    $track_count = $null
    $rawTrackCount = Get-IfExists -target $Raw -path 'track_count'
    if ($rawTrackCount) { try { $track_count = [int]$rawTrackCount } catch { $track_count = $rawTrackCount } }
    $disc_count = $null
    $rawDiscCount = Get-IfExists -target $Raw -path 'disc_count'
    if ($rawDiscCount) { try { $disc_count = [int]$rawDiscCount } catch { $disc_count = $rawDiscCount } }

    $res = [PSCustomObject]@{
        id = $id
        url = $url
        name = (Get-IfExists -target $Raw -path 'name') -or (Get-IfExists -target $Raw -path 'title')
        artists = $artists
        genres = $genres
        cover_url = (Get-IfExists -target $Raw -path 'cover_url') -or (Get-IfExists -target $Raw -path 'cover')
        track_count = $track_count
        disc_count = $disc_count
        release_date = (Get-IfExists -target $Raw -path 'release_date') -or (Get-IfExists -target $Raw -path 'date')
    }

    return $res
}

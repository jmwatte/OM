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
    if ($null -ne $Raw.artists) {
        if ($Raw.artists -is [array]) {
            foreach ($a in $Raw.artists) {
                if ($a -is [string]) { $artists += [PSCustomObject]@{ name = $a } }
                elseif ($a -is [PSCustomObject] -or $a -is [hashtable]) { 
                    $n = if ($a.name) { $a.name } elseif ($a.artist) { $a.artist } else { '' }
                    $artists += [PSCustomObject]@{ name = $n }
                } else {
                    $artists += [PSCustomObject]@{ name = $a.ToString() }
                }
            }
        } else {
            # single artist string/object
            if ($Raw.artists -is [string]) { $artists = @([PSCustomObject]@{ name = $Raw.artists }) }
            else { $n = if ($Raw.artists.name) { $Raw.artists.name } elseif ($Raw.artists.artist) { $Raw.artists.artist } else { $Raw.artists.ToString() }; $artists = @([PSCustomObject]@{ name = $n }) }
        }
    } elseif ($null -ne $Raw.artist) {
        $artists = @([PSCustomObject]@{ name = $Raw.artist })
    }

    # Genres - normalize to array
    $genres = @()
    if ($null -ne $Raw.genres) {
        if ($Raw.genres -is [array]) { $genres = $Raw.genres } else { $genres = @($Raw.genres) }
    }

    # Determine id/url
    $id = $null
    $url = $null
    if ($Raw.id) { $id = $Raw.id }
    if ($Raw.url) { $url = $Raw.url }
    if (-not $url -and $id -and $id -match '^https?://') { $url = $id }

    # Track/disc counts
    $track_count = $null
    if ($Raw.track_count) { try { $track_count = [int]$Raw.track_count } catch { $track_count = $Raw.track_count } }
    $disc_count = $null
    if ($Raw.disc_count) { try { $disc_count = [int]$Raw.disc_count } catch { $disc_count = $Raw.disc_count } }

    $res = [PSCustomObject]@{
        id = $id
        url = $url
        name = if ($Raw.name) { $Raw.name } else { $Raw.title }
        artists = $artists
        genres = $genres
        cover_url = if ($Raw.cover_url) { $Raw.cover_url } else { $Raw.cover }
        track_count = $track_count
        disc_count = $disc_count
        release_date = if ($Raw.release_date) { $Raw.release_date } else { $Raw.date }
    }

    return $res
}

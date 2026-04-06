function ConvertFrom-ProviderUrl {
    <#
    .SYNOPSIS
    Extracts a bare provider ID from a URL or returns the input unchanged if not a URL.

    .DESCRIPTION
    Supports Spotify, Discogs, and MusicBrainz URLs. Qobuz handles full URLs natively
    so no extraction is needed.

    .PARAMETER InputId
    The raw ID string, which may be a full URL or a bare provider ID.

    .PARAMETER Provider
    The current provider name (Spotify, Discogs, MusicBrainz, Qobuz).

    .EXAMPLE
    ConvertFrom-ProviderUrl -InputId 'https://open.spotify.com/album/1oMcCp7RLhUTT7zbJqVV4A?si=abc' -Provider Spotify
    # Returns: 1oMcCp7RLhUTT7zbJqVV4A
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$InputId,

        [Parameter(Mandatory)]
        [string]$Provider
    )

    $id = $InputId.Trim()

    switch ($Provider) {
        'Spotify' {
            # https://open.spotify.com/album/1oMcCp7RLhUTT7zbJqVV4A?si=...
            # https://open.spotify.com/artist/4Z8W4fKeB5YxbusRsdQVPb
            if ($id -match 'open\.spotify\.com/(?:album|artist|track)/([A-Za-z0-9]+)') {
                $id = $matches[1]
                Write-Verbose "Extracted Spotify ID from URL: $id"
            }
        }
        'Discogs' {
            # https://www.discogs.com/release/249504-...
            # https://www.discogs.com/master/1764178-...
            if ($id -match 'discogs\.com/release/(\d+)') {
                $id = $matches[1]
                Write-Verbose "Extracted Discogs release ID from URL: $id"
            }
            elseif ($id -match 'discogs\.com/master/(\d+)') {
                $id = "m$($matches[1])"
                Write-Verbose "Extracted Discogs master ID from URL: $id"
            }
        }
        'MusicBrainz' {
            # https://musicbrainz.org/release/12345678-abcd-1234-abcd-123456789abc
            if ($id -match 'musicbrainz\.org/release/([0-9a-f-]{36})') {
                $id = $matches[1]
                Write-Verbose "Extracted MusicBrainz release ID from URL: $id"
            }
        }
        # Qobuz: handles full URLs natively, no extraction needed
    }

    return $id
}

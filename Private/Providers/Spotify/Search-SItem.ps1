function Search-SItem {
    <#
    .SYNOPSIS
        Search Spotify for artists or albums.

    .DESCRIPTION
        Wraps Spotishell's Search-Item cmdlet to provide standardized search for OM.
        Supports searching for artists or albums based on query.

    .PARAMETER Query
        The search query (e.g., artist name or "artist album").

    .PARAMETER Type
        The type of search: 'artist' or 'album'. Defaults to 'artist'.

    .EXAMPLE
        Search-SItem -Query "Pink Floyd" -Type artist
        Searches for artists matching "Pink Floyd".

    .EXAMPLE
        Search-SItem -Query "Pink Floyd Dark Side of the Moon" -Type album
        Searches for albums matching the query.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Query,

        [Parameter()]
        [ValidateSet('artist', 'album')]
        [string]$Type = 'artist'
    )

    try {
        $result = Search-Item -Query $Query -Type $Type
        if ($result) {
            # Standardize output to match OM expectations
            if ($Type -eq 'album' -and $result.albums) {
                return [PSCustomObject]@{
                    albums = [PSCustomObject]@{
                        items = $result.albums.items
                    }
                }
            }
            elseif ($Type -eq 'artist' -and $result.artists) {
                return [PSCustomObject]@{
                    artists = [PSCustomObject]@{
                        items = $result.artists.items
                    }
                }
            }
        }
    }
    catch {
        Write-Verbose "Spotify search failed for query '$Query' type '$Type': $_"
    }

    # Return empty result on failure
    return [PSCustomObject]@{
        ($Type + 's') = [PSCustomObject]@{
            items = @()
        }
    }
}
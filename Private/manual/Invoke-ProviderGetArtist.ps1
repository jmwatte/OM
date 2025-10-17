function Invoke-ProviderGetArtist {
    <#
    .SYNOPSIS
        Get full artist details including genres from a provider.
    
    .DESCRIPTION
        Fetches complete artist information with genres. For Spotify, this ensures
        genres are populated even when not available from search results.
    
    .PARAMETER Provider
        The music provider (Spotify, Qobuz, or Discogs).
    
    .PARAMETER ArtistId
        The artist ID from the provider.
    
    .EXAMPLE
        $artist = Invoke-ProviderGetArtist -Provider 'Spotify' -ArtistId '1234567890'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Spotify', 'Qobuz', 'Discogs')]
        [string]$Provider,

        [Parameter(Mandatory)]
        [string]$ArtistId
    )

    switch ($Provider) {
        'Spotify' { 
            try {
                Get-Artist -Id $ArtistId
            } catch {
                Write-Verbose "Failed to get Spotify artist details for $ArtistId : $_"
                $null
            }
        }
        'Qobuz'   { 
            # Qobuz doesn't have a separate artist details endpoint in current implementation
            $null
        }
        'Discogs' { 
            # Discogs artist details could be added here if needed
            $null
        }
    }
}

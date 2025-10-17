function get-GenresTags($ProviderArtist, $ProviderAlbum) {
    $genreValue = $null

    # Try artist genres first
    if ($ProviderArtist) {
        $genreValue = Get-IfExists $ProviderArtist 'genres'
    }

    # Fall back to album genres or genre (singular)
    if (-not $genreValue -and $ProviderAlbum) {
        $genreValue = Get-IfExists $ProviderAlbum 'genres'
        if (-not $genreValue) {
            $genreValue = Get-IfExists $ProviderAlbum 'genre'
        }
    }

    # Ensure we return an array
    if ($genreValue) {
        return @($genreValue)
    }
    
    return @()
}
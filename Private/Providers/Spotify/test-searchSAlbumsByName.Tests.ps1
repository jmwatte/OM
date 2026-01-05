Describe 'Search-SAlbumsByName (Spotify) - genres fallback' {
    It 'fills album.genres from primary artist when album has no genres' {
        # Mock Search-Item to return an album with no genres but with artist id
        $mockAlbum = [PSCustomObject]@{
            id = 'album1'
            artists = @([PSCustomObject]@{ id = 'artist1'; name = 'Artist' })
            images = @()
            total_tracks = 10
            external_urls = @{ spotify = 'http://example' }
        }

        # Dot-source the provider under test to ensure the function is available in this runspace
        $scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { (Get-Location).Path }
        $providerFile = Join-Path $scriptRoot 'Search-SAlbumsByName.ps1'
        . (Resolve-Path -LiteralPath $providerFile -ErrorAction Stop).Path

        Mock -CommandName Search-Item -MockWith { @{ albums = @{ items = @($mockAlbum) } } }
        # Define a concrete fallback function in this session so the provider can call it directly during the test
        function Invoke-ProviderGetArtist { param($Provider, $ArtistId) return [PSCustomObject]@{ genres = @('Rock','Blues') } }

        $res = Search-SAlbumsByName -ArtistName 'Artist' -AlbumName 'Album'
        $res.Count | Should -Be 1
        $res[0].genres | Should -Be @('Rock','Blues')
    }
}
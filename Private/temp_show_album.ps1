. 'Private\Utils\Show-AlbumCandidates.ps1'
$albums = @(
    @{ name = 'One'; id = '1'; artists = @(@{ name = 'A' }); release_date = '2001'; total_tracks = 10 },
    @{ name = 'Two'; id = '2'; artists = @(@{ name = 'B' }); release_date = '2002' }
)
Show-AlbumCandidates -AlbumCandidates $albums

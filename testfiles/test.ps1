$dest = pf
$tags = @('Genres', 'AlbumArtists')
got $dest | 
sot -Transform {
    foreach ($tag in $tags) {
        $_.$tag = (
            $_.$tag |
            ForEach-Object { $_.ToLower() } |
            Select-Object -Unique |
            ForEach-Object { (Get-Culture).TextInfo.ToTitleCase($_) }
        ) 
    }
     $_ } 
    -PassThru
    -WhatIf
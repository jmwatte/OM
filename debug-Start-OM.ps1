# Debug script for Start-OM function
# This script imports the OM module and calls Start-OM with debug parameters

# Import the OM module
 Import-Module OM -Force -Verbose
<#. .\Private\Providers\Common\Invoke-ProviderSearch.ps1
. .\Private\Providers\Discogs\Search-DItem.ps1
. .\Private\Providers\MusicBrainz\Search-MBItem.ps1
. .\Private\Providers\Qobuz\Search-QItem.ps1
. .\Private\Providers\Qobuz\Search-GQArtist.ps1
. .\Private\Providers\Spotify\Search-SItem.ps1
. .\Private\Providers\Common\Invoke-MusicBrainzRequest.ps1
. .\Private\QobuzLocales.ps1
. .\Private\Providers\Common\Invoke-DiscogsRequest.ps1
$a =Invoke-ProviderSearch -Provider Qobuz -Query "the beatles help" -Type album
Write-Host "Qobuz Search Results:"
$a.albums.items | Format-List
$b =Invoke-ProviderSearch -Provider MusicBrainz -Album "help" -Artist "the beatles" -Type album
write-host "MusicBrainz Search Results:"
$b.albums.items | Format-List
$c=Invoke-ProviderSearch -Provider Discogs -Query "the beatles help" -Type album
write-host "Discogs Search Results:"
$c.albums.items | Format-List
$d=Invoke-ProviderSearch -Provider Spotify -Query "the beatles help" -Type album
write-host "Spotify Search Results:"
$d.albums.items | Format-List #>
# Call Start-OM with the desired parameters
Start-OM -Path "E:\The Beatles" -Provider discogs
 #start get-Qartistalbums with -ArtistId "https://www.qobuz.com/be-fr/interpreter/paul-weller/53535"
# . .\Private\Providers\Qobuz\Search-GQArtist.ps1
# . .\Private\QobuzLocales.ps1
# . .\Private\Get-IfExists.ps1
# $a =Search-GQArtist -Query "swans" -Verbose
# $a.artists.items | Format-List
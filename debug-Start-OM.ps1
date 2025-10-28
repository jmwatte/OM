# Debug script for Start-OM function
# This script imports the OM module and calls Start-OM with debug parameters

# Import the OM module
Import-Module OM -Force -Verbose

# Call Start-OM with the desired parameters
som  "D:\The Beatles" -Provider Qobuz
 #start get-Qartistalbums with -ArtistId "https://www.qobuz.com/be-fr/interpreter/paul-weller/53535"
# . .\Private\Providers\Qobuz\Search-GQArtist.ps1
# . .\Private\QobuzLocales.ps1
# . .\Private\Get-IfExists.ps1
# $a =Search-GQArtist -Query "swans" -Verbose
# $a.artists.items | Format-List
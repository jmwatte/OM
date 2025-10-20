# Debug script for Start-OM function
# This script imports the OM module and calls Start-OM with debug parameters

# Import the OM module
Import-Module "$PSScriptRoot\OM.psd1" -Force

# Call Start-OM with the desired parameters
#Start-OM  -Path "E:\Queens Of The Stone Age" -Provider Discogs
#start get-Qartistalbums with -ArtistId "https://www.qobuz.com/be-fr/interpreter/paul-weller/53535" so I can debug that function
. .\Private\Providers\Qobuz\Get-QArtistAlbums.ps1
. .\Private\QobuzLocales.ps1
Get-QArtistAlbums -Id "https://www.qobuz.com/be-fr/interpreter/paul-weller/53535"
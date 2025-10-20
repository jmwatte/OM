# Debug script for Start-OM function
# This script imports the OM module and calls Start-OM with debug parameters

# Import the OM module
Import-Module "$PSScriptRoot\OM.psd1" -Force

# Call Start-OM with the desired parameters
Start-OM  -Path "E:\Tangerine Dream" -provider Qobuz
#start get-Qartistalbums with -ArtistId "https://www.qobuz.com/be-fr/interpreter/paul-weller/53535" so I can debug that function
#. .\Private\Providers\Qobuz\Get-QAlbumTracks.ps1
#. .\Private\QobuzLocales.ps1
#Get-QAlbumTracks  -Id "https://www.qobuz.com/us-en/album/the-beatles-1967-1970-the-beatles/rlrv742tr79jb"
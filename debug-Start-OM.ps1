# Debug script for Start-OM function
# This script imports the OM module and calls Start-OM with debug parameters

# Import the OM module
Import-Module "$PSScriptRoot\OM.psd1" -Force

# Call Start-OM with the desired parameters
Start-OM  -Path "E:\Paul Weller" -Provider Discogs
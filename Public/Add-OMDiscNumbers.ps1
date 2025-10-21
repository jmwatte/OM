# .EXTERNALHELP OM-help.xml
<#
.SYNOPSIS
    Adds or updates disc and track numbers in audio files based on folder structure.

.DESCRIPTION
    The Add-OMDiscNumbers cmdlet updates the disc and track numbers of audio files in a folder structure.
    It can handle both disc numbering (for multi-disc albums) and track numbering within each disc folder.
    Numbers are zero-padded based on the total count (e.g., "01/12" for a 12-track disc).

    Supported audio formats:
    - MP3 (.mp3)
    - FLAC (.flac)
    - WAV (.wav)
    - M4A (.m4a)
    - AAC (.aac)

.PARAMETER baseFolder
    The root folder containing the disc subfolders. For single-disc albums, this is the folder containing the tracks.

.PARAMETER discs
    If specified, updates the disc number and total disc count for each file based on folder order.

.PARAMETER tracks
    If specified, updates the track number and total track count for files within each folder.

.EXAMPLE
    Add-OMDiscNumbers -baseFolder "D:\Music\Rush - Moving Pictures (2011)" -tracks
    Updates only track numbers for all audio files in the album folder.

.EXAMPLE
    Add-OMDiscNumbers -baseFolder "D:\Music\Pink Floyd - The Wall" -discs -tracks
    Updates both disc and track numbers for a multi-disc album, with numbers formatted based on total counts.

.EXAMPLE
    Add-OMDiscNumbers -baseFolder "D:\Music\Beatles Box Set" -discs -tracks -WhatIf
    Shows what changes would be made without actually modifying any files.

.EXAMPLE
    Add-OMDiscNumbers -baseFolder "D:\Music\Album" -discs -tracks -Verbose
    Updates numbers with detailed progress output showing each file being processed.

.NOTES
    Requires TagLib# for audio file tag manipulation.
    Files are sorted alphabetically within each folder to determine track order.
    Numbers are zero-padded based on the total count in each folder.

.INPUTS
    System.String
    You can pipe a folder path to Add-OMDiscNumbers.

.OUTPUTS
    None
    This cmdlet does not generate any output.

.LINK
    https://github.com/jmwatte/OM
#>
function Add-OMDiscNumbers {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$baseFolder,

        [Parameter(Mandatory = $false)]
        [switch]$discs,

        [Parameter(Mandatory = $false)]
        [switch]$tracks
    )

    # Ensure the base folder exists
    if (-Not (Test-Path -LiteralPath $baseFolder -PathType Container)) {
        Write-Error "The specified base folder does not exist: $baseFolder"
        return
    }

    # Load TagLib
    if (-not (Get-Command -Name Assert-TagLibLoaded -ErrorAction SilentlyContinue)) {
        . "$PSScriptRoot\Private\Assert-TagLibLoaded.ps1"
    }
    Assert-TagLibLoaded

    # Get all subfolders and sort them
    $subFolders = Get-ChildItem -LiteralPath $baseFolder -Directory | Sort-Object Name
    $totalDiscs = $subFolders.Count
    $discFormat = "d$($totalDiscs.ToString().Length)"  # Format string for disc numbers

    $discNumber = 1
    foreach ($folder in $subFolders) {
        Write-Verbose "Processing folder: $($folder.FullName) (Disc $($discNumber.ToString($discFormat)) of $totalDiscs)"
        
        # Get all audio files in current folder
        $audioFiles = Get-ChildItem -LiteralPath $folder.FullName -File | 
                     Where-Object { $_.Extension -match '\.(mp3|flac|wav|m4a|aac)$' } |
                     Sort-Object Name
        
        $totalTracks = $audioFiles.Count
        $trackFormat = "d$($totalTracks.ToString().Length)"  # Format string for track numbers
        $trackNumber = 1

        foreach ($file in $audioFiles) {
            try {
                $tagFile = [TagLib.File]::Create($file.FullName)
                $changes = @()

                if ($discs) {
                    $needsDiscUpdate = $tagFile.Tag.Disc -eq 0 -or $tagFile.Tag.DiscCount -ne $totalDiscs
                    if ($needsDiscUpdate -and $PSCmdlet.ShouldProcess($file.Name, "Set DiscNumber to $($discNumber.ToString($discFormat))/$totalDiscs")) {
                        if ($tagFile.Tag.Disc -eq 0) { $tagFile.Tag.Disc = $discNumber }
                        $tagFile.Tag.DiscCount = $totalDiscs
                        $changes += "disc $($discNumber.ToString($discFormat))/$totalDiscs"
                    }
                }

                if ($tracks) {
                    $needsTrackUpdate = $tagFile.Tag.Track -eq 0 -or $tagFile.Tag.TrackCount -ne $totalTracks
                    if ($needsTrackUpdate -and $PSCmdlet.ShouldProcess($file.Name, "Set TrackNumber to $($trackNumber.ToString($trackFormat))/$totalTracks")) {
                        if ($tagFile.Tag.Track -eq 0) { $tagFile.Tag.Track = $trackNumber }
                        $tagFile.Tag.TrackCount = $totalTracks
                        $changes += "track $($trackNumber.ToString($trackFormat))/$totalTracks"
                    }
                }

                if ($changes.Count -gt 0) {
                    $tagFile.Save()
                    Write-Host "Updated $($file.Name): $($changes -join ', ')"
                }
                else {
                    Write-Verbose "No changes needed for $($file.Name)"
                }
            }
            catch {
                Write-Warning "Failed to update file: $($file.Name). Error: $_"
            }
            finally {
                if ($tagFile) { $tagFile.Dispose() }
            }

            $trackNumber++
        }

        $discNumber++
        Write-Verbose "Completed processing folder: $($folder.Name)"
    }
}
#this function add-discNumbers takes a folder checks the folders under it finds the audiofiles in eachfolder and for each folder adds the disctag to it counting up from 1 to length of folders...
#see to it that is has whatif and accepts pipeline paths remember to use LiteralPath where possible

<#
.SYNOPSIS
    Adds disc numbers to audio files in subfolders of a specified base folder.

.DESCRIPTION
    The Add-DiscNumbers function scans the subfolders of the given base folder, sorts them alphabetically,
    and assigns incremental disc numbers (starting from 1) to all audio files within each subfolder.
    Only files with extensions .mp3, .flac, .wav, .m4a, or .aac are processed. If a file already has a disc number
    (not 0), it is skipped. The function uses TagLib# to read and write audio tags.

    Supports -WhatIf and -Confirm for safe operation, and accepts pipeline input for the base folder path.

.PARAMETER baseFolder
    The path to the base folder containing subfolders with audio files. This parameter is mandatory and accepts pipeline input.

.EXAMPLE
    Add-DiscNumbers -baseFolder "C:\Music\Albums"

    Processes all subfolders under "C:\Music\Albums", assigning disc numbers 1, 2, 3, etc., to audio files in each.

.EXAMPLE
    "C:\Music\Albums" | Add-DiscNumbers -WhatIf

    Pipes the folder path and previews changes without applying them.

.EXAMPLE
    Add-DiscNumbers -baseFolder "C:\Music\Albums" -Confirm

    Prompts for confirmation before updating each file.

.NOTES
    - Requires TagLib# library to be available in the MuFo module's lib folder.
    - Subfolders are sorted alphabetically to ensure consistent disc numbering.
    - Only updates files where the disc tag is currently 0.
    - Use -WhatIf to preview changes without modifying files.

.LINK
    https://github.com/jmwatte/MuFo
#>

function Add-DiscNumbers {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$baseFolder
    )

    # Ensure the base folder exists
    if (-Not (Test-Path -LiteralPath $baseFolder -PathType Container)) {
        Write-Error "The specified base folder does not exist: $baseFolder"
        return
    }

    #try to load load taglib else call 
    Add-Type -Path ((Get-Module OM).ModuleBase + '\lib\TagLib.dll')

    # Get all subfolders in the base folder
    $subFolders = Get-ChildItem -LiteralPath $baseFolder -Directory | Sort-Object Name

    $discNumber = 1

    foreach ($folder in $subFolders) {
        Write-Host "Processing folder: $($folder.FullName) with DiscNumber: $discNumber"

        # Get all audio files in the current folder
        $audioFiles = Get-ChildItem -LiteralPath $folder.FullName -File | Where-Object { $_.Extension -match '\.(mp3|flac|wav|m4a|aac)$' }

        foreach ($file in $audioFiles) {
            try {
                # Use TagLib# to read and write tags
                $tagFile = [TagLib.File]::Create($file.FullName)
                if ($tagFile.Tag.Disc -eq0) {
                    if ($PSCmdlet.ShouldProcess($file.Name, "Set DiscNumber to $discNumber")) {
                        $tagFile.Tag.Disc = $discNumber
                        $tagFile.Save()
                        Write-Host "Updated DiscNumber for file: $($file.Name) to $discNumber"
                    }
                } else {
                    Write-Host "File: $($file.Name) already has a DiscNumber: $($tagFile.Tag.Disc)"
                }
            } catch {
                Write-Warning "Failed to update file: $($file.Name). Error: $_"
            }
        }

        $discNumber++
    }

    Write-Host "Completed adding DiscNumbers."
}
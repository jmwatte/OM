# .EXTERNALHELP OM-help.xml
<#
.SYNOPSIS
    Adds or updates disc and track numbers in audio files based on folder structure.

.DESCRIPTION
    The Add-OMDiscNumbers cmdlet updates the disc and track numbers of audio files in a folder structure.
    It can handle both single-disc albums (files directly in the folder) and multi-disc albums (files in subfolders).
    For multi-disc albums, each subfolder represents one disc. For single-disc albums, the main folder is treated as disc 1.
    Numbers are zero-padded based on the total count (e.g., "01/12" for a 12-track disc).

    Supported audio formats:
    - MP3 (.mp3)
    - FLAC (.flac)
    - WAV (.wav)
    - M4A (.m4a)
    - AAC (.aac)
    - WMA (.wma)

.PARAMETER baseFolder
    The root folder containing the audio files. For multi-disc albums, this folder should contain subfolders for each disc.
    For single-disc albums, this is the folder containing the tracks directly.

.PARAMETER discs
    If specified, updates the total disc count for each file and sets disc numbers only if they're not already set (0).

.PARAMETER forceDiscs
    If specified, updates both disc numbers and total disc count, overwriting any existing disc numbers.

.PARAMETER tracks
    If specified, updates the total track count for each file and sets track numbers only if they're not already set (0).

.PARAMETER forceTracks
    If specified, updates both track numbers and total track count, overwriting any existing track numbers.

.EXAMPLE
    Add-OMDiscNumbers -baseFolder "D:\Music\Album" -tracks
    Updates track count for all files and sets track numbers only for files that don't have them (track=0).

.EXAMPLE
    Add-OMDiscNumbers -baseFolder "D:\Music\Album" -forceTracks
    Updates track count and renumbers all tracks sequentially, overwriting any existing track numbers.

.EXAMPLE
    Add-OMDiscNumbers -baseFolder "D:\Music\Pink Floyd - The Wall" -discs
    Updates disc count for a multi-disc album and sets disc numbers only for discs that don't have them.

.EXAMPLE
    Add-OMDiscNumbers -baseFolder "D:\Music\Pink Floyd - The Wall" -forceDiscs
    Updates disc count and renumbers all discs sequentially, overwriting any existing disc numbers.

.EXAMPLE
    Add-OMDiscNumbers -baseFolder "D:\Music\Box Set" -discs -tracks
    Updates disc and track counts, preserving existing numbers but setting them where missing.

.EXAMPLE
    Add-OMDiscNumbers -baseFolder "D:\Music\Box Set" -forceDiscs -forceTracks
    Completely renumbers discs and tracks, overwriting all existing numbers.

.EXAMPLE
    Add-OMDiscNumbers -baseFolder "D:\Music\Album" -discs -forceTracks
    Preserves existing disc numbers (setting if missing) but forces track renumbering.

.EXAMPLE
    Add-OMDiscNumbers -baseFolder "D:\Music\Album" -discs -tracks -WhatIf
    Shows what changes would be made without actually modifying any files.

.EXAMPLE
    Add-OMDiscNumbers -baseFolder "D:\Music\Album" -forceDiscs -forceTracks -Verbose
    Renumbers everything with detailed progress output showing each file being processed.

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
        [switch]$forceDiscs,

        [Parameter(Mandatory = $false)]
        [switch]$tracks,

        [Parameter(Mandatory = $false)]
        [switch]$forceTracks
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
    # Assert-TagLibLoaded may return a value; suppress it to avoid printing a stray Boolean
    [void](Assert-TagLibLoaded)

    # Collect planned changes for a clear WhatIf summary
    $plannedChanges = @()

    # Helper to detect if a folder is a disc folder (contains audio files)
    $isDiscFolder = {
        param([string]$FolderPath)
        $audioFiles = Get-ChildItem -LiteralPath $FolderPath -File -ErrorAction SilentlyContinue | 
                     Where-Object { $_.Extension -match '\.(mp3|flac|wav|m4a|aac|wma)$' }
        return ($audioFiles.Count -gt 0)
    }

    # Get all subfolders that contain audio files (potential disc folders)
    # Sort naturally by extracting numeric values from folder names (handles CD 1, CD 2, ..., CD 10 correctly)
    $allSubFolders = Get-ChildItem -LiteralPath $baseFolder -Directory -ErrorAction SilentlyContinue | 
                     Sort-Object { 
                         # Extract numeric portion from folder name (e.g., "CD 10" -> 10, "Disc 2" -> 2)
                         if ($_.Name -match '\d+') { [int]$matches[0] } else { 0 }
                     }
    $discFolders = @($allSubFolders | Where-Object { & $isDiscFolder $_.FullName })
    
    # Check if base folder itself has audio files
    $baseFolderHasAudio = & $isDiscFolder $baseFolder
    
    # Determine disc structure:
    # - If base folder has audio AND no disc subfolders: single-disc album (flat structure)
    # - If base folder has audio AND disc subfolders exist: single-disc album (ignore subfolders like "covers")
    # - If base folder has NO audio AND disc subfolders exist: multi-disc album
    $subFolders = @()
    $totalDiscs = 0
    
    if ($baseFolderHasAudio) {
        # Base folder contains audio files - treat as single disc, ignore subfolders
        Write-Verbose "Detected single-disc album (audio files in base folder)"
        $subFolders = @([PSCustomObject]@{ FullName = $baseFolder; Name = Split-Path $baseFolder -Leaf })
        $totalDiscs = 1
    }
    elseif ($discFolders.Count -gt 0) {
        # No audio in base folder, but subfolders have audio - multi-disc album
        Write-Verbose "Detected multi-disc album ($($discFolders.Count) disc folders)"
        $subFolders = $discFolders
        $totalDiscs = $discFolders.Count
    }
    else {
        # No audio files found anywhere
        Write-Warning "No audio files found in '$baseFolder' or its subfolders"
        return
    }
    
    $discFormat = "d$($totalDiscs.ToString().Length)"  # Format string for disc numbers

    $discNumber = 1
    foreach ($folder in $subFolders) {
        Write-Verbose "Processing folder: $($folder.FullName) (Disc $($discNumber.ToString($discFormat)) of $totalDiscs)"
        
        # Get all audio files in current folder
        $audioFiles = Get-ChildItem -LiteralPath $folder.FullName -File | 
                     Where-Object { $_.Extension -match '\.(mp3|flac|wav|m4a|aac|wma)$' } |
                     Sort-Object Name
        
        $totalTracks = $audioFiles.Count
        $trackFormat = "d$($totalTracks.ToString().Length)"  # Format string for track numbers
        $trackNumber = 1

        foreach ($file in $audioFiles) {
            $plannedEntry = [PSCustomObject]@{
                File = $file.FullName
                Actions = @()
            }
            try {
                $tagFile = [TagLib.File]::Create($file.FullName)
                $changes = @()

                if ($discs -or $forceDiscs) {
                    $updateDiscNumber = $forceDiscs -or $tagFile.Tag.Disc -eq 0
                    $needsDiscUpdate = $updateDiscNumber -or $tagFile.Tag.DiscCount -ne $totalDiscs

                    if ($needsDiscUpdate) {
                        $plannedEntry.Actions += "disc $($discNumber.ToString($discFormat))/$totalDiscs"
                        if ($PSCmdlet.ShouldProcess($file.Name, "Set DiscNumber to $($discNumber.ToString($discFormat))/$totalDiscs")) {
                            if ($updateDiscNumber) { $tagFile.Tag.Disc = $discNumber }
                            $tagFile.Tag.DiscCount = $totalDiscs
                            $changes += "disc $($discNumber.ToString($discFormat))/$totalDiscs"
                        }
                    }
                }

                if ($tracks -or $forceTracks) {
                    $updateTrackNumber = $forceTracks -or $tagFile.Tag.Track -eq 0
                    $needsTrackUpdate = $updateTrackNumber -or $tagFile.Tag.TrackCount -ne $totalTracks

                    if ($needsTrackUpdate) {
                        $plannedEntry.Actions += "track $($trackNumber.ToString($trackFormat))/$totalTracks"
                        if ($PSCmdlet.ShouldProcess($file.Name, "Set TrackNumber to $($trackNumber.ToString($trackFormat))/$totalTracks")) {
                            if ($updateTrackNumber) { $tagFile.Tag.Track = $trackNumber }
                            $tagFile.Tag.TrackCount = $totalTracks
                            $changes += "track $($trackNumber.ToString($trackFormat))/$totalTracks"
                        }
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

            if ($plannedEntry.Actions.Count -gt 0) { $plannedChanges += $plannedEntry }

            $trackNumber++
        }

        $discNumber++
        Write-Verbose "Completed processing folder: $($folder.Name)"
    }

    # If there were planned changes, display a concise WhatIf-style summary
    if ($plannedChanges.Count -gt 0 -and $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('WhatIf') -and $PSCmdlet.MyInvocation.BoundParameters['WhatIf']) {
        Write-Host "`nPlanned changes summary:`n" -ForegroundColor Cyan
        foreach ($entry in $plannedChanges) {
            Write-Host "$($entry.File) -> $($entry.Actions -join ', ')"
        }
        Write-Host "`nUse -WhatIf to preview changes or run without -WhatIf to apply them." -ForegroundColor Yellow
    } else {
        Write-Verbose "No planned changes detected across processed files."
    }
}
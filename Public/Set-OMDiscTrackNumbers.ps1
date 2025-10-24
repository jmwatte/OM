function Set-OMDiscTrackNumbers {
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

                if ($discs -and $tagFile.Tag.Disc -eq 0) {
                    if ($PSCmdlet.ShouldProcess($file.Name, "Set DiscNumber to $($discNumber.ToString($discFormat))/$totalDiscs")) {
                        $tagFile.Tag.Disc = $discNumber
                        $tagFile.Tag.DiscCount = $totalDiscs
                        $changes += "disc $($discNumber.ToString($discFormat))/$totalDiscs"
                    }
                }

                if ($tracks) {
                    if ($PSCmdlet.ShouldProcess($file.Name, "Set TrackNumber to $($trackNumber.ToString($trackFormat))/$totalTracks")) {
                        $tagFile.Tag.Track = $trackNumber
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
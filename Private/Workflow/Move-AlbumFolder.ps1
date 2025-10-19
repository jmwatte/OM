function Move-AlbumFolder {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$AlbumPath,
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$NewArtist,
        [Parameter(Mandatory = $false)][string]$NewYear,
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$NewAlbumName,
        [Parameter(Mandatory = $false)][bool]$RemoveEmptyOldArtistFolder = $true,
        [Parameter(Mandatory = $false)][switch]$Force
    )

    begin {
        if (-not (Test-Path -LiteralPath $AlbumPath -PathType Container)) {
            throw "Album folder not found: $AlbumPath"
        }

        $currentArtistPath = Split-Path -Parent $AlbumPath
        $currentArtistName = Split-Path -Leaf $currentArtistPath
        $artistParentPath = Split-Path -Parent $currentArtistPath

        $currentAlbumLeaf = Split-Path -Leaf $AlbumPath
        if ([string]::IsNullOrWhiteSpace($NewYear)) {
            if ($currentAlbumLeaf -match '^(?<year>\d{4})\s*-\s*(.+)$') { $NewYear = $matches.year }
            else { $NewYear = '' }
        }

        $targetArtistPath = Join-Path -Path $artistParentPath -ChildPath $NewArtist
        if ($NewYear) { $baseAlbumName = "$NewYear - $NewAlbumName" } else { $baseAlbumName = $NewAlbumName }

        function Get-UniqueAlbumPath {
            param([string]$ArtistPath, [string]$BaseAlbumName, [string]$OriginalAlbumPath)
            $candidate = Join-Path -Path $ArtistPath -ChildPath $BaseAlbumName

            # If the desired path doesn't exist, we're good.
            if (-not (Test-Path -LiteralPath $candidate)) { return $candidate }

            # If the path exists, check if it's the SAME folder we are trying to move.
            if ((Resolve-Path -LiteralPath $candidate).Path -eq (Resolve-Path -LiteralPath $OriginalAlbumPath).Path) {
                return $candidate # It's the same folder, so no rename is needed.
            }

            # If it exists and it's a DIFFERENT folder, then we have a real collision.
            $n = 2
            while ($true) {
                $candidateName = "$BaseAlbumName ($n)"
                $candidate = Join-Path -Path $ArtistPath -ChildPath $candidateName
                if (-not (Test-Path -LiteralPath $candidate)) { return $candidate }
                $n++
                if ($n -gt 9999) { throw "Unable to find non-colliding name for $BaseAlbumName in $ArtistPath" }
            }
        }

        $createArtist = -not (Test-Path -LiteralPath $targetArtistPath -PathType Container)
        if ($createArtist) {
            if ($PSCmdlet.ShouldProcess($targetArtistPath, "Create artist folder")) {
                New-Item -Path $targetArtistPath -ItemType Directory -ErrorAction Stop | Out-Null
            }
        }

        $destAlbumPath = Get-UniqueAlbumPath -ArtistPath $targetArtistPath -BaseAlbumName $baseAlbumName -OriginalAlbumPath $AlbumPath

        # If the source and destination paths are the same, no action is needed.
        if ((Resolve-Path -LiteralPath $destAlbumPath).Path -eq (Resolve-Path -LiteralPath $AlbumPath).Path) {
            Write-Verbose "Source and destination album paths are identical. No move or rename necessary."
            return [PSCustomObject]@{
                Success           = $true
                OldAlbumPath      = $AlbumPath
                NewAlbumPath      = $destAlbumPath
                OldArtistPath     = $currentArtistPath
                NewArtistPath     = $targetArtistPath
                CollisionAdjusted = $false
                Action            = 'None'
            }
        }

        $renamingOnly = ($currentArtistPath -eq $targetArtistPath)

        # build concise action description
        $oldLeaf = Split-Path -Leaf $AlbumPath
        $newLeaf = Split-Path -Leaf $destAlbumPath
        if ($renamingOnly) {
            $actionDesc = "Rename album '$oldLeaf' -> '$newLeaf' in artist '$currentArtistName'"
        } else {
            $actionDesc = "Move album '$oldLeaf' from artist '$currentArtistName' -> '$NewArtist'"
        }
    }

    process {
        try {
            if ($PSCmdlet.ShouldProcess($AlbumPath, $actionDesc)) {
                if ($renamingOnly) {
                    $newLeaf = Split-Path -Leaf $destAlbumPath
                    Rename-Item -LiteralPath $AlbumPath -NewName $newLeaf -ErrorAction Stop
                }
                else {
                    $destParent = Split-Path -Parent $destAlbumPath
                    if (-not (Test-Path -LiteralPath $destParent -PathType Container)) {
                        if ($PSCmdlet.ShouldProcess($destParent, "Create destination parent folder")) {
                            New-Item -Path $destParent -ItemType Directory -ErrorAction Stop | Out-Null
                        }
                    }

                    Move-Item -LiteralPath $AlbumPath -Destination $destAlbumPath -ErrorAction Stop -Force:$Force.IsPresent
                }
            }

            if ($RemoveEmptyOldArtistFolder -and -not $renamingOnly -and (Test-Path -LiteralPath $currentArtistPath -PathType Container)) {
                $children = Get-ChildItem -LiteralPath $currentArtistPath -Force -ErrorAction SilentlyContinue
                if (-not $children) {
                    $rmDesc = "Remove empty artist folder '$currentArtistPath'"
                    if ($PSCmdlet.ShouldProcess($currentArtistPath, $rmDesc)) {
                        Remove-Item -LiteralPath $currentArtistPath -Force -Recurse:$false -ErrorAction Stop
                    }
                }
            }

            [PSCustomObject]@{
                Success           = $true
                OldAlbumPath      = $AlbumPath
                NewAlbumPath      = $destAlbumPath
                OldArtistPath     = $currentArtistPath
                NewArtistPath     = $targetArtistPath
                CollisionAdjusted = ($destAlbumPath -ne (Join-Path -Path $targetArtistPath -ChildPath $baseAlbumName))
                Action            = if ($renamingOnly) { 'Rename' } else { 'Move' }
            }
        }
        catch {
            throw "Failed to move/rename album folder: $($_)"
        }
    }
}
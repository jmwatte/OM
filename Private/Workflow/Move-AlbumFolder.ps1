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
        Write-Host "--- DEBUG: Move-AlbumFolder ---" -ForegroundColor Magenta
        Write-Host "Input AlbumPath: $AlbumPath"
        Write-Host "Input NewArtist: $NewArtist"
        Write-Host "Input NewYear: $NewYear"
        Write-Host "Input NewAlbumName: $NewAlbumName"
        Write-Host "--------------------------------" -ForegroundColor Magenta

        $AlbumPath = $AlbumPath.TrimEnd('\/')
        if (-not (Test-Path -LiteralPath $AlbumPath -PathType Container)) {
            throw "Album folder not found: $AlbumPath"
        }

        $currentArtistPath = Split-Path -Parent $AlbumPath
        $currentArtistName = Split-Path -Leaf $currentArtistPath
        $artistParentPath  = Split-Path -Parent $currentArtistPath

        $currentAlbumLeaf = Split-Path -Leaf $AlbumPath
        if ([string]::IsNullOrWhiteSpace($NewYear)) {
            if ($currentAlbumLeaf -match '^(?<year>\d{4})\s*-\s*(.+)$') { $NewYear = $matches.year }
            else { $NewYear = '' }
        }

        $targetArtistPath = Join-Path -Path $artistParentPath -ChildPath $NewArtist
        if ($NewYear) { $baseAlbumName = "$NewYear - $NewAlbumName" } else { $baseAlbumName = $NewAlbumName }

        Write-Host "Derived currentArtistPath: $currentArtistPath"
        Write-Host "Derived artistParentPath: $artistParentPath"
        Write-Host "Derived targetArtistPath: $targetArtistPath"
        Write-Host "Derived baseAlbumName: $baseAlbumName"
        Write-Host "--------------------------------" -ForegroundColor Magenta

        function Get-UniqueAlbumPath {
            param([string]$ArtistPath, [string]$BaseAlbumName, [string]$OriginalAlbumPath)
            $candidate = Join-Path -Path $ArtistPath -ChildPath $BaseAlbumName
            Write-Host "Get-UniqueAlbumPath candidate: $candidate"

            if (-not (Test-Path -LiteralPath $candidate)) { return $candidate }

            if ((Resolve-Path -LiteralPath $candidate).ProviderPath -eq (Resolve-Path -LiteralPath $OriginalAlbumPath).ProviderPath) {
                return $candidate
            }

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
        Write-Host "Final destAlbumPath: $destAlbumPath" -ForegroundColor Cyan

        $renamingOnly = ($currentArtistPath.Trim() -eq $targetArtistPath.Trim())
        $oldLeaf = Split-Path -Leaf $AlbumPath
        $newLeaf = Split-Path -Leaf $destAlbumPath
        if ($renamingOnly) {
            $actionDesc = "Rename album '$oldLeaf' -> '$newLeaf' in artist '$currentArtistName'"
        } else {
            $actionDesc = "Move album '$oldLeaf' from artist '$currentArtistName' -> '$NewArtist'"
        }

        # stash values for process
        $script:destAlbumPath = $destAlbumPath
        $script:baseAlbumName = $baseAlbumName
        $script:renamingOnly  = $renamingOnly
        $script:actionDesc    = $actionDesc
        $script:currentArtistPath = $currentArtistPath
        $script:targetArtistPath  = $targetArtistPath
    }

    process {
        try {
            # EARLY EXIT GUARD
            if ((Resolve-Path -LiteralPath $script:destAlbumPath).ProviderPath.Trim() -eq (Resolve-Path -LiteralPath $AlbumPath).ProviderPath.Trim()) {
                Write-Verbose "Source and destination album paths are identical. No move or rename necessary."
                return [PSCustomObject]@{
                    Success           = $true
                    OldAlbumPath      = $AlbumPath
                    NewAlbumPath      = $script:destAlbumPath
                    OldArtistPath     = $script:currentArtistPath
                    NewArtistPath     = $script:targetArtistPath
                    CollisionAdjusted = $false
                    Action            = 'None'
                }
            }

            if ($PSCmdlet.ShouldProcess($AlbumPath, $script:actionDesc)) {
                if ($script:renamingOnly) {
                    $newLeaf = Split-Path -Leaf $script:destAlbumPath
                    Rename-Item -LiteralPath $AlbumPath -NewName $newLeaf -ErrorAction Stop
                }
                else {
                    $destParent = Split-Path -Parent $script:destAlbumPath
                    if (-not (Test-Path -LiteralPath $destParent -PathType Container)) {
                        if ($PSCmdlet.ShouldProcess($destParent, "Create destination parent folder")) {
                            New-Item -Path $destParent -ItemType Directory -ErrorAction Stop | Out-Null
                        }
                    }
                    Move-Item -LiteralPath $AlbumPath -Destination $script:destAlbumPath -ErrorAction Stop -Force:$Force.IsPresent
                }
            }

            if ($RemoveEmptyOldArtistFolder -and -not $script:renamingOnly -and (Test-Path -LiteralPath $script:currentArtistPath -PathType Container)) {
                $children = Get-ChildItem -LiteralPath $script:currentArtistPath -Force -ErrorAction SilentlyContinue
                if (-not $children) {
                    $rmDesc = "Remove empty artist folder '$script:currentArtistPath'"
                    if ($PSCmdlet.ShouldProcess($script:currentArtistPath, $rmDesc)) {
                        Remove-Item -LiteralPath $script:currentArtistPath -Force -Recurse:$false -ErrorAction Stop
                    }
                }
            }

            [PSCustomObject]@{
                Success           = $true
                OldAlbumPath      = $AlbumPath
                NewAlbumPath      = $script:destAlbumPath
                OldArtistPath     = $script:currentArtistPath
                NewArtistPath     = $script:targetArtistPath
                CollisionAdjusted = ($script:destAlbumPath -ne (Join-Path -Path $script:targetArtistPath -ChildPath $script:baseAlbumName))
                Action            = if ($script:renamingOnly) { 'Rename' } else { 'Move' }
            }
        }
        catch {
            throw "Failed to move/rename album folder: $($_)"
        }
    }
}









<# function Move-AlbumFolder {
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
        Write-Host "--- DEBUG: Move-AlbumFolder ---" -ForegroundColor Magenta
        Write-Host "Input AlbumPath: $AlbumPath"
        Write-Host "Input NewArtist: $NewArtist"
        Write-Host "Input NewYear: $NewYear"
        Write-Host "Input NewAlbumName: $NewAlbumName"
        Write-Host "--------------------------------" -ForegroundColor Magenta

        $AlbumPath = $AlbumPath.TrimEnd('\/')
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

        Write-Host "Derived currentArtistPath: $currentArtistPath"
        Write-Host "Derived artistParentPath: $artistParentPath"
        Write-Host "Derived targetArtistPath: $targetArtistPath"
        Write-Host "Derived baseAlbumName: $baseAlbumName"
        Write-Host "--------------------------------" -ForegroundColor Magenta

        function Get-UniqueAlbumPath {
            param([string]$ArtistPath, [string]$BaseAlbumName, [string]$OriginalAlbumPath)
            $candidate = Join-Path -Path $ArtistPath -ChildPath $BaseAlbumName
            Write-Host "Get-UniqueAlbumPath candidate: $candidate"

            if (-not (Test-Path -LiteralPath $candidate)) { return $candidate }

            if ((Resolve-Path -LiteralPath $candidate).ProviderPath -eq (Resolve-Path -LiteralPath $OriginalAlbumPath).ProviderPath) {
                return $candidate
            }

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
        Write-Host "Final destAlbumPath: $destAlbumPath" -ForegroundColor Cyan

        if ((Resolve-Path -LiteralPath $destAlbumPath).ProviderPath.Trim() -eq (Resolve-Path -LiteralPath $AlbumPath).ProviderPath.Trim()) {
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

        $renamingOnly = ($currentArtistPath.Trim() -eq $targetArtistPath.Trim())

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
 #>
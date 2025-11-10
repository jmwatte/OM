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
        
        # Handle drive root case: if album is at root (e.g., E:\Album), artistParentPath will be empty
        # In this case, use the drive root as the parent path
        if ([string]::IsNullOrEmpty($artistParentPath) -and $currentArtistPath -match '^[A-Z]:\\?$') {
            $artistParentPath = $currentArtistPath
            Write-Verbose "Album is at drive root, using drive as parent: $artistParentPath"
        }

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

        # Check if artist folder needs case change (exists but case differs)
        # On Windows, Test-Path is case-insensitive, so check actual name from Get-Item
        $artistFolderExists = Test-Path -LiteralPath $targetArtistPath -PathType Container
        $artistCaseDiffersOnly = $false
        
        if ($artistFolderExists -and (Test-Path -LiteralPath $currentArtistPath -PathType Container)) {
            $actualArtistPath = (Get-Item -LiteralPath $currentArtistPath).FullName
            $artistCaseDiffersOnly = ($actualArtistPath -cne $targetArtistPath) -and ($actualArtistPath -ieq $targetArtistPath)
        }
        
        $createArtist = -not $artistFolderExists
        
        if ($createArtist) {
            if ($PSCmdlet.ShouldProcess($targetArtistPath, "Create artist folder")) {
                New-Item -Path $targetArtistPath -ItemType Directory -ErrorAction Stop | Out-Null
            }
        }
        
        # Handle case-only change of artist folder using two-step rename (Windows requirement)
        if ($artistCaseDiffersOnly) {
            $tempArtistName = [Guid]::NewGuid().ToString()
            $tempArtistPath = Join-Path -Path $artistParentPath -ChildPath $tempArtistName
            if ($PSCmdlet.ShouldProcess($currentArtistPath, "Change artist folder case via temp rename")) {
                Write-Verbose "Renaming artist folder case: '$currentArtistPath' -> temp -> '$targetArtistPath'"
                Rename-Item -LiteralPath $currentArtistPath -NewName $tempArtistName -ErrorAction Stop
                Rename-Item -LiteralPath $tempArtistPath -NewName (Split-Path -Leaf $targetArtistPath) -ErrorAction Stop
                # After artist folder case rename, update the album path to reflect new artist folder
                $AlbumPath = Join-Path -Path $targetArtistPath -ChildPath (Split-Path -Leaf $AlbumPath)
                Write-Verbose "Updated AlbumPath after artist rename: $AlbumPath"
            }
        }

        $destAlbumPath = Get-UniqueAlbumPath -ArtistPath $targetArtistPath -BaseAlbumName $baseAlbumName -OriginalAlbumPath $AlbumPath
        Write-Host "Final destAlbumPath: $destAlbumPath" -ForegroundColor Cyan

        $renamingOnly = ($currentArtistPath.Trim() -ceq $targetArtistPath.Trim())
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
        # EARLY EXIT GUARD - Use case-sensitive comparison to allow case-only renames (e.g., tears for fears → Tears For Fears)
        # PowerShell -eq is case-insensitive by default, so use -ceq for exact match
        if ($script:destAlbumPath -ceq $AlbumPath) {
            Write-Verbose "Source and destination album paths are identical (case-sensitive match). No move or rename necessary."
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
                # IMPORTANT: only pass the leaf name here
                $newLeaf = Split-Path -Leaf $script:destAlbumPath
                Write-Verbose "Renaming '$AlbumPath' -> '$newLeaf'"
                Rename-Item -LiteralPath "$AlbumPath" -NewName "$newLeaf" -ErrorAction Stop
            }
            else {
                $destParent = Split-Path -Parent $script:destAlbumPath
                if (-not (Test-Path -LiteralPath $destParent -PathType Container)) {
                    if ($PSCmdlet.ShouldProcess($destParent, "Create destination parent folder")) {
                        New-Item -Path $destParent -ItemType Directory -ErrorAction Stop | Out-Null
                    }
                }
                Write-Verbose "Moving '$AlbumPath' -> '$script:destAlbumPath'"
                Move-Item -LiteralPath "$AlbumPath" -Destination "$script:destAlbumPath" -ErrorAction Stop -Force:$Force.IsPresent
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
[CmdletBinding(SupportsShouldProcess = $true)]

param(
    [Parameter(Mandatory=$true)]
    [string]$RootDir
)

$audioExts = @('.mp3', '.flac', '.wav', '.m4a', '.ogg', '.aac')
$imageExts = @('.jpg', '.jpeg', '.png', '.bmp', '.gif')
$coverNames = @('folder', 'cover', 'album','front')

function HasAudio($folder) {
    $files = Get-ChildItem $folder -File | Where-Object { $_.Extension -in $audioExts }
    return $files.Count -gt 0
}

function HasCover($folder) {
    $files = Get-ChildItem $folder -File | Where-Object { ($_.BaseName -imatch 'folder|cover|albumfront') -and ($_.Extension.ToLower() -in $imageExts) }
    return $files.Count -gt 0
}

function IsDiscFolder($folder) {
    $name = $folder.Name
    return $name -imatch '(cd|disc)\s*\d+'
}

$topFolders = Get-ChildItem $RootDir -Directory
$results = @()

foreach ($top in $topFolders) {
    Write-Verbose "Processing top folder: $($top.FullName)"
    
    # Find all folders (including top itself) with audio files
    $allFoldersWithAudio = @()
    
    # Check the top folder itself
    if (HasAudio $top) {
        $allFoldersWithAudio += $top
    }
    
    # Check all subfolders recursively
    Get-ChildItem $top.FullName -Directory -Recurse | ForEach-Object {
        if (HasAudio $_) {
            $allFoldersWithAudio += $_
        }
    }
    
    if ($allFoldersWithAudio.Count -eq 0) {
        Write-Verbose "No folders with audio found in $($top.FullName)"
        continue
    }
    
    # Now find folders with audio but NO cover, and NO subfolders with audio
    $candidatesNeedingCovers = @()
    foreach ($folder in $allFoldersWithAudio) {
        # Skip if this folder has a cover
        if (HasCover $folder) {
            Write-Verbose "Folder $($folder.FullName) has audio AND cover - skipping"
            continue
        }
        
        # Check if this folder has any subfolders with audio
        $hasAudioSubfolders = $false
        Get-ChildItem $folder.FullName -Directory -Recurse | ForEach-Object {
            if (HasAudio $_) {
                $hasAudioSubfolders = $true
            }
        }
        
        if (-not $hasAudioSubfolders) {
            # This is a leaf folder with audio but no cover
            Write-Verbose "Found leaf folder with audio but no cover: $($folder.FullName)"
            $candidatesNeedingCovers += $folder
        }
    }
    
    if ($candidatesNeedingCovers.Count -eq 0) {
        Write-Verbose "No folders needing covers in $($top.FullName)"
        continue
    }
    
    # Process each candidate
    foreach ($candidate in $candidatesNeedingCovers) {
        $isDisc = IsDiscFolder $candidate
        if ($isDisc) {
            $parent = $candidate.Parent
            if (HasCover $parent) {
                # Copy cover from parent to candidate
                $coverFile = Get-ChildItem $parent -File | Where-Object { ($_.BaseName -imatch 'folder|cover|album') -and ($_.Extension.ToLower() -in $imageExts) } | Select-Object -First 1
                if ($coverFile) {
                    $dest = Join-Path $candidate.FullName $coverFile.Name
                    Write-Verbose "Copying $($coverFile.FullName) to $dest"
                    if ($PSCmdlet.ShouldProcess($dest, "Copy cover file from $($coverFile.FullName)")) {
                        Copy-Item $coverFile.FullName $dest
                    }
                }
            } else {
                Write-Verbose "Disc folder $($candidate.FullName) has no cover in parent $($parent.FullName), adding parent to results"
                $results += $parent.FullName
            }
        } else {
            # Not a disc folder and no cover
            Write-Verbose "Non-disc folder $($candidate.FullName) has no cover, adding to results"
            $results += $candidate.FullName
        }
    }
}

# Output the collected folders (remove duplicates)
$results | Select-Object -Unique | ForEach-Object { Write-Output $_ }
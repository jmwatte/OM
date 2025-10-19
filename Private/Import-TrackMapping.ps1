function Import-TrackMapping {
<#
.SYNOPSIS
    Import edited track mapping file and apply changes to audio files.

.DESCRIPTION
    Takes the edited mapping file from New-TrackMapping and applies the changes:
    1. Updates track numbers to match the order you specified
    2. Updates titles if you edited them
    3. Optionally renames files to match new track order
    
    IMPORTANT: Creates backup copies before making any changes!

.PARAMETER MappingFile
    Path to the edited mapping file (.txt) from New-TrackMapping.

.PARAMETER AudioPath
    Path to folder containing the audio files to update.
    If not specified, uses the folder containing the mapping file.

.PARAMETER RenameFiles
    If specified, also renames files to match new track order.
    Format: "01 - Title.ext", "02 - Title.ext", etc.

.PARAMETER BackupSuffix
    Suffix to add to backup files. Default: ".backup"



.EXAMPLE
    Import-TrackMapping -MappingFile "album-mapping.txt"
    
    Updates track numbers based on your edited mapping file.

.EXAMPLE
    Import-TrackMapping -MappingFile "fix-tracks.txt" -RenameFiles
    
    Updates track numbers AND renames files to match new order.

.EXAMPLE
    Import-TrackMapping -MappingFile "mapping.txt" -WhatIf
    
    Shows what would be changed without making any changes.

.NOTES
    Author: jmw
    Part of manual override system for MuFo.
    Always creates backups before making changes.
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$MappingFile,
        
        [string]$AudioPath,
        
        [switch]$RenameFiles,
        
        [string]$BackupSuffix = ".backup"
    )
    
    if (-not (Test-Path $MappingFile)) {
        Write-Error "Mapping file not found: $MappingFile"
        return
    }
    
    # Determine audio path
    if (-not $AudioPath) {
        $AudioPath = Split-Path (Resolve-Path $MappingFile) -Parent
    }
    
    if (-not (Test-Path $AudioPath)) {
        Write-Error "Audio path not found: $AudioPath"
        return
    }
    
    Write-Host "Reading mapping file: $MappingFile" -ForegroundColor Cyan
    
    # Parse mapping file
    $mappingLines = Get-Content $MappingFile | Where-Object { 
        $_ -and -not $_.StartsWith('#') -and $_.Trim()
    }
    
    if ($mappingLines.Count -eq 0) {
        Write-Error "No valid track mappings found in file"
        return
    }
    
    # Parse each mapping line
    $trackMappings = @()
    foreach ($line in $mappingLines) {
        if ($line -match '^(\d+)\.\s*(.+)$') {
            $trackMappings += @{
                TrackNumber = [int]$matches[1]
                Title = $matches[2].Trim()
                OriginalLine = $line
            }
        } else {
            Write-Warning "Skipping invalid line: $line"
        }
    }
    
    if ($trackMappings.Count -eq 0) {
        Write-Error "No valid track mappings parsed from file"
        return
    }
    
    Write-Host "Parsed $($trackMappings.Count) track mappings" -ForegroundColor Green
    
    # Get audio files in the directory
    $audioExtensions = @('.mp3', '.flac', '.m4a', '.ogg', '.wav', '.wma')
    $audioFiles = Get-ChildItem -Path $AudioPath -File | Where-Object { 
        $_.Extension.ToLower() -in $audioExtensions 
    }
    
    if ($audioFiles.Count -ne $trackMappings.Count) {
        Write-Warning "Mismatch: $($audioFiles.Count) audio files but $($trackMappings.Count) mappings"
        Write-Host "Audio files found:"
        $audioFiles | ForEach-Object { Write-Host "  $($_.Name)" }
        Write-Host "Mappings:"
        $trackMappings | ForEach-Object { Write-Host "  $($_.TrackNumber). $($_.Title)" }
        
        if (-not $PSCmdlet.ShouldContinue("Continue with mismatched counts?", "File Count Mismatch")) {
            return
        }
    }
    
    # Try to match files to mappings (by order in original playlist)
    # This assumes the mapping file order corresponds to the original file order
    $changes = @()
    for ($i = 0; $i -lt [Math]::Min($audioFiles.Count, $trackMappings.Count); $i++) {
        $file = $audioFiles[$i]
        $mapping = $trackMappings[$i]
        
        # Read current tags
        $currentTags = @{}
        try {
            if (([System.Management.Automation.PSTypeName]'TagLib.File').Type) {
                $tagFile = [TagLib.File]::Create($file.FullName)
                $currentTags = @{
                    Track = $tagFile.Tag.Track
                    Title = $tagFile.Tag.Title
                    Artist = $tagFile.Tag.FirstPerformer
                    Album = $tagFile.Tag.Album
                }
                $tagFile.Dispose()
            }
        } catch {
            Write-Warning "Could not read tags from: $($file.Name)"
        }
        
        # Determine new filename if renaming
        $newFileName = $file.Name
        if ($RenameFiles) {
            $trackNum = $mapping.TrackNumber.ToString("00")
            $cleanTitle = $mapping.Title -replace '[<>:"/\\|?*]', '_'
            $newFileName = "$trackNum - $cleanTitle$($file.Extension)"
        }
        
        $changes += @{
            File = $file
            CurrentTrack = $currentTags.Track
            CurrentTitle = $currentTags.Title
            NewTrack = $mapping.TrackNumber
            NewTitle = $mapping.Title
            CurrentFileName = $file.Name
            NewFileName = $newFileName
            WillRename = ($RenameFiles -and $newFileName -ne $file.Name)
            WillUpdateTags = ($mapping.TrackNumber -ne $currentTags.Track -or $mapping.Title -ne $currentTags.Title)
        }
    }
    
    # Show what will be changed
    Write-Host "`nChanges to be made:" -ForegroundColor Yellow
    foreach ($change in $changes) {
        Write-Host "`n📁 $($change.CurrentFileName)" -ForegroundColor Cyan
        
        if ($change.WillUpdateTags) {
            if ($change.CurrentTrack -ne $change.NewTrack) {
                Write-Host "   🔢 Track: $($change.CurrentTrack) → $($change.NewTrack)" -ForegroundColor White
            }
            if ($change.CurrentTitle -ne $change.NewTitle) {
                Write-Host "   🏷️  Title: '$($change.CurrentTitle)' → '$($change.NewTitle)'" -ForegroundColor White
            }
        }
        
        if ($change.WillRename) {
            Write-Host "   📝 Rename: $($change.NewFileName)" -ForegroundColor White
        }
        
        if (-not $change.WillUpdateTags -and -not $change.WillRename) {
            Write-Host "   ✅ No changes needed" -ForegroundColor Green
        }
    }
    
    if ($WhatIfPreference) {
        Write-WhatIfMessage "`n[WhatIf] No changes made - this was a preview only" -ForegroundColor Magenta
        return
    }
    
    # Confirm before making changes
    $changesNeeded = $changes | Where-Object { $_.WillUpdateTags -or $_.WillRename }
    if ($changesNeeded.Count -eq 0) {
        Write-Host "`nNo changes needed - all files already match mapping!" -ForegroundColor Green
        return
    }
    
    if (-not $PSCmdlet.ShouldContinue("Apply $($changesNeeded.Count) changes?", "Confirm Changes")) {
        return
    }
    
    # Apply changes
    Write-Host "`nApplying changes..." -ForegroundColor Yellow
    $successCount = 0
    
    foreach ($change in $changes) {
        if (-not ($change.WillUpdateTags -or $change.WillRename)) {
            continue
        }
        
        try {
            # Create backup if we're modifying the file
            if ($change.WillUpdateTags -or $change.WillRename) {
                $backupPath = "$($change.File.FullName)$BackupSuffix"
                if (-not (Test-Path $backupPath)) {
                    Copy-Item $change.File.FullName $backupPath
                    Write-Verbose "Created backup: $backupPath"
                }
            }
            
            # Update tags
            if ($change.WillUpdateTags) {
                if (([System.Management.Automation.PSTypeName]'TagLib.File').Type) {
                    $tagFile = [TagLib.File]::Create($change.File.FullName)
                    $tagFile.Tag.Track = $change.NewTrack
                    $tagFile.Tag.Title = $change.NewTitle
                    $tagFile.Save()
                    $tagFile.Dispose()
                    Write-Host "✅ Updated tags: $($change.File.Name)" -ForegroundColor Green
                } else {
                    Write-Warning "TagLib not available - skipping tag update for: $($change.File.Name)"
                }
            }
            
            # Rename file
            if ($change.WillRename) {
                $newPath = Join-Path $AudioPath $change.NewFileName
                if (Test-Path $newPath) {
                    Write-Warning "File already exists: $($change.NewFileName) - skipping rename"
                } else {
                    Rename-Item $change.File.FullName $change.NewFileName
                    Write-Host "✅ Renamed: $($change.NewFileName)" -ForegroundColor Green
                }
            }
            
            $successCount++
            
        } catch {
            Write-Error "Failed to process $($change.File.Name): $($_.Exception.Message)"
        }
    }
    
    Write-Host "`n🎉 Successfully processed $successCount of $($changesNeeded.Count) files" -ForegroundColor Green
    
    if ($BackupSuffix) {
        Write-Host "💾 Backup files created with suffix: $BackupSuffix" -ForegroundColor Cyan
        Write-Host "   Remove backups when satisfied with results" -ForegroundColor Gray
    }
    
    return @{
        ProcessedFiles = $successCount
        TotalChanges = $changesNeeded.Count
        BackupSuffix = $BackupSuffix
        MappingFile = $MappingFile
    }
}
function Save-TagsForFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][hashtable]$TagValues,
        [Parameter()][switch]$WhatIf
    )

    if (-not (Test-Path -LiteralPath $FilePath)) {
        throw "File does not exist: $FilePath"
    }

    $locked = Assert-FileLocked -Path $FilePath
    if ($locked) {
        $result = Wait-ForFileUnlock -Path $FilePath
        if ($result.Action -eq 'skip') {
            Write-Warning "Skipping file: $FilePath"
            return @{ Success = $false; Reason = 'skipped' }
        }
        elseif ($result.Action -eq 'force') {
            Write-Warning "Attempting forced write on file: $FilePath"
            # continue to attempt save
        }
        # else proceed because user freed the file
    }

    try {
        if ($WhatIf.IsPresent -or $WhatIf) {
            Write-Host "WhatIf: would open and save tags to $FilePath"
            return @{ Success = $true; WhatIf = $true }
        }

        # Open TagLib.File, set tags, save, dispose
        $tagFile = [TagLib.File]::Create($FilePath)
        try {
            foreach ($k in $TagValues.Keys) {
                $v = $TagValues[$k]
                switch ($k) {
                    'AlbumArtist'{ $tagFile.Tag.AlbumArtists = @($v) }
                    'Title' { $tagFile.Tag.Title = $v }
                    'Track' { $tagFile.Tag.Track = [uint]$v }
                    'Disc' { $tagFile.Tag.Disc = [uint]$v }
                    'Performers' { 
                        if ($v -is [string] -and $v -match ';') {
                            $tagFile.Tag.Performers = $v -split '\s*;\s*'
                        } else {
                            $tagFile.Tag.Performers = @($v)
                        }
                    }
                    'Genres' {
                        # Replace genres (don't append). Handle both string and array inputs.
                        if ($v -is [array]) {
                            $tagFile.Tag.Genres = $v
                        } elseif ($v -is [string] -and $v -match ';') {
                            $tagFile.Tag.Genres = $v -split '\s*;\s*'
                        } else {
                            $tagFile.Tag.Genres = @($v)
                        }
                    }
                    'Date' { $tagFile.Tag.Year = [uint]$v }
                    'Album' { $tagFile.Tag.Album = $v }
                    'Composer' { 
                        if ($v -is [string] -and $v -match ';') {
                            $tagFile.Tag.Composers = $v -split '\s*;\s*'
                        } else {
                            $tagFile.Tag.Composers = @($v)
                        }
                    }
                    'Composers' { 
                        if ($v -is [string] -and $v -match ';') {
                            $tagFile.Tag.Composers = $v -split '\s*;\s*'
                        } else {
                            $tagFile.Tag.Composers = @($v)
                        }
                    }
                    'Conductor' {
                        # Store conductor in Conductor field if available (classical music)
                        if ($tagFile.Tag.PSObject.Properties['Conductor']) {
                            $tagFile.Tag.Conductor = $v
                        } else {
                            # Fallback: add to Comment/Description if Conductor field doesn't exist
                            if ($tagFile -is [TagLib.Flac.File]) {
                                # FLAC uses Description field
                                if ($tagFile.Tag.Description) {
                                    $tagFile.Tag.Description += "`nConductor: $v"
                                } else {
                                    $tagFile.Tag.Description = "Conductor: $v"
                                }
                            } else {
                                # Other formats use Comment
                                if ($tagFile.Tag.Comment) {
                                    $tagFile.Tag.Comment += "`nConductor: $v"
                                } else {
                                    $tagFile.Tag.Comment = "Conductor: $v"
                                }
                            }
                        }
                    }
                    'Comment' {
                        # Store full production credits in Comment/Description field
                        # FLAC files use Description field (DESCRIPTION Vorbis comment)
                        if ($tagFile -is [TagLib.Flac.File]) {
                            $tagFile.Tag.Description = $v
                        } else {
                            $tagFile.Tag.Comment = $v
                        }
                    }
                    default {
                        if ($tagFile.Tag.PSObject.Properties.Match($k)) {
                            $tagFile.Tag.$k = $v
                        }
                    }
                }
            }
            $tagFile.Save()
        }
        finally {
            $tagFile.Dispose()
        }

        return @{ Success = $true }
    }
    catch {
        Write-Warning "Failed to save tags for $($FilePath): $_"
        return @{ Success = $false; Reason = $_.Exception.Message }
    }
}
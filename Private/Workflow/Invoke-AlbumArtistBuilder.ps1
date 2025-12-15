function Invoke-AlbumArtistBuilder {
    <#
    .SYNOPSIS
        Interactive album artist builder for classical music and complex releases.
    
    .DESCRIPTION
        Allows user to select and order artists to build the album artist string.
        Useful when automatic detection is ambiguous (e.g., composer vs. performer).
    
    .PARAMETER AlbumName
        Name of the album.
    
    .PARAMETER Tracks
        Array of track objects with artist information.
    
    .PARAMETER CurrentAlbumArtist
        Current/default album artist value.
    
    .EXAMPLE
        $albumArtist = Invoke-AlbumArtistBuilder -AlbumName "Violin Concerto" -Tracks $tracks -CurrentAlbumArtist "Beethoven"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AlbumName,
        
        [Parameter(Mandatory = $true)]
        [array]$Tracks,
        
        [Parameter(Mandatory = $false)]
        [string]$CurrentAlbumArtist = ""
    )

    if (-not $Tracks -or $Tracks.Count -eq 0) {
        Write-Warning "No tracks provided for album artist builder"
        return $CurrentAlbumArtist
    }

    # Collect all unique artists from tracks
    $allArtists = @{}
    $artistOrder = @()
    
    foreach ($track in $Tracks) {
        if ($track.artists) {
            foreach ($artist in $track.artists) {
                $name = $artist.name
                if (-not $name) { continue }
                
                if (-not $allArtists.ContainsKey($name)) {
                    $allArtists[$name] = @{
                        Name = $name
                        Role = $null
                        Type = $null
                        IsComposer = $false
                        IsConductor = $false
                        IsEnsemble = $false
                    }
                    $artistOrder += $name
                    
                    # Try to determine type
                    if ($artist.PSObject.Properties['role'] -and $artist.role) {
                        $allArtists[$name].Role = $artist.role
                        if ($artist.role -match '(?i)composer|composed by') {
                            $allArtists[$name].IsComposer = $true
                        }
                        if ($artist.role -match '(?i)conductor') {
                            $allArtists[$name].IsConductor = $true
                        }
                    }
                    
                    if ($artist.PSObject.Properties['type'] -and $artist.type) {
                        $allArtists[$name].Type = $artist.type
                        if ($artist.type -match '(?i)composer') {
                            $allArtists[$name].IsComposer = $true
                        }
                    }
                    
                    if ($name -match '(?i)(orchestra|orchestre|orchester|philharmonic|philharmonique|philharmoniker|symphony|symphonie|sinfonie|ensemble|choir|chorus|quartet|trio)') {
                        $allArtists[$name].IsEnsemble = $true
                    }
                }
            }
        }
        
        # Also check for explicit composer/conductor properties
        if ($track.PSObject.Properties['composer'] -and $track.composer) {
            $composers = if ($track.composer -is [array]) { $track.composer } else { @($track.composer) }
            foreach ($comp in $composers) {
                if ($comp -and -not $allArtists.ContainsKey($comp)) {
                    $allArtists[$comp] = @{
                        Name = $comp
                        Role = 'composer'
                        IsComposer = $true
                    }
                    $artistOrder += $comp
                } elseif ($allArtists.ContainsKey($comp)) {
                    $allArtists[$comp].IsComposer = $true
                    $allArtists[$comp].Role = 'composer'
                }
            }
        }
        
        if ($track.PSObject.Properties['Conductor'] -and $track.Conductor) {
            $cond = $track.Conductor
            if ($cond -and -not $allArtists.ContainsKey($cond)) {
                $allArtists[$cond] = @{
                    Name = $cond
                    Role = 'conductor'
                    IsConductor = $true
                }
                $artistOrder += $cond
            } elseif ($allArtists.ContainsKey($cond)) {
                $allArtists[$cond].IsConductor = $true
                if (-not $allArtists[$cond].Role) {
                    $allArtists[$cond].Role = 'conductor'
                }
            }
        }
    }

    if ($artistOrder.Count -eq 0) {
        Write-Warning "No artists found in tracks"
        return $CurrentAlbumArtist
    }

    # Initialize selected artists (start with current or empty)
    $selectedArtists = @()
    if ($CurrentAlbumArtist) {
        # Try to match current album artist to available artists
        foreach ($name in $artistOrder) {
            if ($CurrentAlbumArtist -eq $name -or $CurrentAlbumArtist -like "*$name*") {
                $selectedArtists += $name
            }
        }
    }

    # Interactive loop
    $done = $false
    while (-not $done) {
        # Ensure selectedArtists is always an array (safety check)
        if ($null -eq $selectedArtists) {
            $selectedArtists = @()
        } elseif ($selectedArtists -isnot [array]) {
            $selectedArtists = @($selectedArtists)
        }
        
        if ($VerbosePreference -ne 'Continue') { Clear-Host }
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "=== ALBUM ARTIST BUILDER ===" -ForegroundColor Cyan
        Write-Host "========================================`n" -ForegroundColor Cyan
        
        Write-Host "Album: " -NoNewline -ForegroundColor Yellow
        Write-Host $AlbumName -ForegroundColor Cyan
        Write-Host ""
        
        Write-Host "Available artists:" -ForegroundColor Yellow
        for ($i = 0; $i -lt $artistOrder.Count; $i++) {
            $name = $artistOrder[$i]
            $info = $allArtists[$name]
            $isSelected = $selectedArtists -contains $name
            
            $mark = if ($isSelected) { "[✓]" } else { "[ ]" }
            $color = if ($isSelected) { 'Green' } else { 'Gray' }
            
            $label = "$mark [$($i+1)] $name"
            if ($info.Role) { $label += " ($($info.Role))" }
            elseif ($info.IsComposer) { $label += " (composer)" }
            elseif ($info.IsConductor) { $label += " (conductor)" }
            elseif ($info.IsEnsemble) { $label += " (ensemble)" }
            
            Write-Host "  $label" -ForegroundColor $color
        }
        
        Write-Host ""
        Write-Host "Current album artist: " -NoNewline -ForegroundColor Yellow
        if ($selectedArtists.Count -gt 0) {
            Write-Host ($selectedArtists -join '; ') -ForegroundColor Green
        } else {
            Write-Host "(none selected)" -ForegroundColor Red
        }
        
        Write-Host "`nCommands:" -ForegroundColor Yellow
        Write-Host "  [1-$($artistOrder.Count)]  Toggle artist selection" -ForegroundColor Gray
        Write-Host "  [a]         Select all" -ForegroundColor Gray
        Write-Host "  [c]         Clear selection" -ForegroundColor Gray
        Write-Host "  [o]         Change order" -ForegroundColor Gray
        Write-Host "  [r]         Reset to original ($CurrentAlbumArtist)" -ForegroundColor Gray
        Write-Host "  [s]         Skip/keep original" -ForegroundColor Gray
        Write-Host "  [Enter]     Accept current selection" -ForegroundColor Green
        
        Write-Host ""
        $userInput = Read-Host "Select option"
        $userInput = $userInput.Trim().ToLower()
        
        if ([string]::IsNullOrEmpty($userInput)) {
            # Accept current selection
            if ($selectedArtists.Count -eq 0) {
                Write-Host "No artists selected. Using original: $CurrentAlbumArtist" -ForegroundColor Yellow
                return $CurrentAlbumArtist
            }
            $done = $true
            break
        }
        
        switch -Regex ($userInput) {
            '^[0-9]+$' {
                $idx = [int]$userInput - 1
                if ($idx -ge 0 -and $idx -lt $artistOrder.Count) {
                    $name = $artistOrder[$idx]
                    if ($selectedArtists -contains $name) {
                        # Remove artist - ensure result is always an array
                        $selectedArtists = @($selectedArtists | Where-Object { $_ -ne $name })
                    } else {
                        # Add artist - ensure result is always an array
                        $selectedArtists = @($selectedArtists) + $name
                    }
                } else {
                    Write-Host "Invalid number. Press Enter to continue..." -ForegroundColor Red
                    Read-Host
                }
            }
            '^a$' {
                $selectedArtists = @() + $artistOrder
            }
            '^c$' {
                $selectedArtists = @()
            }
            '^o$' {
                if ($selectedArtists.Count -lt 2) {
                    Write-Host "Need at least 2 selected artists to reorder. Press Enter..." -ForegroundColor Red
                    Read-Host
                } else {
                    Write-Host "`nCurrent order:" -ForegroundColor Yellow
                    for ($i = 0; $i -lt $selectedArtists.Count; $i++) {
                        Write-Host "  $($i+1). $($selectedArtists[$i])" -ForegroundColor Cyan
                    }
                    Write-Host "`nEnter new order (comma-separated, e.g., 2,1,3):" -ForegroundColor Yellow
                    $orderInput = Read-Host
                    $newOrder = $orderInput.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
                    
                    if ($newOrder.Count -eq $selectedArtists.Count) {
                        $reordered = @()
                        $valid = $true
                        foreach ($num in $newOrder) {
                            if ($num -match '^\d+$') {
                                $idx = [int]$num - 1
                                if ($idx -ge 0 -and $idx -lt $selectedArtists.Count) {
                                    $reordered += $selectedArtists[$idx]
                                } else {
                                    $valid = $false
                                    break
                                }
                            } else {
                                $valid = $false
                                break
                            }
                        }
                        
                        if ($valid) {
                            $selectedArtists = $reordered
                        } else {
                            Write-Host "Invalid order format. Press Enter..." -ForegroundColor Red
                            Read-Host
                        }
                    } else {
                        Write-Host "Must specify all $($selectedArtists.Count) positions. Press Enter..." -ForegroundColor Red
                        Read-Host
                    }
                }
            }
            '^r$' {
                $selectedArtists = @()
                if ($CurrentAlbumArtist) {
                    foreach ($name in $artistOrder) {
                        if ($CurrentAlbumArtist -eq $name -or $CurrentAlbumArtist -like "*$name*") {
                            $selectedArtists += $name
                        }
                    }
                }
            }
            '^s$' {
                Write-Host "Keeping original album artist: $CurrentAlbumArtist" -ForegroundColor Yellow
                return $CurrentAlbumArtist
            }
            default {
                Write-Host "Invalid command. Press Enter to continue..." -ForegroundColor Red
                Read-Host
            }
        }
    }

    # Build final album artist string
    $result = $selectedArtists -join '; '
    Write-Host "`n✓ Album artist set to: $result" -ForegroundColor Green
    Start-Sleep -Milliseconds 500
    
    return $result
}

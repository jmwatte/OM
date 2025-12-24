<#
.SYNOPSIS
    Finds album folders with missing or incomplete genre tags.

.DESCRIPTION
    Scans a music library to identify album folders where audio files have missing,
    empty, or incomplete genre tags. This helps efficiently target which albums need
    genre updates, avoiding unnecessary API calls and processing.
    
    The script groups files by album folder and reports:
    - Folders where ALL files have no genres
    - Folders where SOME files have no genres (partial)
    - Optional: Folders with fewer than N genres (incomplete)

.PARAMETER Path
    Root path to scan for music albums. Can be a single album folder or entire library.

.PARAMETER IncludePartial
    Include folders where only SOME files are missing genres (not all).
    Default: Only report folders where ALL files lack genres.

.PARAMETER MinGenreCount
    Minimum number of genres required. Folders with fewer genres are reported.
    Default: 1 (any genre tag counts as having genres)

.PARAMETER ExportCsv
    Export results to CSV file for later processing.

.PARAMETER PassThru
    Return folder paths that can be piped to Start-OM for batch processing.

.EXAMPLE
    .\find-missing-genres.ps1 -Path "C:\Music"
    
    Find all album folders where ALL files have no genre tags.

.EXAMPLE
    .\find-missing-genres.ps1 -Path "C:\Music" -IncludePartial
    
    Find folders where at least one file is missing genre tags.

.EXAMPLE
    .\find-missing-genres.ps1 -Path "C:\Music" -MinGenreCount 2
    
    Find folders where files have fewer than 2 genres (want more detailed tagging).

.EXAMPLE
    .\find-missing-genres.ps1 -Path "C:\Music" -ExportCsv missing-genres.csv
    
    Export results to CSV for review.

.EXAMPLE
    .\find-missing-genres.ps1 -Path "C:\Music" -PassThru | ForEach-Object {
        Start-OM -Path $_ -UpdateGenresOnly -Auto -Provider Discogs
    }
    
    Find albums with missing genres and automatically update them from Discogs.

.NOTES
    Efficient pre-processing step before running Start-OM -UpdateGenresOnly.
    Saves API calls and time by only processing albums that need genre updates.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$Path,
    
    [switch]$IncludePartial,
    
    [int]$MinGenreCount = 1,
    
    [string]$ExportCsv,
    
    [switch]$PassThru
)

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "🔍 Finding Albums with Missing Genre Tags" -ForegroundColor Magenta
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""
Write-Host "Scanning: $Path" -ForegroundColor Cyan
Write-Host "Min genres required: $MinGenreCount" -ForegroundColor Gray
Write-Host "Include partial: $IncludePartial" -ForegroundColor Gray
Write-Host ""

# Find all audio files recursively
$audioFiles = Get-ChildItem -LiteralPath $Path -File -Recurse -ErrorAction SilentlyContinue | 
    Where-Object { $_.Extension -match '\.(mp3|flac|m4a|wav|ogg|ape|opus|wma)$' }

if ($audioFiles.Count -eq 0) {
    Write-Warning "No audio files found in $Path"
    return
}

Write-Host "Found $($audioFiles.Count) audio files. Analyzing genres..." -ForegroundColor Cyan
Write-Host ""

# Group files by parent folder (album folder)
$albumFolders = $audioFiles | Group-Object { $_.Directory.FullName }

$results = @()
$processedCount = 0
$totalAlbums = $albumFolders.Count

foreach ($albumGroup in $albumFolders) {
    $processedCount++
    $albumPath = $albumGroup.Name
    $files = $albumGroup.Group
    
    # Show progress for large libraries
    if ($totalAlbums -gt 50 -and $processedCount % 10 -eq 0) {
        $percent = [math]::Round(($processedCount / $totalAlbums) * 100)
        Write-Progress -Activity "Scanning Albums" -Status "$processedCount of $totalAlbums ($percent%)" -PercentComplete $percent
    }
    
    Write-Verbose "Checking: $albumPath"
    
    # Get tags for all files in this folder
    $filesWithoutGenres = 0
    $filesWithFewGenres = 0
    $totalFiles = $files.Count
    $genreExamples = @()
    
    foreach ($file in $files) {
        try {
            $tags = Get-OMTags -Path $file.FullName
            $genreCount = 0
            
            if ($tags.Genres) {
                # Handle both summary string and array formats
                if ($tags.Genres -is [string]) {
                    if ($tags.Genres -eq '*Empty*' -or [string]::IsNullOrWhiteSpace($tags.Genres)) {
                        $genreCount = 0
                    } else {
                        # Count comma-separated genres in summary string
                        $genreCount = ($tags.Genres -split ',' | Where-Object { $_ -and $_ -ne '*Empty*' }).Count
                    }
                } elseif ($tags.Genres -is [array]) {
                    $genreCount = $tags.Genres.Count
                } else {
                    $genreCount = 1
                }
            }
            
            if ($genreCount -eq 0) {
                $filesWithoutGenres++
            } elseif ($genreCount -lt $MinGenreCount) {
                $filesWithFewGenres++
                if ($genreExamples.Count -lt 3) {
                    $genreExamples += "$($tags.Genres)"
                }
            } else {
                if ($genreExamples.Count -lt 3) {
                    $genreExamples += "$($tags.Genres)"
                }
            }
        } catch {
            Write-Verbose "  Error reading tags from $($file.Name): $_"
            $filesWithoutGenres++
        }
    }
    
    # Determine if this album should be reported
    $shouldReport = $false
    $reason = ""
    
    if ($filesWithoutGenres -eq $totalFiles) {
        # ALL files have no genres
        $shouldReport = $true
        $reason = "All files missing genres"
    } elseif ($IncludePartial -and $filesWithoutGenres -gt 0) {
        # SOME files have no genres
        $shouldReport = $true
        $reason = "Partial: $filesWithoutGenres/$totalFiles missing"
    } elseif ($filesWithFewGenres -gt 0 -and $filesWithoutGenres -eq 0) {
        # Files have genres but fewer than minimum
        $shouldReport = $true
        $reason = "Incomplete: < $MinGenreCount genres"
    }
    
    if ($shouldReport) {
        $folderName = Split-Path $albumPath -Leaf
        $parentFolder = Split-Path $albumPath -Parent | Split-Path -Leaf
        
        $result = [PSCustomObject]@{
            Path = $albumPath
            Folder = $folderName
            Artist = $parentFolder
            TotalFiles = $totalFiles
            MissingGenres = $filesWithoutGenres
            FewGenres = $filesWithFewGenres
            Reason = $reason
            ExampleGenres = ($genreExamples | Select-Object -First 2) -join ' | '
        }
        
        $results += $result
    }
}

# Clear progress
if ($totalAlbums -gt 50) {
    Write-Progress -Activity "Scanning Albums" -Completed
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "📊 RESULTS" -ForegroundColor Magenta
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

if ($results.Count -eq 0) {
    Write-Host "✓ No albums with missing genres found!" -ForegroundColor Green
    Write-Host "  All albums have at least $MinGenreCount genre tag(s)." -ForegroundColor Gray
    return
}

Write-Host "Found $($results.Count) album(s) with missing/incomplete genres:" -ForegroundColor Yellow
Write-Host ""

# Group by reason for better display
$byReason = $results | Group-Object Reason

foreach ($group in $byReason) {
    Write-Host "$($group.Name): $($group.Count) albums" -ForegroundColor Cyan
    foreach ($album in $group.Group | Select-Object -First 5) {
        Write-Host "  📁 $($album.Artist) / $($album.Folder)" -ForegroundColor White
        Write-Host "     Files: $($album.TotalFiles) | Missing: $($album.MissingGenres)" -ForegroundColor Gray
        if ($album.ExampleGenres) {
            Write-Host "     Current: $($album.ExampleGenres)" -ForegroundColor DarkGray
        }
    }
    if ($group.Count -gt 5) {
        Write-Host "  ... and $($group.Count - 5) more" -ForegroundColor Gray
    }
    Write-Host ""
}

# Export to CSV if requested
if ($ExportCsv) {
    $results | Export-Csv -Path $ExportCsv -NoTypeInformation -Encoding UTF8
    Write-Host "✓ Exported results to: $ExportCsv" -ForegroundColor Green
    Write-Host ""
}

# Display summary with next steps
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "📝 NEXT STEPS" -ForegroundColor Magenta
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""
Write-Host "To update genres for these albums:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Preview changes (WhatIf mode):" -ForegroundColor Cyan
Write-Host "   .\find-missing-genres.ps1 -Path '$Path' -PassThru | ForEach-Object {" -ForegroundColor White
Write-Host "       Start-OM -Path `$_ -UpdateGenresOnly -Auto -Provider Discogs -WhatIf" -ForegroundColor White
Write-Host "   }" -ForegroundColor White
Write-Host ""
Write-Host "2. Update genres (for real):" -ForegroundColor Cyan
Write-Host "   .\find-missing-genres.ps1 -Path '$Path' -PassThru | ForEach-Object {" -ForegroundColor White
Write-Host "       Start-OM -Path `$_ -UpdateGenresOnly -Auto -Provider Discogs" -ForegroundColor White
Write-Host "   }" -ForegroundColor White
Write-Host ""
Write-Host "3. Interactive selection (review each album):" -ForegroundColor Cyan
Write-Host "   .\find-missing-genres.ps1 -Path '$Path' -PassThru | ForEach-Object {" -ForegroundColor White
Write-Host "       Start-OM -Path `$_ -UpdateGenresOnly -Provider Qobuz" -ForegroundColor White
Write-Host "   }" -ForegroundColor White
Write-Host ""

# PassThru mode: return paths for piping
if ($PassThru) {
    return $results | Select-Object -ExpandProperty Path
}

# Display full results table if small enough
if ($results.Count -le 50) {
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host "📋 FULL LIST" -ForegroundColor Magenta
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host ""
    $results | Format-Table Artist, Folder, TotalFiles, MissingGenres, Reason -AutoSize
}

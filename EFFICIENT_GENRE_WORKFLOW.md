# Efficient Genre Updates - Complete Workflow Guide

## Problem
Running `Start-OM -UpdateGenresOnly` on an entire library would waste:
- ❌ API calls on albums that already have genres
- ❌ Time matching albums that don't need updates
- ❌ Risk of hitting rate limits

## Solution
Use the **two-step workflow**:
1. **`find-missing-genres.ps1`** - Identify albums missing genres
2. **`Start-OM -UpdateGenresOnly`** - Update only those albums

---

## Step 1: Find Albums Missing Genres

### Basic Usage
```powershell
# Find all albums where ALL files have no genres
.\find-missing-genres.ps1 -Path "C:\Music"
```

### Advanced Options
```powershell
# Include albums where SOME files are missing genres
.\find-missing-genres.ps1 -Path "C:\Music" -IncludePartial

# Find albums with less than 2 genres (want more detailed tagging)
.\find-missing-genres.ps1 -Path "C:\Music" -MinGenreCount 2

# Export results to CSV for review
.\find-missing-genres.ps1 -Path "C:\Music" -ExportCsv "missing-genres.csv"

# Get folder paths for piping (no display)
.\find-missing-genres.ps1 -Path "C:\Music" -PassThru
```

---

## Step 2: Update Missing Genres

### Preview First (Recommended)
```powershell
# Preview what would be updated (WhatIf mode)
.\find-missing-genres.ps1 -Path "C:\Music" -PassThru | ForEach-Object {
    Start-OM -Path $_ -UpdateGenresOnly -Auto -Provider Discogs -WhatIf
}
```

### Automatic Batch Update
```powershell
# Automatically update all albums with missing genres
.\find-missing-genres.ps1 -Path "C:\Music" -PassThru | ForEach-Object {
    Start-OM -Path $_ -UpdateGenresOnly -Auto -Provider Discogs
}
```

### Interactive Review
```powershell
# Manually select album for each folder (more control)
.\find-missing-genres.ps1 -Path "C:\Music" -PassThru | ForEach-Object {
    Start-OM -Path $_ -UpdateGenresOnly -Provider Qobuz
}
```

---

## Complete Workflow Examples

### Example 1: Classical Music Collection
```powershell
# Find classical albums missing genres
.\find-missing-genres.ps1 -Path "C:\Music\Classical" -PassThru | ForEach-Object {
    Write-Host "Processing: $_" -ForegroundColor Cyan
    # Qobuz is great for classical genres
    Start-OM -Path $_ -UpdateGenresOnly -Auto -Provider Qobuz
}
```

### Example 2: Large Mixed Library
```powershell
# Step 1: Export list for review
.\find-missing-genres.ps1 -Path "C:\Music" -ExportCsv "todo.csv"

# Step 2: Review CSV, then process in batches
Import-Csv "todo.csv" | Select-Object -First 50 -ExpandProperty Path | ForEach-Object {
    Start-OM -Path $_ -UpdateGenresOnly -Auto -Provider Discogs -WhatIf
}

# Step 3: If preview looks good, run for real (remove -WhatIf)
Import-Csv "todo.csv" | Select-Object -First 50 -ExpandProperty Path | ForEach-Object {
    Start-OM -Path $_ -UpdateGenresOnly -Auto -Provider Discogs
}
```

### Example 3: Genre Enhancement (Merge Mode)
```powershell
# Find albums with fewer than 3 genres
.\find-missing-genres.ps1 -Path "C:\Music\Electronic" -MinGenreCount 3 -PassThru | ForEach-Object {
    # Merge new genres with existing (keeps both)
    Start-OM -Path $_ -UpdateGenresOnly -GenreMode Merge -Auto -Provider Discogs
}
```

### Example 4: Multi-Provider Strategy
```powershell
# Get list of folders
$folders = .\find-missing-genres.ps1 -Path "C:\Music\Jazz" -PassThru

# First pass: Qobuz (high quality metadata)
$folders | ForEach-Object {
    Start-OM -Path $_ -UpdateGenresOnly -Auto -Provider Qobuz
}

# Second pass: Merge Discogs genres for more detail
$folders | ForEach-Object {
    Start-OM -Path $_ -UpdateGenresOnly -GenreMode Merge -Auto -Provider Discogs
}
```

---

## Efficiency Comparison

### ❌ Inefficient Approach
```powershell
# Processes ALL albums (1000+ API calls)
Get-ChildItem "C:\Music" -Directory | ForEach-Object {
    Start-OM -Path $_.FullName -UpdateGenresOnly -Auto -Provider Discogs
}
```

### ✅ Efficient Approach
```powershell
# Only processes albums missing genres (maybe 50-100 API calls)
.\find-missing-genres.ps1 -Path "C:\Music" -PassThru | ForEach-Object {
    Start-OM -Path $_ -UpdateGenresOnly -Auto -Provider Discogs
}
```

---

## Tips & Best Practices

### 1. Always Preview First
```powershell
# Add -WhatIf to any Start-OM command to preview
Start-OM -Path $folder -UpdateGenresOnly -Auto -Provider Discogs -WhatIf
```

### 2. Process in Batches for Large Libraries
```powershell
$missing = .\find-missing-genres.ps1 -Path "C:\Music" -PassThru

# Process first 25 albums
$missing | Select-Object -First 25 | ForEach-Object {
    Start-OM -Path $_ -UpdateGenresOnly -Auto -Provider Discogs
}

# Process next 25 albums
$missing | Select-Object -Skip 25 -First 25 | ForEach-Object {
    Start-OM -Path $_ -UpdateGenresOnly -Auto -Provider Discogs
}
```

### 3. Handle Errors Gracefully
```powershell
.\find-missing-genres.ps1 -Path "C:\Music" -PassThru | ForEach-Object {
    try {
        Start-OM -Path $_ -UpdateGenresOnly -Auto -Provider Discogs -ErrorAction Stop
        Write-Host "✓ Updated: $_" -ForegroundColor Green
    } catch {
        Write-Warning "Failed: $_ - $($_.Exception.Message)"
        # Log failures to file
        $_ | Out-File "failed-albums.txt" -Append
    }
}
```

### 4. Monitor Progress for Large Collections
```powershell
$folders = .\find-missing-genres.ps1 -Path "C:\Music" -PassThru
$total = $folders.Count
$current = 0

$folders | ForEach-Object {
    $current++
    Write-Host "[$current/$total] Processing: $_" -ForegroundColor Cyan
    Start-OM -Path $_ -UpdateGenresOnly -Auto -Provider Discogs
}
```

### 5. Verify Results
```powershell
# Before
$before = .\find-missing-genres.ps1 -Path "C:\Music" -PassThru
Write-Host "Albums missing genres: $($before.Count)"

# ... run updates ...

# After
$after = .\find-missing-genres.ps1 -Path "C:\Music" -PassThru
Write-Host "Albums still missing genres: $($after.Count)"
Write-Host "Updated: $($before.Count - $after.Count) albums"
```

---

## Troubleshooting

### No albums found by find-missing-genres
✅ **Good!** All your albums already have genre tags

### Too many albums found
- Use `-MinGenreCount 2` or higher if you want more detailed genres
- Use `-IncludePartial` if you want to find albums where only some files are missing

### Start-OM can't find matches
- Try different provider (`-Provider Qobuz` or `-Provider Spotify`)
- Folder names might not match provider data - use interactive mode
- Lower `-AutoConfidenceThreshold 0.60` for more lenient matching

### Rate limiting from provider
- Process in smaller batches (25-50 albums at a time)
- Add delays: `Start-Sleep -Seconds 2` between calls
- Spread across multiple sessions/days

---

## Summary

**Cost-Effective Workflow:**
1. ✅ `find-missing-genres.ps1` - Identify targets (fast, no API calls)
2. ✅ `Start-OM -UpdateGenresOnly -WhatIf` - Preview changes (API calls, but safe)
3. ✅ `Start-OM -UpdateGenresOnly` - Apply updates (only to needed albums)

**Result:** Only process what needs updating, saving time and API quota!

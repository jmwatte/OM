# UpdateGenresOnly Feature - Quick Reference

## Overview
The new `-UpdateGenresOnly` feature in Start-OM allows you to update ONLY genre tags across your music library without touching any other metadata (Title, Artist, Album, Track numbers, etc.).

## Key Features
✅ Updates only genre tags - all other tags remain unchanged
✅ Works with all providers (Spotify, Qobuz, Discogs, MusicBrainz)
✅ Two modes: Replace or Merge genres
✅ Supports batch processing with `-Auto` flag
✅ Supports `-WhatIf` for safe preview
✅ Uses Quick Find mode for fast album matching

## Parameters

### -UpdateGenresOnly
When specified, only genre tags are updated from the matched album.

### -GenreMode
Controls how genres are updated:
- **Replace** (default): Replaces all existing genres with provider genres
- **Merge**: Adds provider genres to existing genres (deduplicates)

## Usage Examples

### 1. Interactive Mode - Single Album
```powershell
# Replace genres with Qobuz genres (interactive album selection)
Start-OM -Path "C:\Music\Artist\Album" -UpdateGenresOnly -Provider Qobuz

# Add Discogs genres to existing genres (merge)
Start-OM -Path "C:\Music\Artist\Album" -UpdateGenresOnly -GenreMode Merge -Provider Discogs
```

### 2. Auto Mode - Batch Processing
```powershell
# Automatically update genres for all albums in an artist folder
Start-OM -Path "C:\Music\Artist" -UpdateGenresOnly -Auto -Provider Discogs

# Merge genres across entire collection
Start-OM -Path "C:\Music" -UpdateGenresOnly -GenreMode Merge -Auto -Provider Qobuz
```

### 3. Preview Mode (WhatIf)
```powershell
# Preview what genres would be updated without making changes
Start-OM -Path "C:\Music\Artist" -UpdateGenresOnly -Auto -Provider Discogs -WhatIf
```

### 4. Use Case: Missing Genres
```powershell
# Find albums with missing genres and update them
Get-ChildItem -Path "C:\Music" -Directory -Recurse | ForEach-Object {
    $tags = Get-OMTags -Path $_.FullName
    if (-not $tags.Genres -or $tags.Genres -eq '*Empty*') {
        Write-Host "Updating missing genres: $($_.FullName)" -ForegroundColor Yellow
        Start-OM -Path $_.FullName -UpdateGenresOnly -Auto -Provider Discogs
    }
}
```

## Workflow

1. **Album Detection**: Uses folder structure to auto-detect artist and album
2. **Quick Find**: Searches provider for matching album (skips artist stage)
3. **Genre Extraction**: Fetches genre information from matched release
4. **Tag Update**: Updates only genre tags on all audio files
5. **Next Album**: Automatically moves to next album (in Auto mode)

## Provider-Specific Notes

### Spotify
- Provides genres from artist profile
- Usually broader genre categories

### Qobuz
- Provides genre from album/release
- Often more specific classical sub-genres

### Discogs
- Provides both genres and styles
- Combines both for comprehensive tagging
- Great for niche/underground music

### MusicBrainz
- Provides genre from release
- Community-driven, variable quality

## Tips

1. **Start with WhatIf**: Always test with `-WhatIf` first on a subset of albums
2. **Choose Provider Wisely**: Discogs often has the most detailed genres for diverse collections
3. **Merge vs Replace**: Use Merge to combine genres from multiple sources; use Replace for clean slate
4. **Batch Processing**: Use `-Auto` for large collections, but verify accuracy on a few albums first
5. **Combine with Existing Workflow**: Can be run independently of full tagging workflow

## Example Scenarios

### Scenario 1: Classical Collection - Add Genre Metadata
```powershell
# Classical music often lacks genre tags
Start-OM -Path "C:\Music\Classical" -UpdateGenresOnly -Provider Qobuz -Auto
```

### Scenario 2: Electronic Music - Detailed Sub-genres
```powershell
# Discogs excels at electronic music sub-genres
Start-OM -Path "C:\Music\Electronic" -UpdateGenresOnly -Provider Discogs -GenreMode Merge -Auto
```

### Scenario 3: Mixed Collection - Multi-source Genres
```powershell
# First pass: Qobuz
Start-OM -Path "C:\Music\Various" -UpdateGenresOnly -Provider Qobuz -Auto

# Second pass: Merge Discogs genres
Start-OM -Path "C:\Music\Various" -UpdateGenresOnly -GenreMode Merge -Provider Discogs -Auto
```

## Troubleshooting

**Problem**: No genres found for album
**Solution**: Try different provider or enter genres manually when prompted

**Problem**: Albums not matching automatically in Auto mode
**Solution**: Lower `-AutoConfidenceThreshold` or run interactively first to verify folder structure

**Problem**: Genres not merging correctly
**Solution**: Check if files have genres in different formats (split by semicolons vs commas)

## Related Functions

- `Get-OMTags`: Read current tags including genres
- `Set-OMTags`: Manually set genre tags
- `Format-Genres`: Normalize genre formatting
- `Export-OMGenres/Import-OMGenres`: Manage genre lists

## Future Enhancements (Potential)

- Filter to only update albums with missing genres
- Genre validation against predefined lists
- Multi-provider genre merging in single pass
- Genre cleanup/normalization after update

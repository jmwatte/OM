# Album Artist Fix - Quick Album Search Mode

## Problem Description

When using Quick Album Search mode with a folder structure like:
```
d:\fakename\ManyAlbum-Artist\audiofiles
```

Running `Start-OM` on the "fakename" folder would:
1. Auto-detect artist from parent folder name ("fakename")
2. Search for albums
3. **Bug**: When saving tags, it would use the folder name ("fakename") as the album artist instead of the actual artist from the provider metadata

This resulted in tags like:
```powershell
Genres       : Blues
Artists      : Billy Stapleton, The Mark Dufresne Band
Year         : 1999
AlbumArtists : artists    # <-- Wrong! Should be from provider
Album        : Have Another Round
```

## Root Cause

In Quick Album Search mode ([Start-OM.ps1](Public/Start-OM.ps1) around line 965-985), when an album was selected, the code created a `$ProviderArtist` object using `$quickArtist`:

```powershell
# OLD CODE (BUGGY)
$ProviderArtist = @{ name = $quickArtist; id = $quickArtist }
```

The problem: `$quickArtist` was set from the parent folder name ("fakename" or "artists"), not from the selected album's metadata.

This `$ProviderArtist.name` was then passed to `Get-Tags`, which used it as the album artist value.

## Fix Applied

The fix extracts the artist name from the selected album's metadata instead of using the folder name:

```powershell
# NEW CODE (FIXED)
# Extract artist name from album metadata (not folder name)
$artistNameFromAlbum = $null
if ($value = Get-IfExists $ProviderAlbum 'artists') {
    # Spotify/MusicBrainz: artists array
    if ($value -is [array] -and $value.Count -gt 0) {
        $artistNameFromAlbum = if ($value[0].name) { $value[0].name } else { $value[0].ToString() }
    } elseif ($value.name) {
        $artistNameFromAlbum = $value.name
    } else {
        $artistNameFromAlbum = $value.ToString()
    }
} elseif ($value = Get-IfExists $ProviderAlbum 'artist') {
    # Qobuz/Discogs: artist string
    $artistNameFromAlbum = $value
}

# Fallback to folder name only if album has no artist metadata
if (-not $artistNameFromAlbum) {
    $artistNameFromAlbum = $quickArtist
    Write-Verbose "No artist in album metadata, using folder name: $artistNameFromAlbum"
} else {
    Write-Verbose "Extracted artist from album metadata: $artistNameFromAlbum"
}

# Use the extracted artist name
$ProviderArtist = @{ name = $artistNameFromAlbum; id = $artistNameFromAlbum }
```

### What Changed

1. **Extracts artist from album metadata** based on provider format:
   - **Spotify/MusicBrainz**: `ProviderAlbum.artists[0].name`
   - **Qobuz/Discogs**: `ProviderAlbum.artist`

2. **Only falls back to folder name** if the album has no artist metadata (rare case)

3. **All providers supported**: Works with Spotify, Qobuz, Discogs, and MusicBrainz

## Verification

### Before Fix
```powershell
AlbumArtists : artists  # Wrong - folder name
```

### After Fix
```powershell
AlbumArtists : Billy Stapleton, The Mark Dufresne Band  # Correct - from provider
```

### Test Steps

1. Create a test folder structure:
   ```
   d:\test-folder\Artist Name\Album Name
   ```

2. Run Start-OM on "test-folder":
   ```powershell
   Start-OM -Path "d:\test-folder"
   ```

3. Use Quick Album Search mode (default)

4. Select an album

5. Save tags with `st` or `sa`

6. Verify the AlbumArtists tag matches the provider's artist, not "test-folder"

## Technical Details

### Affected Code
- **File**: [Public/Start-OM.ps1](Public/Start-OM.ps1)
- **Lines**: ~965-1010 (Quick Album Search album selection)
- **Function**: Album selection in Quick Album Search mode

### Not Affected
- **Artist-First mode**: Was already working correctly (uses artist from search results)
- **Direct ArtistId/AlbumId parameters**: Already working correctly

### Provider-Specific Handling

Different providers return album data in different formats:

| Provider     | Artist Location           | Format              |
|--------------|---------------------------|---------------------|
| Spotify      | `album.artists[0].name`   | Array of objects    |
| Qobuz        | `album.artist`            | String              |
| Discogs      | `album.artist`            | String              |
| MusicBrainz  | `album.artists[0].name`   | Array of objects    |

The fix handles all formats using `Get-IfExists` and type checking.

## Related Issues

This fix also ensures consistency when:
- Using the `aa` (Album Artist Builder) command
- Switching between providers
- Processing multiple albums in a batch

## Migration Notes

No migration needed - this is a bug fix that makes the behavior match user expectations. Existing albums may need to be re-tagged if they were processed with the old code.

To re-tag existing albums:
```powershell
Start-OM -Path "d:\music\artist-folder"
# Select album, then save tags again
```

## Changelog

- **Fixed**: Quick Album Search now uses artist from provider metadata, not folder name
- **Added**: Verbose logging to show where artist name comes from
- **Improved**: Handles all provider formats (Spotify, Qobuz, Discogs, MusicBrainz)

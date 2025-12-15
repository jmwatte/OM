# Genre Management Enhancement Proposal

## Current State

**Existing Save Options:**
- `SA` - Save All (tags + folder names)
- `ST` - Save Tags only
- `SF` - Save Folder Names only

**Current Behavior:**
- Genres are **replaced** entirely when saving tags
- No way to accumulate genres from multiple providers
- No way to selectively edit specific tag fields

## Proposed Enhancement

### Option 1: Genre Mode Toggle (Simplest & Recommended)

Add a **Genre Mode** toggle that controls how genres are saved:

**New Commands:**
- `gm` - Toggle Genre Mode between **Replace** (default) and **Merge**
  - **Replace Mode**: Current behavior - completely replace existing genres
  - **Merge Mode**: Combine new genres with existing ones (deduplicated)

**Display in Options:**
```
Options: ... (gm)GenreMode:Replace/Merge ...
```

**Workflow Example:**
```powershell
# 1. Start with Spotify to get basic metadata
Start-OM -Path "Album" -Provider Spotify
# Save tags (genres: "rock, indie rock")
> st

# 2. Switch to MusicBrainz for detailed genres
> pm  # Switch to MusicBrainz
# Album now shows genres: "alternative rock, indie pop, jangle pop"

> gm  # Toggle to Merge mode
> st  # Save tags
# Result: Genres now has BOTH: "rock, indie rock, alternative rock, indie pop, jangle pop"

# 3. Switch to Discogs for broader categories
> pd  # Switch to Discogs
# Album shows genres: "Rock, Pop"

> st  # Save with merge
# Result: "rock, indie rock, alternative rock, indie pop, jangle pop, Rock, Pop"
```

**Implementation Complexity:** ⭐⭐ (Low-Medium)
- Add `$script:genreMode = 'Replace'` variable
- Add toggle command in switch statement
- Modify `Save-TagsForFile` to accept merge parameter
- Update genre saving logic to merge arrays

---

### Option 2: Selective Tag Saving (More Flexible)

Add ability to specify which tags to save:

**New Commands:**
- `st` alone - Save all tags (current behavior)
- `st:g` - Save genres only
- `st:a` - Save artist/album artist only
- `st:c` - Save composer only
- `st:g,a` - Save genres and artist
- `st:!g` - Save all EXCEPT genres

**Workflow Example:**
```powershell
# Collect from multiple providers
> ps  # Spotify first
> st:!g  # Save everything except genres

> pm  # MusicBrainz
> st:g  # Save only genres (merge with existing)

> pq  # Qobuz
> st:c  # Save only composer info
```

**Implementation Complexity:** ⭐⭐⭐⭐ (Medium-High)
- Parse command arguments (`st:g,a`)
- Create selective tag filtering in `Get-Tags`
- Modify `Save-TagsForFile` to accept tag filter
- Handle both include and exclude patterns

---

### Option 3: Pre-Save Tag Editor (Most Powerful)

Add interactive tag review/edit before saving:

**New Commands:**
- `review` or `edit` - Open tag editor before save
- Shows current vs. new tags side-by-side
- Allow field-by-field accept/reject/edit

**Workflow:**
```
> review

Current Tags          →  New Tags
───────────────────────────────────────────
Genres: rock          →  rock, indie pop
Artist: The Beatles   →  The Beatles
Composer: [empty]     →  Lennon-McCartney

Actions: [a]ccept all, [r]eject all, [e]dit
Select fields to update (g,a,c) or (a)ll: g,c
```

**Implementation Complexity:** ⭐⭐⭐⭐⭐ (High)
- Create new interactive UI
- Field-by-field comparison logic
- Manual editing capabilities
- Integration with save workflow

---

### Option 4: Multi-Provider Workflow (Advanced)

Add ability to queue multiple providers and merge their data:

**New Commands:**
- `collect` - Start multi-provider collection mode
- `ps` / `pm` / `pd` - Add provider results to collection
- `merge` - Merge all collected data
- `save` - Save merged results

**Workflow:**
```powershell
> collect  # Start collection
> ps  # Add Spotify data
✓ Collected from Spotify
> pm  # Add MusicBrainz data
✓ Collected from MusicBrainz
> merge  # Show merge preview
Genres: spotify(rock, indie) + musicbrainz(alternative rock, jangle pop)
> save  # Save merged data
```

**Implementation Complexity:** ⭐⭐⭐⭐⭐⭐ (Very High)
- Collection state management
- Cross-provider merging logic
- Conflict resolution UI

---

## Recommendation: Start with Option 1

**Why Option 1 (Genre Mode Toggle)?**

✅ **Simple to implement** - Minimal code changes
✅ **Simple to use** - One toggle command
✅ **Solves the core problem** - Accumulate genres from multiple providers
✅ **Non-breaking** - Default behavior stays the same
✅ **Extensible** - Can expand to other fields later

**Implementation Steps:**

1. Add script-level variable for genre mode
2. Add `gm` command to toggle mode
3. Update UI to show current mode
4. Modify `Save-TagsForFile` to merge genres when in Merge mode
5. Test with multiple providers

**Future Enhancements:**
- Expand to other fields (Merge modes for composers, artists, etc.)
- Add genre deduplication and normalization
- Add manual genre editing command

---

## Alternative: Genre-Specific Commands

If you want genre-specific control without affecting other workflows:

**New Commands:**
- `ag` - Add/Append genres (merge with existing)
- `rg` - Replace genres (current behavior)
- `cg` - Clear genres

**Workflow:**
```
> ps  # Spotify
> st  # Save all tags including genres

> pm  # MusicBrainz - different genres
> ag  # Append these genres to existing
> st  # Save other tags normally
```

This keeps genre management separate from general saving but still simple.

---

## Technical Notes

### Current Genre Saving (Save-TagsForFile.ps1, line 50-57)
```powershell
'Genres' {
    # Currently REPLACES genres (don't append)
    if ($v -is [array]) {
        $tagFile.Tag.Genres = $v
    } elseif ($v -is [string] -and $v -match ';') {
        $tagFile.Tag.Genres = $v -split '\s*;\s*'
    } else {
        $tagFile.Tag.Genres = @($v)
    }
}
```

### Proposed Merge Logic
```powershell
'Genres' {
    if ($GenreMergeMode) {
        # Read existing genres first
        $existing = @($tagFile.Tag.Genres)
        
        # Parse new genres
        $new = if ($v -is [array]) { $v }
               elseif ($v -is [string] -and $v -match ';') { $v -split '\s*;\s*' }
               else { @($v) }
        
        # Merge and deduplicate (case-insensitive)
        $merged = @($existing + $new | 
            Sort-Object -Unique -Property { $_.ToLowerInvariant() })
        
        $tagFile.Tag.Genres = $merged
    }
    else {
        # Replace (current behavior)
        # ... existing code ...
    }
}
```

---

## Questions to Consider

1. **Should merged genres be sorted?** (alphabetically, by provider, by frequency?)
2. **Should there be genre normalization?** (e.g., "Rock" vs "rock" vs "ROCK")
3. **Should there be a genre limit?** (some tags support only X genres)
4. **Should there be genre deduplication logic?** ("indie rock" vs "indie-rock")
5. **Should manual genre editing be supported?** (interactive genre picker)

Let me know which approach you prefer, and I can implement it!

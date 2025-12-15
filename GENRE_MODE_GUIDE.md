# Genre Mode Toggle - Quick Guide

## Feature Overview

The Genre Mode Toggle allows you to **accumulate genres from multiple providers** instead of overwriting them each time you save tags.

## Usage

### Command
- **`gm`** - Toggle between Replace and Merge modes

### Modes

**Replace Mode (Default)**
- Completely replaces existing genres with new ones
- Use when you want fresh genre data from a single provider

**Merge Mode**
- Combines existing genres with new ones
- Automatically deduplicates (case-insensitive)
- Use when collecting genres from multiple providers

### Status Display

The options line shows current mode:
```
(gm)GenreMode:Replace    # Default - overwrites genres
(gm)GenreMode:Merge      # Combines genres from multiple sources
```

## Example Workflows

### Workflow 1: Collect from Multiple Providers

```powershell
# Start with Spotify
Start-OM -Path "C:\Music\Album" -Provider Spotify

# In Stage C (track matching):
> st              # Save with Spotify genres: "rock, indie rock"

# Switch to MusicBrainz for more detailed genres
> pm              # Switch provider to MusicBrainz
> gm              # Toggle to Merge mode
> st              # Genres now: "rock, indie rock, alternative rock, jangle pop"

# Add Discogs broad categories
> pd              # Switch to Discogs
> st              # Genres now: "rock, indie rock, alternative rock, jangle pop, Rock, Pop"
```

### Workflow 2: Replace Then Merge

```powershell
# Start fresh
Start-OM -Path "Album" -Provider Qobuz

> st              # Save Qobuz data (Replace mode)
> pm              # MusicBrainz
> gm              # Toggle to Merge
> st              # Add MusicBrainz genres to Qobuz genres
```

### Workflow 3: Clean Up and Replace

```powershell
# You have accumulated too many genres, start fresh
> gm              # Make sure you're in Replace mode (toggle if needed)
> ps              # Switch to Spotify
> st              # Replace all genres with Spotify's simpler genre set
```

## Technical Details

### Deduplication
- Genres are compared case-insensitively
- "Rock", "rock", and "ROCK" are treated as the same
- First occurrence is kept (preserves capitalization from first provider)

### Genre Sources by Provider
- **Spotify**: Artist-level genres (broad categories)
- **Qobuz**: Album-level genres (Classical categories)
- **Discogs**: Album-level genres (very broad: Rock, Pop, Electronic, etc.)
- **MusicBrainz**: Album-level genres (detailed tags: "jangle pop", "merseybeat", etc.)

### Merge Logic Example

**Starting genres:** `rock, indie rock` (from Spotify)

**Toggle to Merge, add MusicBrainz:** `alternative rock, indie pop`

**Result:** `rock, indie rock, alternative rock, indie pop`

**Add Discogs:** `Rock, Pop`

**Result:** `rock, indie rock, alternative rock, indie pop, Pop`
- Note: "Rock" from Discogs was deduplicated because "rock" already exists
- "Pop" is added because it's unique

## Tips

1. **Start with Spotify or Qobuz** for basic metadata in Replace mode
2. **Toggle to Merge** before adding MusicBrainz or Discogs genres
3. **Use Replace mode** when you want to clean up accumulated genres
4. **Genres persist** across provider switches - they're in your files
5. The mode **stays active** until you toggle it again

## Verification

After saving tags, you can verify genres are merged by:
1. Looking at the track display (shows current file genres)
2. Using the verbose mode (`v` command) to see detailed tag info

## Keyboard Shortcuts

- `gm` - Toggle Genre Mode
- `st` - Save Tags only
- `sa` - Save All (tags + folders)
- `v` - Toggle verbose display (shows genres)
- `pm` / `ps` / `pd` / `pq` - Switch providers

## Default Behavior

- Genre Mode defaults to **Replace** at the start of each album
- This preserves existing behavior - you must explicitly toggle to Merge

Enjoy collecting comprehensive genre metadata from multiple sources!

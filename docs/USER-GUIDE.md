# OM User Guide

OM is a PowerShell module for organizing and tagging your music library using metadata from Spotify, Qobuz, Discogs, and MusicBrainz.

## Table of Contents

- [Quick Start](#quick-start)
- [Search Modes](#search-modes)
- [The Interactive Workflow](#the-interactive-workflow)
  - [Stage A: Artist Selection](#stage-a-artist-selection)
  - [Stage B: Album Selection](#stage-b-album-selection)
  - [Stage C: Track Matching & Tagging](#stage-c-track-matching--tagging)
- [Auto Mode (Batch Processing)](#auto-mode-batch-processing)
- [Selective Updates](#selective-updates)
- [Cover Art](#cover-art)
- [Genre Management](#genre-management)
- [Other Commands](#other-commands)
- [Command Reference](#command-reference)
- [Configuration](#configuration)
- [Tips & Tricks](#tips--tricks)

---

## Quick Start

```powershell
# Import the module
Import-Module OM

# Process a single album interactively
Start-OM -Path "C:\Music\Artist\2024 - Album Name"

# Process all albums under an artist folder
Start-OM -Path "C:\Music\Artist"

# Shorter using the alias
SOM -Path "C:\Music\Artist"
```

The module detects whether the path is a single album (contains audio files) or an artist folder (contains album subfolders) and adjusts accordingly.

**Supported audio formats:** MP3, FLAC, M4A, OGG, WAV, WMA, APE

---

## Search Modes

OM has two search modes, toggled with the `f` command at any prompt:

### Quick Album Search (default)

Searches for an album directly using artist + album name derived from folder structure. Fastest way to find a match.

```
📁 Auto-detected from folder structure: Artist='Pink Floyd', Album='The Wall'
Searching for 'The Wall' by 'Pink Floyd'...
```

If the auto-detected names are wrong, use `ni` (New Item) to enter correct artist and album, or `b` to go back and re-enter.

### Artist-First Search

Traditional workflow: first find the artist, then browse their discography. Better when folder names are inaccurate or you want to explore an artist's catalog.

```
Spotify Artist candidates for 'Pink Floyd':
[1] Pink Floyd - Progressive Rock, Art Rock (id: 0k17h0D3J5VfsdmQ1iZtE9)
[2] Pink Floyd Tribute - Tribute (id: ...)
```

---

## The Interactive Workflow

### Stage A: Artist Selection

*Only used in artist-first mode. Quick Album Search skips directly to album results.*

The module searches for the artist and shows candidates. Select by number, or use commands to refine:

| Command | Action |
|---------|--------|
| `1-N` / Enter | Select artist (Enter = first) |
| `p` | Show current provider |
| `ps` / `pq` / `pd` / `pm` | Switch to Spotify / Qobuz / Discogs / MusicBrainz |
| `f` | Toggle search mode (quick ↔ artist-first) |
| `id:<id>` | Select artist by provider ID |
| `al:<name>` | Change album name for search |
| `x` | Skip this album |
| `?` | Show all available commands |
| *(text)* | Search with new artist name |

### Stage B: Album Selection

Shows the artist's albums sorted by how closely they match your folder name. Select one to proceed to track matching.

| Command | Action |
|---------|--------|
| `1-N` / Enter | Select album (Enter = first) |
| `b` | Back to artist selection |
| `n` / `pr` | Next / Previous page |
| `p` | Show current provider |
| `ps` / `pq` / `pd` / `pm` | Switch provider |
| `f` | Toggle search mode |
| `ni` | New Item — enter new artist + album |
| `id:<id>` | Select album by provider ID |
| `cv` / `cvo` / `cs` / `ct` | Cover art: view / original / save / embed in tags |
| `*` | Select all albums (multi-disc combine) |
| `x` | Skip this album |
| `?` | Show all available commands |
| *(text)* | Search with new term |

### Stage C: Track Matching & Tagging

Displays a side-by-side comparison of your local files and the provider's tracks. Tracks are automatically paired using various sorting algorithms.

```
 # | Local File                  | Provider Track               | Confidence
---|-----------------------------|------------------------------|----------
 1 | 01 - Comfortably Numb.flac  | Comfortably Numb             | 95%
 2 | 02 - Hey You.flac           | Hey You                      | 92%
 3 | 03 - Another Brick...flac   | Another Brick in the Wall... | 88%
```

#### Sorting & Matching

| Command | Sort Method |
|---------|-------------|
| `o` | By order (track listing) |
| `d` | By duration similarity |
| `t` | By track number |
| `n` | By name similarity |
| `l` | By title (local file names) |
| `h` | Hybrid (combines multiple heuristics) |
| `m` | Manual — select matches one by one |
| `r` | Reverse source/target columns |
| `rm` | Review marked (low-confidence) tracks |

#### Saving

| Command | Action |
|---------|--------|
| `sa` | **Save All** — tags + cover art + rename folder |
| `st` | Save tags for all tracks |
| `st 1-5,8` | Save tags for specific tracks only |
| `sf` | Save folder names only (rename without tagging) |

#### Other Stage C Commands

| Command | Action |
|---------|--------|
| `cv` / `cvo` / `cs` / `ct` | Cover art: view / view original / save to folder / embed in tags |
| `aa` | Build custom album artist (useful for classical/compilations) |
| `gm` | Toggle genre mode: Replace ↔ Merge |
| `w` | Toggle WhatIf mode (dry run) |
| `v` | Toggle verbose output |
| `b` | Back to album selection |
| `pr` | Previous (back, preserves quick-find context) |
| `p` | Show current provider |
| `ps` / `pq` / `pd` / `pm` | Switch provider |
| `f` | Toggle search mode |
| `x` | Skip this album |
| `?` | Show all available commands |

---

## Auto Mode (Batch Processing)

Process many albums automatically without interaction:

```powershell
# Basic auto mode
Start-OM -Path "C:\Music\Artist" -Auto

# With provider fallback (tries Qobuz → Spotify → Discogs → MusicBrainz)
Start-OM -Path "C:\Music\Artist" -Auto -AutoFallback

# Auto with cover art
Start-OM -Path "C:\Music\Artist" -Auto -AutoFallback -AutoSaveCover

# Conservative: require 90% match confidence
Start-OM -Path "C:\Music\Artist" -Auto -AutoConfidenceThreshold 0.90

# Fall back to interactive for unmatched albums instead of skipping
Start-OM -Path "C:\Music\Artist" -Auto -AutoFallback -AutoWait

# Preview what auto mode would do (no changes)
Start-OM -Path "C:\Music\Artist" -Auto -AutoFallback -WhatIf
```

### Auto Mode Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-Auto` | — | Enable automatic selection and processing |
| `-AutoConfidenceThreshold` | 0.70 | Minimum match score (0.5 – 1.0) |
| `-AutoFallback` | — | Try other providers if primary fails |
| `-AutoWait` | — | Drop to interactive instead of skipping unmatched |
| `-AutoSaveCover` | — | Download cover art automatically |

---

## Selective Updates

Use `-UpdateOnly` to update specific metadata fields without touching others:

```powershell
# Update only genres from Discogs (best genre source)
Start-OM -Path "C:\Music\Artist" -UpdateOnly Genres -Provider Discogs -Auto

# Merge genres (add provider genres to existing, no duplicates)
Start-OM -Path "C:\Music\Artist" -UpdateOnly Genres -GenreMode Merge -Auto

# Collect genres from ALL providers (Spotify, Qobuz, Discogs, MusicBrainz) and merge
Start-OM -Path "C:\Music\Artist" -UpdateOnly AllGenres -Auto

# Collect all-provider genres and also download cover art
Start-OM -Path "C:\Music\Artist" -UpdateOnly AllGenres,CoverArt -Auto

# Only download cover art (no tag changes)
Start-OM -Path "C:\Music\Artist" -UpdateOnly CoverArt -Auto -AutoFallback

# Update genres + year + cover art (preserve everything else)
Start-OM -Path "C:\Music\Artist" -UpdateOnly Genres,Year,CoverArt -Auto

# Update performer/composer credits from Qobuz (best for classical)
Start-OM -Path "C:\Music\Classical" -UpdateOnly Artists,Composers -Provider Qobuz

# Generate mismatch reports (no changes, just JSON reports of missing tracks)
Start-OM -Path "C:\Music\Artist" -UpdateOnly MissingTracks -Auto -AutoFallback
```

### Available Update Targets

| Value | What It Updates |
|-------|-----------------|
| `All` | Everything (default) |
| `Genres` | Genre tags from current provider only |
| `AllGenres` | Collect and merge genres from ALL providers |
| `Year` | Release year only |
| `AlbumArtist` | Album artist field |
| `Artists` | Track-level performer/artist |
| `TrackInfo` | Track title, number, disc number |
| `Album` | Album name |
| `CoverArt` | Download cover art (no tag changes) |
| `Composers` | Composer fields |
| `MissingTracks` | Generate JSON report of mismatches (no changes) |

---

## Cover Art

### During Start-OM

Use cover art commands at album selection (Stage B) or track matching (Stage C):

- `cv` or `cv3` — View cover art (optionally for album #3)
- `cvo` — View original (full resolution)
- `cs` — Save cover art to album folder as `cover.jpg`
- `ct` — Embed cover art into audio file tags

### Standalone

```powershell
# Save cover art for albums missing artwork
Save-OMCoverArt -Path "C:\Music\Artist\Album" -Provider Qobuz

# Force overwrite existing artwork
Save-OMCoverArt -Path "C:\Music\Artist\Album" -Force

# Resize to max 800px
Save-OMCoverArt -Path "C:\Music\Artist\Album" -MaxSize 800
```

### Moving Albums with Cover Art

```powershell
# Process and move organized albums to a target folder
Start-OM -Path "C:\Music\Unsorted" -TargetFolder "C:\Music\Organized"
```

Albums are moved into the structure: `TargetFolder\AlbumArtist\Year - Album\`.

---

## Genre Management

### Genre Modes

| Mode | Behavior |
|------|----------|
| **Replace** (default) | Overwrite existing genres with provider genres |
| **Merge** | Add provider genres to existing genres (deduplicated) |

Toggle during interactive use with `gm` in Stage C, or set via parameter:

```powershell
Start-OM -Path "C:\Music\Artist" -GenreMode Merge
```

### Format-Genres (Whitelist Validation)

Standardize genres across your library using a configurable whitelist:

```powershell
# Interactive: approve/reject each genre
Get-OMTags "C:\Music\Album" -Details | Format-Genres -PassThru | Set-OMTags

# Batch: decide once per unique unmapped genre
GOT "C:\Music\Album" -Details | FOG -Mode Batch -PassThru | SOT

# Auto: only apply existing mappings (no prompts)
GOT "C:\Music\Album" -Details | FOG -Mode Auto -PassThru | SOT

# Review: preview changes without modifying config
GOT "C:\Music\Album" -Details | FOG -Mode Review
```

### Export / Import Genre Config

```powershell
# Backup genre configuration
Export-OMGenres -Path "C:\Backup\genres.json"

# Restore (replaces current)
Import-OMGenres -Path "C:\Backup\genres.json"

# Merge with existing
Import-OMGenres -Path "C:\Backup\genres.json" -Merge
```

---

## Other Commands

### Get-OMTags — Read Metadata

```powershell
# Quick summary of an album
Get-OMTags "C:\Music\Artist\Album"

# Detailed per-file tags
GOT "C:\Music\Artist\Album" -Details

# Include composer analysis (classical music)
GOT "C:\Music\Classical\Album" -Details -IncludeComposer
```

### Set-OMTags — Write Metadata

```powershell
# Set tags via hashtable
Set-OMTags -Path "C:\Music\file.flac" -Tags @{ Year = 2024; Genres = @("Rock") }

# Pipeline: read, transform, write
GOT "C:\Music\Album" -Details |
    Set-OMTags -Transform { $_.Year = 2024; $_ }

# Rename files based on tags
GOT "C:\Music\Album" -Details |
    Set-OMTags -RenamePattern "{Track:D2} - {Title}"

# Extract tags from filenames
GOT "C:\Music\Album" -Details |
    Set-OMTags -ParseFilename "{Track} - {Artists} - {Title}"
```

### Add-OMDiscNumbers — Fix Track/Disc Numbers

```powershell
# Add disc numbers from folder structure
Add-OMDiscNumbers -baseFolder "C:\Music\Artist\Album" -discs

# Force renumber all tracks
Add-OMDiscNumbers -baseFolder "C:\Music\Artist\Album" -forceTracks
```

### Move-OMTags — Organize by Tags

```powershell
# Move and rename based on tags
Move-OMTags -Path "C:\Music\Unsorted\Album" -TargetFolder "C:\Music\Organized"
```

Creates: `C:\Music\Organized\AlbumArtist\Year - Album\01 - Track.flac`

### Repair-AudioFileExtensions — Fix Wrong Extensions

```powershell
# Check and fix mismatched extensions (e.g., .flac that's actually .m4a)
Repair-AudioFileExtensions -Path "C:\Music" -Recurse
```

### Export-OMPlaylists — Export Spotify Playlists to CSV

```powershell
# Interactive picker — select playlists from a grid view
Export-OMPlaylists

# Export all playlists at once
Export-OMPlaylists -All

# Filter by name (supports wildcards)
Export-OMPlaylists -Name "Jazz*"

# Include audio features (key, tempo, danceability, etc.)
Export-OMPlaylists -Name "Favorites" -IncludeAudioFeatures

# Custom output directory
Export-OMPlaylists -OutputPath "D:\Music\Playlists" -All
```

Exports one CSV per playlist to `~/.OM/playlists/` by default. With `-IncludeAudioFeatures`, adds musical key (e.g., C, F#), mode (Major/Minor), tempo, and more.

---

## Command Reference

All interactive commands available via `?` at any prompt:

### Universal Commands (all stages)

| Command | Action |
|---------|--------|
| `ps` / `pq` / `pd` / `pm` | Switch provider (Spotify / Qobuz / Discogs / MusicBrainz) |
| `p` | Show current provider info |
| `x` | Skip this album |
| `f` | Toggle search mode (quick ↔ artist-first) |
| `?` | Show available commands for current context |

### Navigation

| Command | Available In | Action |
|---------|-------------|--------|
| `b` | Quick-Find, Stage B, Stage C | Go back to previous stage |
| `n` | Stage B | Next page of results |
| `pr` | Stage B, Stage C | Previous page / back navigation |
| `ni` | Quick-Find, Stage B | New Item — enter new artist + album name |

### Stage-Specific

| Command | Stage | Action |
|---------|-------|--------|
| `id:<id>` | A, B | Select by provider ID |
| `al:<name>` | A | Change album name for search |
| `*` | B | Select all albums (multi-disc) |
| `sa` / `st` / `sf` | C | Save all / tags / folder names |
| `o` `d` `t` `n` `l` `h` `m` | C | Sort methods |
| `r` / `rm` | C | Reverse columns / Review marked tracks |
| `aa` / `gm` / `w` / `v` | C | Album artist / Genre mode / WhatIf / Verbose |
| `cv` / `cvo` / `cs` / `ct` | B, C, Quick-Find | Cover art operations |

---

## Configuration

### Initial Setup

```powershell
# Set your preferred default provider
Set-OMConfig -DefaultProvider Qobuz

# Spotify credentials
Set-OMConfig -SpotifyClientId "your-id" -SpotifyClientSecret "your-secret"

# Discogs token (get from https://www.discogs.com/settings/developers)
Set-OMConfig -DiscogsToken "your-token"

# Google CSE (for Qobuz URL lookups)
Set-OMConfig -GoogleApiKey "your-key" -GoogleCse "your-cse-id"

# Cover art sizes (pixels)
Set-OMConfig -FolderImageSize 600 -TagImageSize 150

# View current config
Get-OMConfig
```

### Config File Location

- **Windows:** `%USERPROFILE%\.OM\config.json`
- **Linux/Mac:** `~/.OM/config.json`
- **Override:** set `$env:OM_CONFIG_PATH`

### Provider Requirements

| Provider | Credentials Needed | Best For |
|----------|--------------------|----------|
| **Spotify** | Client ID + Secret | General use, good artist data |
| **Qobuz** | App ID + Secret | Hi-res metadata, classical, French catalog |
| **Discogs** | Token | Vinyl releases, genres, compilation credits |
| **MusicBrainz** | None (public API) | Fallback, community-curated data |

---

## Tips & Tricks

### Pipeline Workflow

The `GOT | FOG | SOT` pipeline is the standard pattern for batch tag processing:

```powershell
# Read tags → standardize genres → write back
Get-OMTags "C:\Music\Album" -Details | Format-Genres -PassThru | Set-OMTags
```

### Provider Selection Strategy

- Start with **Spotify** (good general coverage, fast)
- Use **Qobuz** for classical, hi-res, or European releases
- Use **Discogs** for vinyl, rare releases, or better genre data
- Use **MusicBrainz** as a fallback (community data, no auth needed)
- Use `-AutoFallback` to let Auto mode try all providers

### Handling Classical Music

Classical albums often have complex artist credits. Use:

- `aa` command in Stage C to build a custom album artist
- `-IncludeComposer` with `Get-OMTags` for composer analysis
- `-UpdateOnly Artists,Composers -Provider Qobuz` for best classical metadata

### Dry Run

Always preview changes first on important collections:

```powershell
Start-OM -Path "C:\Music\Rare" -Auto -WhatIf
```

Or toggle WhatIf during interactive use with the `w` command.

### Module Aliases

| Alias | Command |
|-------|---------|
| `SOM` | Start-OM |
| `GOT` | Get-OMTags |
| `SOT` | Set-OMTags |
| `FOG` | Format-Genres |
| `MOT` | Move-OMTags |
| `AOD` | Add-OMDiscNumbers |

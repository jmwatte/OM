# Context Object Migration Plan

## Problem

The OM module uses `$script:` variables as shared mutable state between
`Start-OM.ps1` and the Stage/Workflow functions. Functions silently read and
write module-scope variables without declaring them in their parameter blocks.
This makes the code untestable (tests can't control the state) and fragile
(pipeline leaks, uninitialized variables under `Set-StrictMode`).

## Solution

Replace implicit `$script:` access with an explicit **Context hashtable**
passed as a parameter. Hashtables are reference types in PowerShell, so
mutations inside a called function are visible to the caller — same behavior
as `$script:` today, but declared and controllable.

## Current State (after Step 1)

```
Branch: refactor/context-object
Commit: 96ceec2 — Invoke-HandleMoveSuccess migrated + 16 tests
```

`$script:ctx` is initialized per-album in Start-OM.ps1 and contains:

```powershell
$script:ctx = @{
    Album              = $albumOriginal
    AudioFiles         = $null
    PairedTracks       = $null
    RefreshTracks      = $false
    TargetFolderMoved  = $false
    IsSingleAlbumPath  = $script:isSingleAlbumPath
}
```

`Invoke-HandleMoveSuccess` accepts `-Context` with `$script:` fallback.

---

## Variable Inventory

### Already in Context (Category D — Done)

| Variable | Purpose |
|----------|---------|
| `Album` | Current album DirectoryInfo |
| `AudioFiles` | Array of audio file objects |
| `PairedTracks` | Array of {AudioFile, ProviderTrack} pairs |
| `RefreshTracks` | Boolean flag to trigger track display refresh |
| `TargetFolderMoved` | Boolean flag after target folder move |
| `IsSingleAlbumPath` | Boolean — single album vs artist folder mode |

### Need Migration (Category B — Shared Mutable State)

| Variable | Read by | Written by | Refs |
|----------|---------|------------|------|
| `FindMode` | Stage A, B, C, Start-OM | Stage A, C, Start-OM | ~15 |
| `ShowVerbose` | Stage C | Stage C | ~5 |
| `GenreMode` | Stage C, Start-OM | Stage C, Start-OM | ~10 |
| `ManualAlbumArtist` | Stage C | Stage C | ~8 |
| `AutoModeActive` | Stage C | Stage C, Start-OM | ~6 |
| `BackNavigationMode` | Stage C, Start-OM | Stage C, Start-OM | ~10 |

### No Migration Needed

| Variable | Why |
|----------|-----|
| `$script:artist` | Read-only display — passed as parameter to stages |
| `$script:albumName` | Read-only display — passed as parameter to stages |
| `$script:trackCount` | Read-only display — passed as parameter to stages |
| `$script:quickAlbumCandidates` | Only used in Start-OM.ps1, never in stages |
| `$script:quickCurrentPage` | Only used in Start-OM.ps1, never in stages |
| `$script:originalPath` | Set once, read once, both in Start-OM.ps1 |
| Move-AlbumFolder locals | Local to `begin` block, not shared |

### Optional (Category A — Could Add for Consistency)

`artist`, `albumName`, `trackCount` — currently passed as parameters AND
stored in `$script:`. Could add to Context to have a single source of truth,
but not required since stage functions already receive them as parameters.

---

## Migration Steps

### Step 1 — Infrastructure + First Function ✅ DONE

- [x] Create `$script:ctx` hashtable in Start-OM.ps1 per-album init
- [x] Migrate `Invoke-HandleMoveSuccess` with `-Context` + fallback
- [x] Stage C callers pass Context and sync back
- [x] 10 tests for HandleMoveSuccess
- [x] 6 pipeline-leak prevention tests
- [x] Commit: `96ceec2`

### Step 2 — Add Category B Variables to Context

Expand `$script:ctx` to include all Category B variables:

```powershell
$script:ctx = @{
    # Category D (already present)
    Album              = $albumOriginal
    AudioFiles         = $null
    PairedTracks       = $null
    RefreshTracks      = $false
    TargetFolderMoved  = $false
    IsSingleAlbumPath  = $script:isSingleAlbumPath
    # Category B (new)
    FindMode           = 'artist-first'       # or 'quick'
    ShowVerbose        = $false
    GenreMode          = $GenreMode           # from param, default 'Replace'
    ManualAlbumArtist  = $null
    AutoModeActive     = $false
    BackNavigationMode = $false
}
```

Files: `Start-OM.ps1` only.
Tests: Verify init values.
Risk: None — just adding keys, nothing reads them yet.

### Step 3 — Migrate Stage C (biggest target, ~170 refs)

Stage C has the most `$script:` references. Migrate using the accessor pattern:

```powershell
function Invoke-StageC-TrackSelection {
    param(
        ...existing params...
        [hashtable]$Context
    )

    # Accessor pattern (transition period)
    $getAudioFiles = { if ($Context) { $Context.AudioFiles } else { $script:audioFiles } }
    $setAudioFiles = { param($v) if ($Context) { $Context.AudioFiles = $v } else { $script:audioFiles = $v } }
    # ... etc for each variable
```

**Sub-steps** (one commit each):
1. Add `-Context` parameter + accessors for `AudioFiles`, `PairedTracks`,
   `RefreshTracks`, `Album` — the variables already in ctx.
   Write tests for the save-all (`sa`) handler return type.
2. Add accessors for `FindMode`, `ManualAlbumArtist`, `BackNavigationMode`.
3. Add accessors for `ShowVerbose`, `GenreMode`, `AutoModeActive`.
4. Update Start-OM.ps1 to pass `-Context $script:ctx` to Stage C
   and sync state back after each call.

Files: `Invoke-StageC-TrackSelection.ps1`, `Start-OM.ps1`
Tests: Pipeline-leak test for `sa`/`sf` handlers, context state assertions.
Risk: Medium — many references, but accessor pattern is mechanical.

### Step 4 — Migrate Stage A and Stage B (~15 refs each)

These only use `$script:findMode` as shared mutable state. Small scope.

```powershell
function Invoke-StageA-ArtistSearch {
    param(
        ...existing params...
        [hashtable]$Context
    )
    $getFindMode = { if ($Context) { $Context.FindMode } else { $script:findMode } }
    $setFindMode = { param($v) if ($Context) { $Context.FindMode = $v } else { $script:findMode = $v } }
```

Files: `Invoke-StageA-ArtistSearch.ps1`, `Invoke-StageB-AlbumSelection.ps1`, `Start-OM.ps1`
Tests: Verify FindMode toggle works through Context.
Risk: Low — very few references.

### Step 5 — Sync Layer in Start-OM.ps1

Update Start-OM.ps1's stage-calling code to:
1. Pass `-Context $script:ctx` to all three stages
2. After each stage call, sync Context back to `$script:` (transition period):
   ```powershell
   $script:findMode = $script:ctx.FindMode
   $script:audioFiles = $script:ctx.AudioFiles
   # etc.
   ```
3. Write tests for the sync logic.

Files: `Start-OM.ps1`
Risk: Low — the sync is just copying values.

### Step 6 — Remove `$script:` Fallbacks

Once all callers pass Context:
1. Remove the `if ($Context) { ... } else { $script:... }` fallback code
2. Replace accessor scriptblocks with direct `$Context.Foo` access
3. Remove the sync-back code in Start-OM.ps1
4. Remove the now-unused `$script:` variable assignments

Files: All stage and workflow files.
Tests: All existing tests still pass (they already use Context).
Risk: Low — purely removing dead code.

### Step 7 — Remove `$script:ctx` Wrapper (Optional, Final)

At this point `$script:ctx` is the only `$script:` variable for shared state.
Optionally rename it to a local `$ctx` passed through the call chain, fully
eliminating module-scope mutation. This is optional — having one `$script:`
variable is already a massive improvement over 16.

---

## Testing Strategy

Each step includes tests that:

1. **Context state assertions** — verify the function modifies the right
   Context keys (e.g., `$ctx.TargetFolderMoved | Should -BeTrue`)

2. **Pipeline-leak guards** — verify functions return the expected type,
   not arrays (e.g., `$result | Should -BeOfType [hashtable]`)

3. **Source-code regex guards** — verify uncaptured calls have `$null =`
   (e.g., `$src | Should -Not -Match 'pattern'`)

4. **Backward-compat tests** — verify `$script:` fallback works when no
   Context is passed (removed in Step 6)

### Test Files

| File | Covers |
|------|--------|
| `Invoke-HandleMoveSuccess.Tests.ps1` | ✅ Exists — 10 tests |
| `Invoke-StageCPipelineLeak.Tests.ps1` | ✅ Exists — 6 tests |
| `Invoke-StageC-SaveAll.Tests.ps1` | Step 3 — sa handler |
| `Invoke-StageA-Context.Tests.ps1` | Step 4 — FindMode toggle |
| `Invoke-StageB-Context.Tests.ps1` | Step 4 — FindMode toggle |
| `Start-OM-ContextSync.Tests.ps1` | Step 5 — sync logic |

---

## Effort Summary

| Step | Files Changed | Refs to Migrate | Risk | Depends On |
|------|---------------|-----------------|------|------------|
| 1 ✅ | 3 + 2 tests | ~20 | Low | — |
| 2 | 1 | 0 (just add keys) | None | Step 1 |
| 3 | 2 | ~170 | Medium | Step 2 |
| 4 | 3 | ~15 | Low | Step 2 |
| 5 | 1 | ~20 | Low | Steps 3-4 |
| 6 | 5 | ~0 (remove code) | Low | Step 5 |
| 7 | 5 | ~15 | Low | Step 6 |

Steps 3 and 4 can be done in parallel (independent files).
Steps 2-4 are the core work. Steps 5-7 are cleanup.

# OM Module Refactoring Plan

**Created:** January 7, 2026  
**Status:** In Progress  
**Branch:** feat/extract-audio-and-prompts

---

## Executive Summary

The `Start-OM` function is a **3,575-line monolithic function** that violates core software engineering principles. This document provides a step-by-step refactoring roadmap that any developer can follow to transform it into a clean, testable, maintainable codebase.

---

## Phase 1: Quick Fixes (Immediate)

### 1.1 Fix Duplicate TRACE Output ✅ PRIORITY
**Time Estimate:** 30 minutes  
**Problem:** `Show-Message` calls with TRACE diagnostics are visible to users, causing duplicate/garbled output.

| Line | Current Code | Fix |
|------|--------------|-----|
| 312 | `Show-Message -Message ("TRACE: Building nonDiscFolders...")` | Change to `Write-Verbose` |
| 1341 | `Show-Message -Message ("TRACE: showHeader args...")` | Change to `Write-Verbose` |
| 1617 | `Show-Message -Message ("TRACE: showHeader args...")` | Change to `Write-Verbose` |
| 1863 | `Show-Message -Message ("TRACE: showHeader args...")` | Change to `Write-Verbose` |
| 2888 | `Show-Message -Message ("TRACE: handleMoveSuccess args...")` | Change to `Write-Verbose` |
| 3232 | `Show-Message -Message ("TRACE: handleMoveSuccess args...")` | Change to `Write-Verbose` |

**Verification:**
```powershell
# Should NOT show TRACE messages:
Start-OM -Path "C:\Music\Artist\Album"

# Should show TRACE messages:
Start-OM -Path "C:\Music\Artist\Album" -Verbose
```

---

## Phase 2: Remove Duplicate Inline Functions

### 2.1 Identify Inline Functions That Already Exist as Private Functions
**Time Estimate:** 2 hours

The following functions are defined INLINE in Start-OM.ps1 but ALREADY EXIST as separate private function files:

| Inline Definition (Lines) | Existing Private File | Action |
|---------------------------|----------------------|--------|
| `Get-StringSimilarity` (590-676) | `Private/Utils/Get-StringSimilarity.ps1` | DELETE inline, use existing |
| `Get-AlbumMatchConfidence` (678-750) | `Private/Utils/Get-AlbumMatchConfidence.ps1` | DELETE inline, use existing |
| `Get-BestAutoMatch` (752-780) | `Private/Utils/Get-BestAutoMatch.ps1` | DELETE inline, use existing |
| `Invoke-ProviderWithFallback` (782-857) | `Private/Providers/Invoke-ProviderWithFallback.ps1` | DELETE inline, use existing |
| `Invoke-MoveAlbumWithRetry` (426-442) | `Private/Workflow/Invoke-MoveAlbumWithRetry.ps1` | DELETE inline, use existing |

**Steps:**
- [ ] For each inline function, verify the private file version is identical or better
- [ ] Delete the inline definition from Start-OM.ps1
- [ ] Run tests to verify functionality unchanged

---

## Phase 3: Extract Embedded Scriptblocks

### 3.1 Extract `$handleMoveSuccess` Scriptblock
**Time Estimate:** 1 hour  
**Lines:** 444-588 (144 lines)

**Current State:** Defined as a scriptblock variable inside Start-OM
```powershell
$handleMoveSuccess = {
    param($moveResult, $useWhatIf, $oldpath)
    # 144 lines of folder move result handling
}
```

**Target State:** New private function file
```
Private/Workflow/Invoke-HandleMoveSuccess.ps1
```

**Steps:**
- [ ] Create `Private/Workflow/Invoke-HandleMoveSuccess.ps1`
- [ ] Convert scriptblock to function with proper `[CmdletBinding()]`
- [ ] Add parameter validation
- [ ] Replace all `& $handleMoveSuccess` calls with `Invoke-HandleMoveSuccess`
- [ ] Delete the inline scriptblock
- [ ] Create Pester test: `tests/Private/Workflow/Invoke-HandleMoveSuccess.Tests.ps1`

### 3.2 Extract `$showHeader` Scriptblock
**Time Estimate:** 30 minutes  
**Lines:** 410-424

**Current State:** Wraps `Show-OMHeader` with try/catch
```powershell
$showHeader = {
    param($Provider, $Artist, $AlbumName, $TrackCount)
    try { Show-OMHeader ... } catch { Write-Verbose ... }
}
```

**Target State:** Create helper function `Invoke-ShowHeader` in:
```
Private/UI/Invoke-ShowHeader.ps1
```

### 3.3 Extract `$isDiscFolder` Scriptblock
**Time Estimate:** 30 minutes  
**Lines:** 291-323

**Target:** `Private/Utils/Test-IsDiscFolder.ps1`

### 3.4 Extract `$normalizeDiscogsId` Scriptblock
**Time Estimate:** 30 minutes  
**Lines:** 375-407

**Target:** `Private/Utils/ConvertTo-NormalizedDiscogsId.ps1`

---

## Phase 4: Extract Stage Handlers

### 4.1 Create Stage A Handler
**Time Estimate:** 4 hours  
**Lines:** 1611-1780  
**Target:** `Private/Stages/Invoke-StageA-ArtistSelection.ps1`

**Responsibilities:**
- Display header with find mode
- Search for artists via provider
- Handle artist selection UI
- Return selected artist or navigation command

**Function Signature:**
```powershell
function Invoke-StageA-ArtistSelection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Context,
        
        [Parameter(Mandatory)]
        [string]$Provider,
        
        [Parameter(Mandatory)]
        [string]$ArtistQuery
    )
    # Returns: @{ NextStage = 'B'; SelectedArtist = $artist } or @{ Action = 'quit' }
}
```

**Steps:**
- [ ] Create function file with proper parameter binding
- [ ] Extract logic from Start-OM lines 1611-1780
- [ ] Replace `$script:*` variables with `$Context.*` properties
- [ ] Create Pester test file
- [ ] Update Start-OM to call the new function

### 4.2 Refactor Stage B Handler (Already Exists)
**Time Estimate:** 6 hours  
**File:** `Private/Stages/Invoke-StageB-AlbumSelection.ps1` (856 lines)

**Issues to Fix:**
- [ ] Genre update logic duplicated 5+ times (lines 344-379, 405-440, 459-494, 572-607, 734-787)
- [ ] Extract `Update-AlbumGenres` helper function
- [ ] Reduce script-scope dependencies

### 4.3 Create Stage C Handler
**Time Estimate:** 8 hours  
**Lines:** 1830-3500 (1,670 lines - largest extraction)  
**Target:** `Private/Stages/Invoke-StageC-TrackMatching.ps1`

**Responsibilities:**
- Display track matching UI
- Handle all doTracks loop commands (st, sa, rt, cv, mv, etc.)
- Tag saving operations
- Album folder renaming

**Sub-extractions needed:**
- [ ] `Invoke-SaveTrackTags` - handles 'st' command (lines ~2893-3055)
- [ ] `Invoke-SaveAllTracks` - handles 'sa' command (lines ~3056-3300)
- [ ] `Invoke-RefreshTracks` - handles 'rt' command
- [ ] `Invoke-CoverArtHandler` - handles 'cv' command
- [ ] `Invoke-MoveAlbumHandler` - handles 'mv' command

---

## Phase 5: Eliminate Script-Scope State

### 5.1 Create Context Object
**Time Estimate:** 2 hours

**Current State:** 11+ script-scope variables scattered throughout
```powershell
$script:album = $null
$script:isSingleAlbumPath = $false
$script:originalPath = $Path
$script:findMode = 'quick'
$script:ManualAlbumArtist = $null
$script:audioFiles = $null
$script:pairedTracks = $null
$script:refreshTracks = $false
$script:showVerbose = $false
$script:genreMode = 'Replace'
$script:trackCount = ...
$script:albumName = ...
$script:artist = ...
```

**Target State:** Single context object passed to all functions
```powershell
$ctx = [PSCustomObject]@{
    Album            = $null
    IsSingleAlbumPath = $false
    OriginalPath     = $Path
    FindMode         = 'quick'
    ManualAlbumArtist = $null
    AudioFiles       = @()
    PairedTracks     = @()
    RefreshTracks    = $false
    ShowVerbose      = $false
    GenreMode        = 'Replace'
    TrackCount       = 0
    AlbumName        = ''
    Artist           = ''
}
```

**Steps:**
- [ ] Create `New-OMContext` function to initialize context
- [ ] Update all stage handlers to accept `$Context` parameter
- [ ] Replace all `$script:varName` with `$Context.VarName`
- [ ] Add context validation at function entry points

---

## Phase 6: Consolidate Duplicate Logic

### 6.1 Audio File Reload Pattern
**Appears:** 4+ times in codebase

**Current Pattern:**
```powershell
$script:audioFiles = Get-ChildItem -LiteralPath $script:album.FullName -File -Recurse | 
    Where-Object { $_.Extension -match '\.(mp3|flac|wav|m4a|aac|ogg|ape)' } |
    Sort-Object { [regex]::Replace($_.Name, '(\d+)', { $args[0].Value.PadLeft(10, '0') }) }
```

**Target:** Use existing `Get-OMAudioFiles` or create if missing
```powershell
$ctx.AudioFiles = Get-OMAudioFiles -Path $ctx.Album.FullName
```

### 6.2 TagLib File Creation Pattern
**Appears:** Multiple times

**Extract to:** `New-OMTagLibFile` function

---

## Phase 7: Add Pester Tests

### 7.1 Test File Structure
```
tests/
├── Private/
│   ├── Stages/
│   │   ├── Invoke-StageA-ArtistSelection.Tests.ps1
│   │   ├── Invoke-StageB-AlbumSelection.Tests.ps1
│   │   └── Invoke-StageC-TrackMatching.Tests.ps1
│   ├── Workflow/
│   │   ├── Invoke-HandleMoveSuccess.Tests.ps1
│   │   └── Invoke-MoveAlbumWithRetry.Tests.ps1
│   └── UI/
│       └── Invoke-ShowHeader.Tests.ps1
├── Public/
│   └── Start-OM.Tests.ps1
└── Integration/
    └── Start-OM.Integration.Tests.ps1
```

### 7.2 Test Requirements Per Function
Each extracted function should have tests for:
- [ ] Normal operation (happy path)
- [ ] Edge cases (empty input, null values)
- [ ] Error handling (invalid paths, missing files)
- [ ] Mock dependencies (provider APIs, file system)

---

## Progress Tracking

### Checklist Format
Use this format to track progress:

```
## Phase 1: Quick Fixes
- [x] 1.1 Fix TRACE messages (6 locations)

## Phase 2: Remove Duplicates
- [ ] 2.1.1 Remove Get-StringSimilarity inline
- [ ] 2.1.2 Remove Get-AlbumMatchConfidence inline
- [ ] 2.1.3 Remove Get-BestAutoMatch inline
- [ ] 2.1.4 Remove Invoke-ProviderWithFallback inline
- [ ] 2.1.5 Remove Invoke-MoveAlbumWithRetry inline

## Phase 3: Extract Scriptblocks
- [ ] 3.1 Extract $handleMoveSuccess
- [ ] 3.2 Extract $showHeader
- [ ] 3.3 Extract $isDiscFolder
- [ ] 3.4 Extract $normalizeDiscogsId

## Phase 4: Extract Stages
- [ ] 4.1 Create Invoke-StageA-ArtistSelection
- [ ] 4.2 Refactor Invoke-StageB-AlbumSelection
- [ ] 4.3 Create Invoke-StageC-TrackMatching

## Phase 5: State Management
- [ ] 5.1 Create context object pattern

## Phase 6: Consolidate Duplicates
- [ ] 6.1 Unify audio file reload
- [ ] 6.2 Unify TagLib file creation

## Phase 7: Testing
- [ ] 7.1 Create test file structure
- [ ] 7.2 Write tests for each extraction
```

---

## Code Quality Goals

After refactoring, the codebase should meet these metrics:

| Metric | Current | Target |
|--------|---------|--------|
| Start-OM.ps1 lines | 3,575 | < 500 |
| Max function length | 3,575 | < 200 |
| Script-scope variables | 11+ | 0 |
| Inline function definitions | 8 | 0 |
| Pester test coverage | ~0% | > 80% |
| Cyclomatic complexity | Very High | Medium |

---

## Principles to Follow

1. **Single Responsibility:** Each function does ONE thing well
2. **Explicit Dependencies:** Pass dependencies as parameters, not script-scope
3. **Testability:** Functions should be testable in isolation
4. **DRY (Don't Repeat Yourself):** Extract repeated patterns
5. **Fail Fast:** Validate inputs early, provide clear error messages
6. **Progressive Enhancement:** Each phase should leave code in working state

---

## Notes for Implementers

- Always run existing tests before and after changes
- Make atomic commits for each checklist item
- Keep backups of working state (the `backups/` folder exists for this)
- When in doubt, create a test first
- Document any deviations from this plan in commit messages

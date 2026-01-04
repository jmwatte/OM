# OM Module Improvement Roadmap: `Start-OM` Refactoring

This document outlines a strategic roadmap for refactoring the main `Start-OM.ps1` function. The primary goals are to improve maintainability, enhance code quality, and create a more consistent and intuitive user experience (UX).

## Phase 1: Quick Wins (High-Impact UX Fixes)

This phase focuses on immediate, user-facing improvements that address the most significant inconsistencies in the interactive workflow.

### 1.1. Standardize and Unify User Commands
-   **Status:** `Pending`
-   **Objective:** Define a universal set of commands available at every interactive prompt. This eliminates user guesswork and makes the interface predictable.
-   **Implementation Details:**
    -   Create a private helper function, e.g., `Show-OMPrompt`, that takes a prompt message and a context (e.g., 'ArtistSelection', 'AlbumSelection') as input.
    -   This function will display the prompt and a dynamically generated list of available commands based on the context.
    -   The main loop in `Start-OM` will call this function instead of `Read-Host` directly.
-   **Proposed Universal Commands:**
    -   `p <provider_name>`: Switch **P**rovider (e.g., `p spotify`, `p qobuz`).
    -   `b`: Go **B**ack to the previous logical step.
    -   `s`: **S**kip the current album.
    -   `x`: E**x**it the entire `Start-OM` session.
    -   `ni`: **N**ew **I**tem (enter new search terms).
    -   `h`: **H**elp (display available commands).
-   **Contextual Commands:**
    -   `cv <range>`: **C**over **V**iew for listed items.
    -   `cs <range>`: **C**over **S**ave to folder.
    -   `ct <range>`: **C**over save in **T**ags.

### 1.2. Fix Cover Art Command Availability
-   **Status:** `Pending`
-   **Objective:** Resolve the bug where cover art commands (`cv`, `cs`, `ct`) are not available when an auto-mode search fails and yields zero results.
-   **Implementation Details:**
    -   Modify the input loop for "no results found" scenarios.
    -   This loop should use the same `Show-OMPrompt` helper from task 1.1.
    -   When `cv` (or related commands) are entered in a context with no selectable items, the handler should print a graceful message like "No items to display cover art for." instead of erroring or doing nothing.

### 1.3. Implement Consistent "Back" Navigation
-   **Status:** `Pending`
-   **Objective:** Allow users to reliably go back one step in the workflow.
-   **Implementation Details:**
    -   The main workflow loop will need to be aware of the previous stage.
    -   A simple state stack could be implemented (e.g., `$stageHistory = @('A')`). When moving from stage A to B, push 'B' onto the stack. When the user enters `b`, pop from the history to get the previous stage and re-enter its loop.
    -   This will be simplified later with the State Management Object (Phase 3).

## Phase 2: Medium-Term Improvements (Code Cleanliness)

This phase focuses on organizing the code, reducing complexity within `Start-OM.ps1`, and adhering to PowerShell best practices.

### 2.1. Relocate Helper Functions to `Private`
-   **Status:** `Pending`
-   **Objective:** Move all general-purpose helper functions currently defined inside the `Start-OM` `process` block into their own `.ps1` files in the `Private` folder.
-   **Functions to Move:**
    -   `Get-StringSimilarity` -> `Private/Utils/Get-StringSimilarity.ps1`
    -   `Get-AlbumMatchConfidence` -> `Private/Utils/Get-AlbumMatchConfidence.ps1`
    -   `Invoke-ProviderWithFallback` -> `Private/Providers/Common/Invoke-ProviderWithFallback.ps1`
    -   `Get-BestAutoMatch` -> `Private/Utils/Get-BestAutoMatch.ps1`
    -   `showHeader` -> `Private/Utils/Show-OMHeader.ps1`
    -   `Invoke-MoveAlbumWithRetry` -> `Private/Workflow/Invoke-MoveAlbumWithRetry.ps1`
-   **Impact:** Significantly declutters `Start-OM.ps1`, promotes reusability, and allows for independent testing of these helpers.

### 2.2. Centralize Audio File Loading
-   **Status:** `Pending`
-   **Objective:** Create a single, reusable function for loading and processing audio files from a given path.
-   **Implementation Details:**
    -   Create a new function: `Get-OMAudioFile.ps1` in `Private/`.
    -   This function will accept a `-Path` and perform the `Get-ChildItem`, filtering, sorting, and `TagLib.File::Create` logic currently duplicated in `Start-OM`.
    -   Replace all instances of this duplicated logic in `Start-OM` with a call to the new function.

## Phase 3: Long-Term Architectural Refactoring

This phase involves a major restructuring of the workflow to establish a robust, scalable, and maintainable architecture.

### 3.1. Introduce a Central State Management Object
-   **Status:** `Pending`
-   **Objective:** Replace the use of `$script:` scoped variables with a single, explicit state object.
-   **Implementation Details:**
    -   At the beginning of `Start-OM`, create a `$State` object (a `PSCustomObject`).
    -   This object will hold all data relevant to the workflow:
        ```powershell
        $State = [PSCustomObject]@{
            Provider        = 'Spotify'
            CurrentArtist   = $null
            CurrentAlbum    = $null
            ProviderArtist  = $null
            ProviderAlbum   = $null
            LocalAlbumPath  = $Path
            LocalAudioFiles = @()
            PairedTracks    = @()
            StageHistory    = @()
            # etc.
        }
        ```
    -   All subsequent functions will receive this object via a `-State` parameter and modify it directly. This makes state management explicit and traceable.

### 3.2. Decompose `Start-OM.ps1` into Stage-Specific Functions
-   **Status:** `Pending`
-   **Objective:** Break the monolithic logic of `Start-OM` into smaller, focused functions for each stage of the workflow.
-   **Implementation Details:**
    -   The main `Start-OM.ps1` will become a controller/orchestrator. Its main loop will call the appropriate stage function based on the `$State.CurrentStage`.
    -   Logic from the `switch ($stage)` block will be extracted into these new functions, which will reside in `Private/Stages/`:
        -   `Invoke-OMQuickFind.ps1`: Handles the entire "Quick Find" mode UI and logic.
        -   `Invoke-OMArtistSelection.ps1`: Handles the "Artist-First" search and selection.
        -   `Invoke-OMAlbumSelection.ps1`: Handles displaying albums for a selected artist.
        -   `Invoke-OMTrackMatching.ps1`: Handles the Stage C track matching UI and saving logic.
    -   Each stage function will accept the `$State` object and return a status (e.g., 'Proceed', 'GoBack', 'Skip', 'Exit') that the main controller uses to decide the next action.

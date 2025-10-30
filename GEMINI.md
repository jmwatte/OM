# Gemini Code Assistant Context

## Project: OM - Music Organization PowerShell Module

This document provides context for the Gemini Code Assistant about the `OM` PowerShell module.

### Project Overview

`OM` is a PowerShell module designed to streamline the process of organizing and tagging digital music libraries. It provides a suite of interactive and automated tools to fetch metadata from online sources, apply tags to audio files, and rename album folders according to a consistent naming convention.

The module is built around a central interactive workflow, `Start-OM`, which guides the user through a three-stage process of identifying an album, matching tracks, and applying tags. It also offers individual functions for more granular control over tagging and configuration.

### Core Technologies

*   **PowerShell**: The module is written entirely in PowerShell, following standard module structure with `Public` and `Private` folders.
*   **TagLib-Sharp**: The module relies on the `TagLib.dll` library for reading and writing metadata to a wide range of audio file formats (e.g., FLAC, MP3, M4A).
*   **Online Music APIs**: It integrates with several popular music databases to fetch album and artist information:
    *   Spotify
    *   Qobuz
    *   Discogs
    *   MusicBrainz

### Key Files and Structure

*   `OM.psd1`: The module manifest, which defines the module's properties, exported functions, and aliases.
*   `OM.psm1`: The root module script, which loads all public and private functions.
*   `Public/`: Contains the functions that are exported and intended for direct use by the user.
    *   `Start-OM.ps1`: The main interactive workflow for organizing albums.
    *   `Get-OMTags.ps1`: Reads metadata from audio files.
    *   `Set-OMTags.ps1`: Writes metadata to audio files.
    *   `Get-OMConfig.ps1` / `Set-OMConfig.ps1`: Manage module configuration (likely API keys and preferences).
*   `Private/`: Contains helper functions used internally by the public functions.
    *   `Providers/`: Contains the logic for interacting with the different online music APIs.
    *   `Stages/`: Encapsulates the logic for the different stages of the `Start-OM` workflow.
    *   `Utils/`: Provides various utility functions, such as string manipulation and user selection prompts.
*   `lib/`: Contains the `TagLib.dll` library.

### Building and Running

This is a PowerShell module, so there is no formal "build" process. To use the module, you need to:

1.  **Import the module**:
    ```powershell
    Import-Module .\OM.psd1
    ```
2.  **Run the functions**:
    ```powershell
    Start-OM -Path "C:\path\to\music"
    ```

### Development Conventions

*   **Function Naming**: Functions follow the standard PowerShell `Verb-Noun` naming convention (e.g., `Get-OMTags`, `Set-OMTags`).
*   **Public vs. Private**: Functions intended for public use are placed in the `Public` folder, while internal helper functions are in the `Private` folder.
*   **Interactive Workflow**: The primary user interaction is through the `Start-OM` function, which guides the user through a series of prompts and menus.
*   **API Integration**: Each online music provider has its own set of functions in a dedicated subfolder within `Private/Providers`.
*   **Tagging**: The module uses the `TagLib-Sharp` library for all tag reading and writing operations. The `Get-OMTags` and `Set-OMTags` functions provide a high-level interface for this.

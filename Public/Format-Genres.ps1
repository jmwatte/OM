function Format-Genres {
    <#
    .SYNOPSIS
        Validates and standardizes audio file genre tags against a whitelist with intelligent mapping.

    .DESCRIPTION
        Processes genre tags from audio files, validates them against a whitelist of standard genres,
        and provides interactive mapping for unmapped genres. Stores mappings in OM config for future
        automatic correction. Supports multiple modes: Interactive, Batch, Auto, and Review.

        Handles capitalization variants automatically (e.g., "blues", "Blues", "BLUES" → "Blues").
        Supports locale-aware genre mapping (e.g., French "Classique" → "Classical").

    .PARAMETER InputObject
        Tag object from Get-OMTags with a Genres property (array of strings).
        Accepts pipeline input.

    .PARAMETER Mode
        Processing mode:
        - 'Interactive' (default): Prompt for each unique unmapped genre
        - 'Batch': Collect all unmapped genres, decide once for each
        - 'Auto': Only apply existing mappings, skip unknown (silent)
        - 'Review': Show proposed changes without modifying config

    .PARAMETER NonInteractive
        Suppresses all prompts. Only applies pre-existing mappings from config.
        Unmapped genres are left unchanged.

    .PARAMETER ShowFrequency
        Display frequency count for each genre (how many files have it).

    .PARAMETER AllowGenreEditing
        Allow user to edit genre names when using [N]ew option.

    .PARAMETER TargetLocale
        Target locale for genre mapping (e.g., 'en-US', 'fr-FR', 'de-DE').
        Default: 'en-US'

    .PARAMETER AutoApplyTags
        Automatically pipe results to Set-OMTags after formatting.

    .PARAMETER BatchAllMatches
        When applying a mapping, apply to all instances of that genre automatically.

    .PARAMETER PassThru
        Return formatted tag objects with corrected genres for pipeline processing.
        Required when piping to Set-OMTags. Without this, only a summary is displayed.

    .PARAMETER Details
        Return individual file details instead of summary.

    .PARAMETER WhatIf
        Preview changes without modifying config or tags.

    .PARAMETER Force
        Skip all confirmations.

    .EXAMPLE
        # Basic usage: Interactively clean up genres and write back to files
        # IMPORTANT: Use -PassThru to pass modified tags to Set-OMTags
        Get-OMTags -Path "C:\Music\Album" -Details | Format-Genres -PassThru | Set-OMTags
        
        # Or using aliases:
        GOT "C:\Music\Album" -Details | FOG -PassThru | SOT

    .EXAMPLE
        # Preview all genres with frequency counts before making changes
        Get-OMTags -Path "C:\Music" -Details | Format-Genres -Mode Review -ShowFrequency
        
        # Shows a table with:
        # ✓ OK    - Genres already in whitelist
        # ⚙ MAP   - Genres with existing mappings (e.g., "Pop/Rock" → "Pop")
        # ? NEW   - Unmapped genres that need decisions
        # ✗ DEL   - Genres marked as garbage

    .EXAMPLE
        # Process multiple albums non-interactively (only applies existing mappings)
        Get-ChildItem "C:\Music" -Directory | ForEach-Object {
            GOT $_.FullName -Details | FOG -NonInteractive -PassThru | SOT
        }
        
        # Safe for batch processing - won't prompt, only uses known mappings

    .EXAMPLE
        # Interactive mode: Prompt for each unmapped genre as encountered
        # Use -PassThru to pipe corrected tags to Set-OMTags
        GOT "E:\Music\NewAlbum" -Details | FOG -ShowFrequency -PassThru | SOT
        
        # For each unmapped genre, you'll see options:
        # [M]ap to existing genre
        # [N]ew - add to whitelist
        # [G]arbage - mark for deletion
        # [S]kip this genre

    .EXAMPLE
        # Batch mode: Review all unmapped genres first, then decide
        GOT "C:\Music" -Details | FOG -Mode Batch -ShowFrequency -PassThru | SOT
        
        # Collects all unmapped genres across all files, shows frequency,
        # then prompts once per unique genre for decision

    .EXAMPLE
        # Auto mode: Silent processing with existing mappings only
        GOT "D:\MusicLibrary" -Details | FOG -Mode Auto -PassThru | SOT
        
        # No prompts, no new mappings created. Perfect for scheduled tasks.

    .EXAMPLE
        # Safe preview: See what would change without modifying anything
        GOT "C:\Music\TestAlbum" -Details | FOG -ShowFrequency -PassThru | SOT -WhatIf
        
        # Shows exactly which files would be updated and how genres would change

    .EXAMPLE
        # Process single album and see corrected genres in pipeline
        $corrected = GOT "E:\10cc" -Details | FOG -NonInteractive -PassThru
        $corrected | Select-Object Path, Genres
        
        # PassThru returns objects with corrected genres for further processing

    .EXAMPLE
        # Handle locale-specific genres (e.g., French music collection)
        GOT "C:\Musique" -Details | FOG -ShowFrequency | SOT
        
        # Prompts to map "Classique" → "Classical", "Variété" → "Pop", etc.
        # Mappings are saved and reused automatically

    .EXAMPLE
        # Check current genre mappings in config
        $config = Get-OMConfig
        $config.Genres.GenreMappings
        
        # Edit config to add/remove mappings:
        Set-OMConfig -GenresMappings @{"pop/rock" = "Pop"; "classique" = "Classical"}

    .LINK
        Get-OMTags
        Set-OMTags
        Get-OMConfig
        Set-OMConfig
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium', DefaultParameterSetName = 'Default')]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'Default')]
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'Interactive')]
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'Batch')]
        [PSCustomObject]$InputObject,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Interactive', 'Batch', 'Auto', 'Review')]
        [string]$Mode = 'Interactive',

        [Parameter(Mandatory = $false)]
        [switch]$NonInteractive,

        [Parameter(Mandatory = $false)]
        [switch]$ShowFrequency,

        [Parameter(Mandatory = $false)]
        [switch]$AllowGenreEditing,

        [Parameter(Mandatory = $false)]
        [string]$TargetLocale = 'en-US',

        [Parameter(Mandatory = $false)]
        [switch]$AutoApplyTags,

        [Parameter(Mandatory = $false)]
        [switch]$BatchAllMatches,

        [Parameter(Mandatory = $false)]
        [switch]$PassThru,

        [Parameter(Mandatory = $false)]
        [switch]$Details,

        [Parameter(Mandatory = $false)]
        [switch]$Force,

        [Parameter(Mandatory = $false)][object]$Context
    )

    begin {
        # Default standard genres - comprehensive list
        $defaultStandardGenres = @(
            # Classical
            'Classical', 'Western Classical', 'Baroque', 'Romantic', 'Modern Classical', 'Opera',
            'Chamber Music', 'Choral', 'Medieval', 'Renaissance',
            'Indian Classical', 'Persian Classical', 'Andalusian Classical',
            'Korean Court Music', 'Ottoman Classical',
            # Rock
            'Rock', 'Hard Rock', 'Punk Rock', 'Garage Rock', 'Indie Rock',
            'Alternative Rock', 'Progressive Rock', 'Psychedelic Rock', 'Grunge',
            'Glam Rock', 'Southern Rock', 'Surf Rock', 'Post-Rock',
            # Pop
            'Pop', 'Dance-Pop', 'Electropop', 'Teen Pop', 'K-Pop', 'J-Pop',
            'Mandopop', 'Synthpop', 'Bubblegum Pop', 'Power Pop',
            # Electronic
            'EDM', 'House', 'Techno', 'Trance', 'Drum & Bass', 'Dubstep',
            'Electro', 'Ambient', 'Chillout', 'Industrial', 'Trip-Hop',
            'Vaporwave', 'Future Bass',
            # Jazz
            'Jazz', 'Swing', 'Bebop', 'Cool Jazz', 'Free Jazz', 'Fusion',
            'Smooth Jazz',
            # Blues
            'Blues', 'Delta Blues', 'Chicago Blues',
            # R&B / Hip-Hop
            'Rhythm & Blues (R&B)', 'Hip-Hop', 'Rap', 'Trap', 'Boom Bap',
            'Drill', 'Lo-Fi Hip-Hop', 'Conscious Rap', 'Gangsta Rap', 'Crunk',
            # Folk / Country
            'Folk', 'Country', 'Bluegrass', 'Americana', 'Celtic', 'Flamenco',
            'Fado', 'Tango',
            # Reggae / Caribbean
            'Reggae', 'Ska', 'Calypso', 'Soca',
            # World Music
            'Afrobeat', 'Highlife', 'Klezmer', 'Gamelan', 'Tuvan Throat Singing',
            # Metal
            'Heavy Metal', 'Thrash Metal', 'Death Metal', 'Black Metal',
            'Doom Metal', 'Power Metal', 'Symphonic Metal', 'Nu Metal', 'Metalcore',
            # Soul / Funk
            'Soul', 'Funk', 'Motown', 'Neo-Soul', 'Disco', 'Gospel',
            # Multimedia
            'Soundtrack / Film Score', 'Musical Theatre',
            # Experimental
            'Experimental', 'Avant-Garde', 'Noise', 'Minimalism', 'Chillwave', 'Shoegaze'
        )

        # Load config
        try {
            $omConfig = Get-OMConfig -ErrorAction Stop
        }
        catch {
            Write-Warning "Failed to load OM config: $_. Using defaults."
            $omConfig = @{}
        }

        # Initialize Genres section if missing
        if (-not $omConfig.Genres) {
            $genresSection = [PSCustomObject]@{
                AllowedGenreNames = $defaultStandardGenres
                GenreMappings     = @{}
                GarbageGenres     = @()
            }
            $omConfig | Add-Member -NotePropertyName Genres -NotePropertyValue $genresSection -Force
        }

        # Ensure AllowedGenreNames exists and is an array
        if (-not $omConfig.Genres.AllowedGenreNames) {
            $omConfig.Genres | Add-Member -NotePropertyName AllowedGenreNames -NotePropertyValue $defaultStandardGenres -Force
        }

        if (-not $omConfig.Genres.GenreMappings) {
            $omConfig.Genres | Add-Member -NotePropertyName GenreMappings -NotePropertyValue @{} -Force
        }

        if (-not $omConfig.Genres.GarbageGenres) {
            $omConfig.Genres | Add-Member -NotePropertyName GarbageGenres -NotePropertyValue @() -Force
        }

        # Create normalized lookup for case-insensitive matching
        # Use config genres if available, otherwise use defaults
        $genresToUse = if ($omConfig.Genres -and $omConfig.Genres.AllowedGenreNames) {
            $omConfig.Genres.AllowedGenreNames
        }
        else {
            $defaultStandardGenres
        }
        
        $allowedGenresNormalized = @{}
        foreach ($genre in $genresToUse) {
            $key = $genre.ToLower()
            if (-not $allowedGenresNormalized.ContainsKey($key)) {
                $allowedGenresNormalized[$key] = $genre  # Store with original casing
            }
        }

        # Track all genres and their frequencies across pipeline
        # Always clear script variables to prevent accumulation from interrupted runs
        $script:allGenresFrequency = @{}
        $script:allInputObjects = @()
        $script:genreDecisions = @{}
    }

    process {
        # Collect input objects and genres
        if ($InputObject) {
            $script:allInputObjects += $InputObject

            # Extract genres from object
            $genres = $null
            if ($InputObject.Genres) {
                $genres = if ($InputObject.Genres -is [array]) {
                    @($InputObject.Genres | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
                }
                else {
                    # Split by comma/semicolon/slash and decode HTML entities (case-insensitive)
                    $genreString = $InputObject.Genres.ToString()
                    $decodedGenre = $genreString -replace '(?i)&amp;', '&' -replace '(?i)&lt;', '<' -replace '(?i)&gt;', '>' -replace '(?i)&quot;', '"' -replace '(?i)&#39;', "'"
                    @($decodedGenre -split '[,;/]' | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
                }
            }

            # Track frequency
            if ($genres) {
                foreach ($genre in $genres) {
                    $genreKey = $genre.ToLower()
                    if (-not $script:allGenresFrequency.ContainsKey($genreKey)) {
                        $script:allGenresFrequency[$genreKey] = @{
                            original = $genre
                            count    = 0
                            files    = @()
                        }
                    }
                    $script:allGenresFrequency[$genreKey].count++
                    $script:allGenresFrequency[$genreKey].files += $InputObject.Path
                }
            }
        }
    }

    end {
        if ($script:allInputObjects.Count -eq 0) {
            Write-Warning "No input objects with genres found."
            return
        }

        Write-Verbose "Processing $($script:allInputObjects.Count) objects with $($script:allGenresFrequency.Count) unique genres."

        # Analyze genres: categorize as allowed, mapped, or unmapped
        $genreAnalysis = @{
            allowed  = @()
            mapped   = @()
            unmapped = @()
            garbage  = @()
        }

        foreach ($genreKey in $script:allGenresFrequency.Keys) {
            $genreInfo = $script:allGenresFrequency[$genreKey]
            $originalGenre = $genreInfo.original

            # Check if it's allowed (case-insensitive)
            if ($allowedGenresNormalized.ContainsKey($genreKey)) {
                $genreAnalysis.allowed += @{
                    key       = $genreKey
                    original  = $originalGenre
                    standard  = $allowedGenresNormalized[$genreKey]
                    count     = $genreInfo.count
                    files     = $genreInfo.files
                }
            }
            # Check if it's already mapped
            elseif ($omConfig.Genres.GenreMappings.ContainsKey($genreKey)) {
                $mappedTo = $omConfig.Genres.GenreMappings[$genreKey]
                if ($null -eq $mappedTo -or $mappedTo -eq '') {
                    # Marked as garbage
                    $genreAnalysis.garbage += @{
                        key      = $genreKey
                        original = $originalGenre
                        count    = $genreInfo.count
                        files    = $genreInfo.files
                    }
                }
                else {
                    $genreAnalysis.mapped += @{
                        key       = $genreKey
                        original  = $originalGenre
                        mappedTo  = $mappedTo
                        count     = $genreInfo.count
                        files     = $genreInfo.files
                    }
                }
            }
            # Unmapped - will need user input
            else {
                $genreAnalysis.unmapped += @{
                    key      = $genreKey
                    original = $originalGenre
                    count    = $genreInfo.count
                    files    = $genreInfo.files
                }
            }
        }

        # Show frequency summary if requested
        if ($ShowFrequency) {
            Show-GenreFrequencySummary -Analysis $genreAnalysis
        }

        # Ensure Show-Message helper available when dot-sourced in tests
        if (-not (Get-Command -Name Show-Message -ErrorAction SilentlyContinue)) {
            $candidates = @()
            if ($PSScriptRoot) { $candidates += Join-Path $PSScriptRoot '..\Utils\Show-Message.ps1' }
            if ($MyInvocation.MyCommand.Path) { $candidates += Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\Utils\Show-Message.ps1' }
            $candidates += Join-Path (Get-Location) 'Private\Utils\Show-Message.ps1'
            foreach ($p in $candidates) { if (Test-Path $p) { . $p; break } }
        }

        # Handle unmapped genres based on mode
        if ($genreAnalysis.unmapped.Count -gt 0) {
            if ($Mode -eq 'Review' -or $NonInteractive) {
                Show-Message -Message "`nUnmapped genres (will be left unchanged):" -ForegroundColor Yellow -Context $Context
                foreach ($unmapped in $genreAnalysis.unmapped) {
                    Show-Message -Message ("  - '$($unmapped.original)' ($($unmapped.count) files)") -ForegroundColor Gray -Context $Context
                }
            }
            elseif ($Mode -eq 'Interactive' -or $Mode -eq 'Batch') {
                Process-UnmappedGenres -UnmappedGenres $genreAnalysis.unmapped `
                    -AllowedGenres $omConfig.Genres.AllowedGenreNames `
                    -AllowedGenresNormalized $allowedGenresNormalized `
                    -Mode $Mode `
                    -AllowEditing ([bool]$AllowGenreEditing) `
                    -Force ([bool]$Force) `
                    -WhatIf ([bool]$WhatIf)
            }
        }

        # Apply all corrections to objects
        $correctedObjects = Apply-GenreCorrections -InputObjects $script:allInputObjects `
            -AllowedGenresNormalized $allowedGenresNormalized `
            -GenreMappings $omConfig.Genres.GenreMappings `
            -GarbageGenres $omConfig.Genres.GarbageGenres

        # Output results
        if ($PassThru) {
            $correctedObjects | ForEach-Object { $_ }
        }

        # Update config if changes were made
        if ($script:genreDecisions.Count -gt 0 -and -not $WhatIf) {
            Update-GenresConfig -NewMappings $script:genreDecisions -Config $omConfig
        }

        # Cleanup
        $script:allGenresFrequency = @{}
        $script:allInputObjects = @()
        $script:genreDecisions = @{}
    }
}

# Helper function to show frequency summary
function Show-GenreFrequencySummary {
    param(
        [hashtable]$Analysis
    )

    Write-Host "`n╔════════════════════════════════════════════════════════════════╗"
    Write-Host "║                    GENRE ANALYSIS SUMMARY                      ║"
    Write-Host "╠════════════════════════════════════════════════════════════════╣"

    $rows = @()

    foreach ($item in $Analysis.allowed) {
        $rows += [PSCustomObject]@{
            Status = "✓ OK"
            Genre  = $item.original
            Count  = $item.count
            Action = "Allowed"
        }
    }

    foreach ($item in $Analysis.mapped) {
        $rows += [PSCustomObject]@{
            Status = "⚙ MAP"
            Genre  = $item.original
            Count  = $item.count
            Action = "→ $($item.mappedTo)"
        }
    }

    foreach ($item in $Analysis.unmapped) {
        $rows += [PSCustomObject]@{
            Status = "? NEW"
            Genre  = $item.original
            Count  = $item.count
            Action = "Needs decision"
        }
    }

    foreach ($item in $Analysis.garbage) {
        $rows += [PSCustomObject]@{
            Status = "✗ DEL"
            Genre  = $item.original
            Count  = $item.count
            Action = "Delete"
        }
    }

    $rows | Format-Table -Property @(
        @{ Label = "Status"; Expression = { $_.Status }; Width = 8 }
        @{ Label = "Genre"; Expression = { $_.Genre }; Width = 25 }
        @{ Label = "Files"; Expression = { $_.Count }; Width = 8 }
        @{ Label = "Action"; Expression = { $_.Action }; Width = 25 }
    ) | Out-String | Write-Host

    Write-Host "╚════════════════════════════════════════════════════════════════╝"
}

# Helper function to process unmapped genres
function Process-UnmappedGenres {
    param(
        [array]$UnmappedGenres,
        [array]$AllowedGenres,
        [hashtable]$AllowedGenresNormalized,
        [string]$Mode,
        [bool]$AllowEditing,
        [bool]$Force,
        [bool]$WhatIf
    )

    foreach ($unmapped in $UnmappedGenres) {
        $originalGenre = $unmapped.original
        $count = $unmapped.count

        # Check if this genre has been resolved already (either directly or via case-insensitive match)
        $genreLower = $originalGenre.ToLower()
        if ($AllowedGenresNormalized.ContainsKey($genreLower) -or $script:genreDecisions.ContainsKey($genreLower)) {
            Write-Verbose "Skipping '$originalGenre' - already resolved"
            continue
        }

        $decision = $null

        while (-not $decision) {
            # Always display the genre being processed (helps when going back)
            Write-Host "`n╔════════════════════════════════════════════════════════════════╗"
            Write-Host "  Found '$originalGenre' in $count file(s)"
            Write-Host "╚════════════════════════════════════════════════════════════════╝"
            
            Write-Host "`nOptions:"
            Write-Host "  [N]ew      - Add as new standard genre"
            Write-Host "  [A]ddTo    - Map to existing standard genre"
            Write-Host "  [C]hange   - Replace with different genre"
            Write-Host "  [D]elete   - Mark as garbage, remove from tags"
            Write-Host "  [R]eview   - Review and modify recent decisions"
            Write-Host "  [S]kip     - Skip for now (don't decide)"
            Write-Host "  [Show]     - Show sample files with this genre"

            if (-not $Force) {
                $choice = Read-Host "Choose option (N/A/C/D/R/S/Show)"
                $choice = $choice.ToUpper()
                # Handle 'SHOW' before truncating to first character
                if ($choice -ne 'SHOW') {
                    $choice = $choice.Substring(0, 1)
                }
            }
            else {
                $choice = 'S'  # Default to skip if force
            }

            switch ($choice) {
                'N' {
                    # New genre - always allow editing
                    $editedGenre = Read-Host "Genre name (Enter to keep '$originalGenre', or 'B' to go back)"
                    
                    # Check if user wants to go back
                    if ($editedGenre -eq 'B' -or $editedGenre -eq 'b') {
                        Show-Message -Message "Going back to main menu..." -ForegroundColor Gray -Context $Context
                        # Don't set $decision, continue the loop to re-display
                        continue
                    }
                    
                    # Use edited name if provided, otherwise keep original
                    $newGenre = if (-not [string]::IsNullOrWhiteSpace($editedGenre)) {
                        $editedGenre
                    } else {
                        $originalGenre
                    }
                    
                    # Standardize capitalization to Title Case for consistency
                    $textInfo = (Get-Culture).TextInfo
                    $newGenre = $textInfo.ToTitleCase($newGenre.ToLower())

                    # Add to allowed genres and create mapping
                    if (-not $AllowedGenresNormalized.ContainsKey($newGenre.ToLower())) {
                        $script:genreDecisions[$originalGenre.ToLower()] = $newGenre
                        
                        # Add to the live session lists so it's immediately available
                        $AllowedGenres += $newGenre
                        $AllowedGenresNormalized[$newGenre.ToLower()] = $newGenre
                        
                        # Also add to config's AllowedGenreNames so it persists
                        if ($omConfig.Genres.AllowedGenreNames -notcontains $newGenre) {
                            $omConfig.Genres.AllowedGenreNames += $newGenre
                        }
                        
                        Show-Message -Message ("✓ Mapping: '$originalGenre' → '$newGenre'") -ForegroundColor Green -Context $Context
                        Show-Message -Message "  (Now available in standard genres list)" -ForegroundColor Gray -Context $Context
                        
                        # Also map any case variants in the unmapped list to this new standard genre
                        $newGenreLower = $newGenre.ToLower()
                        foreach ($unmappedItem in $genreAnalysis.unmapped) {
                            $unmappedLower = $unmappedItem.original.ToLower()
                            if ($unmappedLower -eq $newGenreLower -and $unmappedItem.original -ne $originalGenre) {
                                $script:genreDecisions[$unmappedLower] = $newGenre
                                Show-Message -Message ("  ✓ Also mapping case variant: '$($unmappedItem.original)' → '$newGenre'") -ForegroundColor Gray -Context $Context
                            }
                        }
                    }
                    else {
                        Show-Message -Message ("⚠ '$newGenre' already exists in standard genres.") -ForegroundColor Yellow -Context $Context
                    }
                    $decision = $true
                }

                'A' {
                    # AddTo - show list and map
                    # Rebuild list from normalized hashtable to include any newly added genres
                    $currentAllowedGenres = @($AllowedGenresNormalized.Values | Sort-Object)
                    
                    Show-Message -Message "`nStandard genres:" -ForegroundColor Cyan -Context $Context
                    for ($i = 0; $i -lt $currentAllowedGenres.Count; $i++) {
                        Show-Message -Message "$($i + 1). $($currentAllowedGenres[$i])" -ForegroundColor Gray -Context $Context
                    }

                    $selection = Read-Host "Map to genre (1-$($currentAllowedGenres.Count), or 'B' to go back)"
                    
                    # Check if user wants to go back
                    if ($selection -eq 'B' -or $selection -eq 'b') {
                        Show-Message -Message "Going back to main menu..." -ForegroundColor Gray -Context $Context
                        # Don't set $decision, so the while loop continues
                    }
                    elseif ($selection -match '^\d+$' -and [int]$selection -ge 1 -and [int]$selection -le $currentAllowedGenres.Count) {
                        $mappedGenre = $currentAllowedGenres[[int]$selection - 1]
                        $script:genreDecisions[$originalGenre.ToLower()] = $mappedGenre
                        Show-Message -Message ("✓ Mapping: '$originalGenre' → '$mappedGenre'") -ForegroundColor Green -Context $Context
                        $decision = $true
                    }
                    else {
                        Show-Message -Message "Invalid selection." -ForegroundColor Red -Context $Context
                    }
                }

                'C' {
                    # Change - replace with a different genre (existing or new)
                    Show-Message -Message ("`nReplace '$originalGenre' with:") -ForegroundColor Cyan -Context $Context
                    Show-Message -Message "  [E]xisting - Choose from standard genres" -ForegroundColor Gray -Context $Context
                    Show-Message -Message "  [N]ew      - Enter a new genre name" -ForegroundColor Gray -Context $Context
                    Show-Message -Message "  [B]ack     - Go back to main menu" -ForegroundColor Gray -Context $Context
                    
                    $changeChoice = Read-Host "Choose option (E/N/B)"
                    $changeChoice = $changeChoice.ToUpper().Substring(0, 1)
                    
                    switch ($changeChoice) {
                        'E' {
                            # Choose from existing genres
                            $currentAllowedGenres = @($AllowedGenresNormalized.Values | Sort-Object)
                            
                            Show-Message -Message "`nStandard genres:" -ForegroundColor Cyan -Context $Context
                            for ($i = 0; $i -lt $currentAllowedGenres.Count; $i++) {
                                Show-Message -Message "$($i + 1). $($currentAllowedGenres[$i])" -ForegroundColor Gray -Context $Context
                            }

                            $selection = Read-Host "Replace with genre (1-$($currentAllowedGenres.Count), or 'B' to go back)"
                            
                            if ($selection -eq 'B' -or $selection -eq 'b') {
                                Show-Message -Message "Going back..." -ForegroundColor Gray -Context $Context
                            }
                            elseif ($selection -match '^\d+$' -and [int]$selection -ge 1 -and [int]$selection -le $currentAllowedGenres.Count) {
                                $replacementGenre = $currentAllowedGenres[[int]$selection - 1]
                                $script:genreDecisions[$originalGenre.ToLower()] = $replacementGenre
                                Show-Message -Message ("✓ Replacing: '$originalGenre' → '$replacementGenre'") -ForegroundColor Green -Context $Context
                                $decision = $true
                            }
                            else {
                                Show-Message -Message "Invalid selection." -ForegroundColor Red -Context $Context
                            }
                        }
                        'N' {
                            # Enter new genre name
                            $newGenreName = Read-Host "Enter new genre name (or 'B' to go back)"
                            
                            if ($newGenreName -eq 'B' -or $newGenreName -eq 'b') {
                                Show-Message -Message "Going back..." -ForegroundColor Gray -Context $Context
                            }
                            elseif (-not [string]::IsNullOrWhiteSpace($newGenreName)) {
                                # Standardize capitalization to Title Case
                                $textInfo = (Get-Culture).TextInfo
                                $newGenreName = $textInfo.ToTitleCase($newGenreName.ToLower())
                                
                                # Add to allowed genres if not already there
                                if (-not $AllowedGenresNormalized.ContainsKey($newGenreName.ToLower())) {
                                    $AllowedGenres += $newGenreName
                                    $AllowedGenresNormalized[$newGenreName.ToLower()] = $newGenreName
                                    
                                    if ($omConfig.Genres.AllowedGenreNames -notcontains $newGenreName) {
                                        $omConfig.Genres.AllowedGenreNames += $newGenreName
                                    }
                                    Show-Message -Message ("  (Added '$newGenreName' to standard genres)") -ForegroundColor Gray -Context $Context
                                }
                                
                                $script:genreDecisions[$originalGenre.ToLower()] = $newGenreName
                                Show-Message -Message ("✓ Replacing: '$originalGenre' → '$newGenreName'") -ForegroundColor Green -Context $Context
                                $decision = $true
                            }
                            else {
                                Show-Message -Message "Invalid genre name." -ForegroundColor Red -Context $Context
                            }
                        }
                        'B' {
                            Show-Message -Message "Going back to main menu..." -ForegroundColor Gray -Context $Context
                        }
                        default {
                            Show-Message -Message "Invalid choice." -ForegroundColor Red -Context $Context
                        }
                    }
                }

                'D' {
                    # Delete - mark as garbage
                    $confirm = Read-Host "Delete '$originalGenre' from all $count file(s)? (y/N)"
                    if ($confirm -eq 'y' -or $confirm -eq 'Y') {
                        $script:genreDecisions[$originalGenre.ToLower()] = $null
                        Show-Message -Message ("✓ Marked '$originalGenre' for deletion") -ForegroundColor Green -Context $Context
                        $decision = $true
                    }
                }

                'R' {
                    # Review recent decisions
                    if ($script:genreDecisions.Count -eq 0) {
                        Show-Message -Message "No decisions made yet." -ForegroundColor Yellow -Context $Context
                    }
                    else {
                        Show-Message -Message "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan -Context $Context
                        Show-Message -Message "  Recent Decisions (this session):" -ForegroundColor Yellow -Context $Context
                        Show-Message -Message "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan -Context $Context
                        
                        $decisionList = @()
                        $index = 1
                        foreach ($key in $script:genreDecisions.Keys) {
                            $value = $script:genreDecisions[$key]
                            $action = if ($null -eq $value) { "DELETE" } else { "→ $value" }
                            $decisionList += [PSCustomObject]@{
                                Index = $index
                                Original = $key
                                Action = $action
                            }
                            Show-Message -Message ("  $index. '$key' $action") -ForegroundColor Gray -Context $Context
                            $index++
                        }
                        
Write-Host "`nOptions:"
                    Write-Host "  Enter number to delete that decision"
                    Write-Host "  'B' to go back"
                        
                        $reviewChoice = Read-Host "Choice"
                        
                        if ($reviewChoice -eq 'B' -or $reviewChoice -eq 'b') {
                            Show-Message -Message "Going back..." -ForegroundColor Gray -Context $Context
                        }
                        elseif ($reviewChoice -match '^\d+$' -and [int]$reviewChoice -ge 1 -and [int]$reviewChoice -le $decisionList.Count) {
                            $toRemove = $decisionList[[int]$reviewChoice - 1].Original
                            $script:genreDecisions.Remove($toRemove)
                            Show-Message -Message ("✓ Removed decision for '$toRemove'") -ForegroundColor Green -Context $Context
                        }
                        else {
                            Show-Message -Message "Invalid choice." -ForegroundColor Red -Context $Context
                        }
                    }
                }

                'S' {
                    # Skip
                    Show-Message -Message ("Skipping '$originalGenre' - will ask again next time") -ForegroundColor Gray -Context $Context
                    $decision = $true
                }

                'SHOW' {
                    # Show sample files
                    Show-Message -Message "`nSample files with '$originalGenre':" -ForegroundColor Cyan -Context $Context
                    $unmapped.files | Select-Object -First 5 | ForEach-Object {
                        Show-Message -Message ("  - $_") -ForegroundColor Gray -Context $Context
                    }
                    if ($unmapped.files.Count -gt 5) {
                        Show-Message -Message ("  ... and $($unmapped.files.Count - 5) more") -ForegroundColor Gray -Context $Context
                    }
                }

                default {
                    Show-Message -Message "Invalid option. Please choose N, A, D, R, S, or Show." -ForegroundColor Red -Context $Context
                }
            }
        }
    }
}

# Helper function to apply corrections
function Apply-GenreCorrections {
    param(
        [array]$InputObjects,
        [hashtable]$AllowedGenresNormalized,
        [hashtable]$GenreMappings,
        [array]$GarbageGenres
    )

    foreach ($obj in $InputObjects) {
        $correctedGenres = @()

        if ($obj.Genres) {
            $genres = if ($obj.Genres -is [array]) { @($obj.Genres) } else { @($obj.Genres) }

            foreach ($genre in $genres) {
                if ([string]::IsNullOrWhiteSpace($genre)) {
                    continue
                }

                $genreKey = $genre.ToLower()

                # Check if allowed (use standard casing)
                if ($AllowedGenresNormalized.ContainsKey($genreKey)) {
                    $correctedGenres += $AllowedGenresNormalized[$genreKey]
                }
                # Check if mapped
                elseif ($GenreMappings.ContainsKey($genreKey)) {
                    $mappedTo = $GenreMappings[$genreKey]
                    if ($null -ne $mappedTo -and $mappedTo -ne '') {
                        $correctedGenres += $mappedTo
                    }
                    # else: it's garbage (null), skip it
                }
                # Check if explicitly garbage
                elseif ($GarbageGenres -contains $genre) {
                    # Skip
                }
                # Unmapped - keep original
                else {
                    $correctedGenres += $genre
                }
            }
        }

        # Update genres and remove duplicates (case-insensitive)
        $obj.Genres = @($correctedGenres | Select-Object -Unique)
        $obj
    }
}

# Helper function to update config
function Update-GenresConfig {
    param(
        [hashtable]$NewMappings,
        [object]$Config
    )

    if ($NewMappings.Count -eq 0) {
        return
    }

    # Update mappings in config
    foreach ($key in $NewMappings.Keys) {
        $Config.Genres.GenreMappings[$key] = $NewMappings[$key]
    }

    # Save updated config
    try {
        $configPath = if ($IsLinux -or $IsMacOS) {
            Join-Path $HOME '.OM' 'config.json'
        }
        else {
            Join-Path $env:USERPROFILE '.OM' 'config.json'
        }
        
        # Ensure directory exists
        $configDir = Split-Path $configPath -Parent
        if (-not (Test-Path $configDir)) {
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        }
        
        # Save entire config with updated genres
        $Config | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath -Encoding UTF8 -ErrorAction Stop
        Write-Verbose "Updated genre mappings in config at: $configPath"
    }
    catch {
        Write-Warning "Failed to save genre mappings to config: $_"
    }
}

Export-ModuleMember -Function Format-Genres


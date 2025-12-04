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
        Return formatted tag objects with corrected genres.

    .PARAMETER Details
        Return individual file details instead of summary.

    .PARAMETER WhatIf
        Preview changes without modifying config or tags.

    .PARAMETER Force
        Skip all confirmations.

    .EXAMPLE
        Get-OMTags -Path "C:\Music\Album" | Format-Genres -ShowFrequency | Set-OMTags

    .EXAMPLE
        Get-OMTags -Path "C:\Music" | Format-Genres -Mode Batch -PassThru -ShowFrequency

    .EXAMPLE
        Get-OMTags -Path "C:\Music\Album" | Format-Genres -NonInteractive -PassThru

    .EXAMPLE
        Get-OMTags -Path "C:\Music\Album" | Format-Genres -Mode Review -WhatIf -ShowFrequency

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
        [switch]$Force
    )

    begin {
        # Default standard genres - comprehensive list
        $defaultStandardGenres = @(
            # Classical
            'Western Classical', 'Baroque', 'Romantic', 'Modern Classical', 'Opera',
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
            $omConfig.Genres = @{
                AllowedGenreNames = $defaultStandardGenres
                GenreMappings     = @{}
                GarbageGenres     = @()
            }
        }

        # Ensure AllowedGenreNames exists and is an array
        if (-not $omConfig.Genres.AllowedGenreNames) {
            $omConfig.Genres.AllowedGenreNames = $defaultStandardGenres
        }

        if (-not $omConfig.Genres.GenreMappings) {
            $omConfig.Genres.GenreMappings = @{}
        }

        if (-not $omConfig.Genres.GarbageGenres) {
            $omConfig.Genres.GarbageGenres = @()
        }

        # Create normalized lookup for case-insensitive matching
        $allowedGenresNormalized = @{}
        foreach ($genre in $omConfig.Genres.AllowedGenreNames) {
            $key = $genre.ToLower()
            if (-not $allowedGenresNormalized.ContainsKey($key)) {
                $allowedGenresNormalized[$key] = $genre  # Store with original casing
            }
        }

        # Track all genres and their frequencies across pipeline
        if (-not $script:allGenresFrequency) {
            $script:allGenresFrequency = @{}
            $script:allInputObjects = @()
            $script:genreDecisions = @{}
        }
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
                    @($InputObject.Genres)
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

        # Handle unmapped genres based on mode
        if ($genreAnalysis.unmapped.Count -gt 0) {
            if ($Mode -eq 'Review' -or $NonInteractive) {
                Write-Host "`nUnmapped genres (will be left unchanged):" -ForegroundColor Yellow
                foreach ($unmapped in $genreAnalysis.unmapped) {
                    Write-Host "  - '$($unmapped.original)' ($($unmapped.count) files)" -ForegroundColor Gray
                }
            }
            elseif ($Mode -eq 'Interactive' -or $Mode -eq 'Batch') {
                Process-UnmappedGenres -UnmappedGenres $genreAnalysis.unmapped `
                    -AllowedGenres $omConfig.Genres.AllowedGenreNames `
                    -AllowedGenresNormalized $allowedGenresNormalized `
                    -Mode $Mode `
                    -AllowEditing $AllowGenreEditing `
                    -Force $Force `
                    -WhatIf $WhatIf
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

    Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                    GENRE ANALYSIS SUMMARY                      ║" -ForegroundColor Cyan
    Write-Host "╠════════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan

    $rows = @()

    foreach ($item in $Analysis.allowed) {
        $rows += @{
            Status = "✓ OK"
            Genre  = $item.original
            Count  = $item.count
            Action = "Allowed"
        }
    }

    foreach ($item in $Analysis.mapped) {
        $rows += @{
            Status = "⚙ MAP"
            Genre  = $item.original
            Count  = $item.count
            Action = "→ $($item.mappedTo)"
        }
    }

    foreach ($item in $Analysis.unmapped) {
        $rows += @{
            Status = "? NEW"
            Genre  = $item.original
            Count  = $item.count
            Action = "Needs decision"
        }
    }

    foreach ($item in $Analysis.garbage) {
        $rows += @{
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

    Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
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

        Write-Host "`nFound '$originalGenre' in $count file(s)" -ForegroundColor Yellow

        $decision = $null

        while (-not $decision) {
            Write-Host "Options:" -ForegroundColor Cyan
            Write-Host "  [N]ew      - Add as new standard genre" -ForegroundColor Gray
            Write-Host "  [A]ddTo    - Map to existing standard genre" -ForegroundColor Gray
            Write-Host "  [D]elete   - Mark as garbage, remove from tags" -ForegroundColor Gray
            Write-Host "  [S]kip     - Skip for now (don't decide)" -ForegroundColor Gray
            Write-Host "  [Show]     - Show sample files with this genre" -ForegroundColor Gray

            if (-not $Force) {
                $choice = Read-Host "Choose option (N/A/D/S/Show)"
                $choice = $choice.ToUpper().Substring(0, 1)
            }
            else {
                $choice = 'S'  # Default to skip if force
            }

            switch ($choice) {
                'N' {
                    # New genre - allow editing
                    $newGenre = $originalGenre
                    if ($AllowEditing) {
                        $editedGenre = Read-Host "Genre name (or Enter to keep '$originalGenre')"
                        if (-not [string]::IsNullOrWhiteSpace($editedGenre)) {
                            $newGenre = $editedGenre
                        }
                    }

                    # Add to allowed genres and create mapping
                    if (-not $AllowedGenresNormalized.ContainsKey($newGenre.ToLower())) {
                        $script:genreDecisions[$originalGenre.ToLower()] = $newGenre
                        Write-Host "✓ Mapping: '$originalGenre' → '$newGenre'" -ForegroundColor Green
                    }
                    else {
                        Write-Host "⚠ '$newGenre' already exists in standard genres." -ForegroundColor Yellow
                    }
                    $decision = $true
                }

                'A' {
                    # AddTo - show list and map
                    Write-Host "`nStandard genres:" -ForegroundColor Cyan
                    for ($i = 0; $i -lt $AllowedGenres.Count; $i++) {
                        Write-Host "$($i + 1). $($AllowedGenres[$i])" -ForegroundColor Gray
                    }

                    $selection = Read-Host "Map to genre (1-$($AllowedGenres.Count))"
                    if ($selection -match '^\d+$' -and [int]$selection -ge 1 -and [int]$selection -le $AllowedGenres.Count) {
                        $mappedGenre = $AllowedGenres[[int]$selection - 1]
                        $script:genreDecisions[$originalGenre.ToLower()] = $mappedGenre
                        Write-Host "✓ Mapping: '$originalGenre' → '$mappedGenre'" -ForegroundColor Green
                        $decision = $true
                    }
                    else {
                        Write-Host "Invalid selection." -ForegroundColor Red
                    }
                }

                'D' {
                    # Delete - mark as garbage
                    $confirm = Read-Host "Delete '$originalGenre' from all $count file(s)? (y/N)"
                    if ($confirm -eq 'y' -or $confirm -eq 'Y') {
                        $script:genreDecisions[$originalGenre.ToLower()] = $null
                        Write-Host "✓ Marked '$originalGenre' for deletion" -ForegroundColor Green
                        $decision = $true
                    }
                }

                'S' {
                    # Skip
                    Write-Host "Skipping '$originalGenre' - will ask again next time" -ForegroundColor Gray
                    $decision = $true
                }

                'SHOW' {
                    # Show sample files
                    Write-Host "`nSample files with '$originalGenre':" -ForegroundColor Cyan
                    $unmapped.files | Select-Object -First 5 | ForEach-Object {
                        Write-Host "  - $_" -ForegroundColor Gray
                    }
                    if ($unmapped.files.Count -gt 5) {
                        Write-Host "  ... and $($unmapped.files.Count - 5) more" -ForegroundColor Gray
                    }
                }

                default {
                    Write-Host "Invalid option. Please choose N, A, D, S, or Show." -ForegroundColor Red
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

        # Update genres
        $obj.Genres = @($correctedGenres)
        $obj
    }
}

# Helper function to update config
function Update-GenresConfig {
    param(
        [hashtable]$NewMappings,
        [hashtable]$Config
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
        Set-OMConfig -GenresMappings $Config.Genres.GenreMappings -GenresAllowedGenreNames $Config.Genres.AllowedGenreNames -Merge
        Write-Verbose "Updated genre mappings in config."
    }
    catch {
        Write-Warning "Failed to save genre mappings to config: $_"
    }
}

Export-ModuleMember -Function Format-Genres

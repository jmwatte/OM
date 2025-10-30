function Get-OMConfig {
    <#
    .SYNOPSIS
    Retrieves OM configuration including API credentials.
    
    .DESCRIPTION
    Loads configuration from user-specific config file or environment variables.
    Searches for config.json in the following order:
    1. $env:OM_CONFIG_PATH (if set)
    2. ~/.OM/config.json (Linux/Mac)
    3. $env:USERPROFILE\.OM\config.json (Windows)
    4. Module directory (for development only - not recommended for production)
    
    .PARAMETER Provider
    Optional. If specified, returns only the configuration for that provider.
    Valid values: 'Spotify', 'Qobuz', 'Discogs'
    
    .EXAMPLE
    $config = Get-OMConfig
    $spotifyId = $config.Spotify.ClientId
    
    .EXAMPLE
    $discogsConfig = Get-OMConfig -Provider Discogs
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('Spotify', 'Qobuz', 'Discogs', 'Google')]
        [string]$Provider
    )

    # Priority 1: Custom config path from environment variable
    if ($env:OM_CONFIG_PATH -and (Test-Path $env:OM_CONFIG_PATH)) {
        $configPath = $env:OM_CONFIG_PATH
        Write-Verbose "Using config from OM_CONFIG_PATH: $configPath"
    }
    else {
        # Priority 2: User-specific config directory
        $userConfigDir = if ($IsLinux -or $IsMacOS) {
            Join-Path $env:HOME '.OM'
        }
        else {
            Join-Path $env:USERPROFILE '.OM'
        }
        
        $configPath = Join-Path $userConfigDir 'config.json'
        
        # Priority 3: Module directory (fallback for development)
        if (-not (Test-Path $configPath)) {
            $moduleRoot = Split-Path -Parent $PSScriptRoot
            $fallbackPath = Join-Path $moduleRoot 'config.json'
            
            if (Test-Path $fallbackPath) {
                Write-Warning "Using config from module directory. Consider moving to: $configPath"
                $configPath = $fallbackPath
            }
        }
    }

    # Load configuration from file and normalize to a hashtable for safe access
    $config = @{}
    if (Test-Path $configPath) {
        try {
            $configContent = Get-Content -Path $configPath -Raw -ErrorAction Stop
            try {
                # Preferred on PS7+: return a hashtable directly
                $config = $configContent | ConvertFrom-Json -AsHashtable -ErrorAction Stop
            }
            catch {
                # Fallback for older PowerShell: parse to PSCustomObject then convert to hashtable
                $tmp = $configContent | ConvertFrom-Json -ErrorAction Stop
                $config = @{}
                if ($tmp -and $tmp.PSObject -and $tmp.PSObject.Properties) {
                    foreach ($p in $tmp.PSObject.Properties) { $config[$p.Name] = $p.Value }
                }
            }
            Write-Verbose "Loaded configuration from: $configPath"
        }
        catch {
            Write-Warning "Failed to load config from $configPath`: $_"
            $config=@{}
        }
    }
    else {
        Write-Verbose "No config file found at: $configPath"
        $config = @{}
    }

    # Merge with environment variables (environment variables take precedence)
    # Spotify
    if ($env:SPOTIFY_CLIENT_ID) {
        if (-not $config.ContainsKey('Spotify')) { $config['Spotify'] = @{} }
        $config['Spotify']['ClientId'] = $env:SPOTIFY_CLIENT_ID
        Write-Verbose "Using Spotify ClientId from environment variable"
    }
    if ($env:SPOTIFY_CLIENT_SECRET) {
        if (-not $config.ContainsKey('Spotify')) { $config['Spotify'] = @{} }
        $config['Spotify']['ClientSecret'] = $env:SPOTIFY_CLIENT_SECRET
        Write-Verbose "Using Spotify ClientSecret from environment variable"
    }

    # Qobuz
    if ($env:QOBUZ_APP_ID) {
        if (-not $config.ContainsKey('Qobuz')) { $config['Qobuz'] = @{} }
        $config['Qobuz']['AppId'] = $env:QOBUZ_APP_ID
        Write-Verbose "Using Qobuz AppId from environment variable"
    }
    if ($env:QOBUZ_SECRET) {
        if (-not $config.ContainsKey('Qobuz')) { $config['Qobuz'] = @{} }
        $config['Qobuz']['Secret'] = $env:QOBUZ_SECRET
        Write-Verbose "Using Qobuz Secret from environment variable"
    }
    if ($env:QOBUZ_LOCALE) {
        if (-not $config.ContainsKey('Qobuz')) { $config['Qobuz'] = @{} }
        # Use consistent property name 'Locale' (culture code), support env var override
        $config['Qobuz']['Locale'] = $env:QOBUZ_LOCALE
        Write-Verbose "Using Qobuz Locale from environment variable"
    }


    # Discogs
    if ($env:DISCOGS_CONSUMER_KEY) {
        if (-not $config.Discogs) { $config.Discogs = @{} }
        $config.Discogs.ConsumerKey = $env:DISCOGS_CONSUMER_KEY
        Write-Verbose "Using Discogs ConsumerKey from environment variable"
    }
    if ($env:DISCOGS_CONSUMER_SECRET) {
        if (-not $config.Discogs) { $config.Discogs = @{} }
        $config.Discogs.ConsumerSecret = $env:DISCOGS_CONSUMER_SECRET
        Write-Verbose "Using Discogs ConsumerSecret from environment variable"
    }
    # Also support legacy DISCOGS_TOKEN for backward compatibility
    if ($env:DISCOGS_TOKEN) {
        if (-not $config.Discogs) { $config.Discogs = @{} }
        $config.Discogs.Token = $env:DISCOGS_TOKEN
        Write-Verbose "Using Discogs Token from environment variable (legacy)"
    }

    # Google Custom Search (optional)
    if ($env:GOOGLE_API_KEY) {
        if (-not $config.Google) { $config.Google = @{} }
        $config.Google.ApiKey = $env:GOOGLE_API_KEY
        Write-Verbose "Using Google API key from environment variable"
    }
    if ($env:GOOGLE_CSE) {
        if (-not $config.Google) { $config.Google = @{} }
        $config.Google.Cse = $env:GOOGLE_CSE
        Write-Verbose "Using Google CSE id from environment variable"
    }

    # Set defaults for missing configurations
    if (-not $config.ContainsKey('Qobuz')) { $config['Qobuz'] = @{} }
    # Backward compatibility: if an older 'QobuzLocale' key is present, map it
    if ($config['Qobuz'].ContainsKey('QobuzLocale') -and -not $config['Qobuz'].ContainsKey('Locale')) {
        $config['Qobuz']['Locale'] = $config['Qobuz']['QobuzLocale']
    }

    # Default to system culture code (e.g. en-US); mapping to the URL form is done by helper functions
    if (-not $config['Qobuz'].ContainsKey('Locale') -or [string]::IsNullOrWhiteSpace($config['Qobuz']['Locale'])) {
        $config['Qobuz']['Locale'] = $PSCulture
    }

    # Cover Art defaults
    if (-not $config.ContainsKey('CoverArt')) { $config['CoverArt'] = @{} }
    if (-not $config['CoverArt'].ContainsKey('FolderImageSize') -or -not $config['CoverArt']['FolderImageSize']) {
        $config['CoverArt']['FolderImageSize'] = 600  # Qobuz max size: 600px
    }
    if (-not $config['CoverArt'].ContainsKey('TagImageSize') -or -not $config['CoverArt']['TagImageSize']) {
        $config['CoverArt']['TagImageSize'] = 150  # Qobuz medium size: 150px
    }

    # Return specific provider or full config
    if ($Provider) {
        # Support both hashtable and PSCustomObject shapes for $config
        $provData = $null
        if ($config -is [hashtable]) {
            if ($config.ContainsKey($Provider)) { $provData = $config[$Provider] }
        }
        else {
            $prop = $config.PSObject.Properties[$Provider]
            if ($prop) { $provData = $prop.Value }
        }

        if ($provData) { return [PSCustomObject]$provData }
        else {
            Write-Warning "No configuration found for provider: $Provider"
            if ($Provider -eq 'Discogs') {
                Write-Warning "Please ensure you have set up the Discogs API credentials."
            }
            elseif ($Provider -eq 'Spotify') {
                Write-Warning "Please ensure you have set up the Spotify API credentials."
            }
            elseif ($Provider -eq 'Google') {
                Write-Warning "Please ensure you have set up the Google search credentials."
            }
            return $null
        }
    }
    else {
        # Convert hashtables to PSCustomObjects for easier property access
        $result = @{ }
        foreach ($key in $config.Keys) {
            $result[$key] = [PSCustomObject]$config[$key]
        }
        return [PSCustomObject]$result
    }
}

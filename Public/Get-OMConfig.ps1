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
        [ValidateSet('Spotify', 'Qobuz', 'Discogs')]
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

    # Load configuration from file
    $config = $null
    if (Test-Path $configPath) {
        try {
            $configContent = Get-Content -Path $configPath -Raw -ErrorAction Stop
            $config = $configContent | ConvertFrom-Json -AsHashtable -ErrorAction Stop
            Write-Verbose "Loaded configuration from: $configPath"
        }
        catch {
            Write-Warning "Failed to load config from $configPath`: $_"
        }
    }
    else {
        Write-Verbose "No config file found at: $configPath"
        $config = @{}
    }

    # Merge with environment variables (environment variables take precedence)
    # Spotify
    if ($env:SPOTIFY_CLIENT_ID) {
        if (-not $config.Spotify) { $config.Spotify = @{} }
        $config.Spotify.ClientId = $env:SPOTIFY_CLIENT_ID
        Write-Verbose "Using Spotify ClientId from environment variable"
    }
    if ($env:SPOTIFY_CLIENT_SECRET) {
        if (-not $config.Spotify) { $config.Spotify = @{} }
        $config.Spotify.ClientSecret = $env:SPOTIFY_CLIENT_SECRET
        Write-Verbose "Using Spotify ClientSecret from environment variable"
    }

    # Qobuz
    if ($env:QOBUZ_APP_ID) {
        if (-not $config.Qobuz) { $config.Qobuz = @{} }
        $config.Qobuz.AppId = $env:QOBUZ_APP_ID
        Write-Verbose "Using Qobuz AppId from environment variable"
    }
    if ($env:QOBUZ_SECRET) {
        if (-not $config.Qobuz) { $config.Qobuz = @{} }
        $config.Qobuz.Secret = $env:QOBUZ_SECRET
        Write-Verbose "Using Qobuz Secret from environment variable"
    }
    if ($env:QOBUZ_LOCALE) {
        if (-not $config.Qobuz) { $config.Qobuz = @{} }
        $config.Qobuz.QobuzLocale = $env:QOBUZ_LOCALE
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

    # Set defaults for missing configurations
    if (-not $config.Qobuz) {
        $config.Qobuz = @{}
    }
    if (-not $config.Qobuz.QobuzLocale) {
        $config.Qobuz.QobuzLocale = Get-QobuzUrlLocale $PSCulture
    }

    # Return specific provider or full config
    if ($Provider) {
        if ($config.$Provider) {
            return [PSCustomObject]$config.$Provider
        }
        else {
            Write-Warning "No configuration found for provider: $Provider"
            return $null
        }
    }
    else {
        # Convert hashtables to PSCustomObjects for easier property access
        $result = @{}
        foreach ($key in $config.Keys) {
            $result[$key] = [PSCustomObject]$config[$key]
        }
        return [PSCustomObject]$result
    }
}

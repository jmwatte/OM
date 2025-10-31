function Set-OMConfig {
    <#
    .SYNOPSIS
    Sets OM configuration values including API credentials.
    
    .DESCRIPTION
    Saves API credentials and configuration to user-specific config file.
    Creates the config directory if it doesn't exist.
    
    Config file location:
    - Linux/Mac: ~/.OM/config.json
    - Windows: %USERPROFILE%\.OM\config.json
    
    .PARAMETER SpotifyClientId
    Spotify API Client ID (from https://developer.spotify.com/dashboard)
    
    .PARAMETER SpotifyClientSecret
    Spotify API Client Secret
    
    .PARAMETER QobuzAppId
    Qobuz API Application ID
    
    .PARAMETER QobuzSecret
    Qobuz API Secret
    
    .PARAMETER QobuzLocale
    Qobuz locale for regional/language preferences (e.g., 'en-US' for US English). Valid values: fr-FR, en-US, en-GB, de-DE, es-ES, it-IT, nl-BE, nl-NL, pt-PT, pt-BR, ja-JP
    
    .PARAMETER DiscogsConsumerKey
    Discogs API Consumer Key (from https://www.discogs.com/settings/developers)
    
    .PARAMETER DiscogsConsumerSecret
    Discogs API Consumer Secret
    
    .PARAMETER DiscogsToken
    Discogs Personal Access Token (legacy/optional - for simple token-based auth)
     
    .PARAMETER GoogleApiKey
    Google API Key for accessing Google Custom Search API (used for fetching release details, track counts, or other metadata when other providers fail).
    Obtain this from the Google Cloud Console: https://console.cloud.google.com/apis/credentials (create a project, enable the Custom Search API, and generate an API key).
    
    .PARAMETER GoogleCse
    Google Custom Search Engine (CSE) ID for targeted searches (e.g., for album/track metadata).
    Create and get this ID from: https://cse.google.com/cse/ (set up a custom search engine, note the "Search engine ID" from the setup page).
    
    .PARAMETER FolderImageSize
    Maximum dimension (width/height) in pixels for cover art saved to album folders. Default: 1000
    
    .PARAMETER TagImageSize
    Maximum dimension (width/height) in pixels for cover art embedded in audio file tags. Default: 500
    
    .PARAMETER DefaultProvider
    Default music provider to use when 'p' is entered in provider selection prompts. Valid values: 'Spotify', 'Qobuz', 'Discogs', 'MusicBrainz'
    
    .PARAMETER ConfigPath
    Optional. Custom path for config file. If not specified, uses default location.
    
    .PARAMETER Merge
    If set, merges new values with existing config. Otherwise, replaces entire provider config.
    
    .EXAMPLE
    Set-OMConfig -SpotifyClientId "abc123" -SpotifyClientSecret "xyz789"
    
    .EXAMPLE
    Set-OMConfig -DiscogsConsumerKey "key123" -DiscogsConsumerSecret "secret456" -Merge
    
    .EXAMPLE
    Set-OMConfig -QobuzAppId "12345" -QobuzSecret "secret" -ConfigPath "C:\custom\config.json"
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $false)]
        [string]$SpotifyClientId,

        [Parameter(Mandatory = $false)]
        [string]$SpotifyClientSecret,

        [Parameter(Mandatory = $false)]
        [string]$QobuzAppId,

        [Parameter(Mandatory = $false)]
        [string]$QobuzSecret,

        [Parameter(Mandatory = $false)]
        [ValidateSet('fr-FR', 'en-US', 'en-GB', 'de-DE', 'es-ES', 'it-IT', 'nl-BE', 'nl-NL', 'pt-PT', 'pt-BR', 'ja-JP')]
        [string]$QobuzLocale,

        [Parameter(Mandatory = $false)]
        [string]$DiscogsConsumerKey,

        [Parameter(Mandatory = $false)]
        [string]$DiscogsConsumerSecret,

        [Parameter(Mandatory = $false)]
        [string]$DiscogsToken,

        [Parameter(Mandatory = $false)]
        [string]$GoogleApiKey,

        [Parameter(Mandatory = $false)]
        [string]$GoogleCse,

        [Parameter(Mandatory = $false)]
        [int]$FolderImageSize,

        [Parameter(Mandatory = $false)]
        [int]$TagImageSize,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Spotify', 'Qobuz', 'Discogs', 'MusicBrainz')]
        [string]$DefaultProvider,

        [Parameter(Mandatory = $false)]
        [string]$ConfigPath,

        [Parameter(Mandatory = $false)]
        [switch]$Merge
    )

    # Determine config file path
    if (-not $ConfigPath) {
    $userConfigDir = if ($IsLinux -or $IsMacOS) {
        Join-Path $env:HOME '.OM'
    } else {
        Join-Path $env:USERPROFILE '.OM'
    }        $ConfigPath = Join-Path $userConfigDir 'config.json'
    }

    # Create directory if it doesn't exist
    $configDir = Split-Path -Parent $ConfigPath
    if (-not (Test-Path $configDir)) {
        if ($PSCmdlet.ShouldProcess($configDir, "Create config directory")) {
            New-Item -Path $configDir -ItemType Directory -Force | Out-Null
            Write-Verbose "Created config directory: $configDir"
        }
    }

    # Load existing config (if present) so we merge new values by default
    $config = @{}
    if (Test-Path $ConfigPath) {
        try {
            $configContent = Get-Content -Path $ConfigPath -Raw -ErrorAction Stop
            $config = $configContent | ConvertFrom-Json -AsHashtable -ErrorAction Stop
            Write-Verbose "Loaded existing config from: $ConfigPath"
        }
        catch {
            Write-Warning "Failed to load existing config, starting fresh: $_"
            $config = @{}
        }
    }

    $modified = $false
    # Update Spotify configuration (merge by default)
    if ($SpotifyClientId -or $SpotifyClientSecret) {
        if (-not $config.Spotify) { $config.Spotify = @{} }
        
        if ($SpotifyClientId) {
            $config.Spotify.ClientId = $SpotifyClientId
            Write-Verbose "Set Spotify ClientId"
            $modified = $true
        }
        if ($SpotifyClientSecret) {
            $config.Spotify.ClientSecret = $SpotifyClientSecret
            Write-Verbose "Set Spotify ClientSecret"
            $modified = $true
        }
    }

    # Update Qobuz configuration (merge by default)
    if ($QobuzAppId -or $QobuzSecret -or $QobuzLocale) {
        if (-not $config.Qobuz) { $config.Qobuz = @{} }
        
        if ($QobuzAppId) {
            $config.Qobuz.AppId = $QobuzAppId
            Write-Verbose "Set Qobuz AppId"
            $modified = $true
        }
        if ($QobuzSecret) {
            $config.Qobuz.Secret = $QobuzSecret
            Write-Verbose "Set Qobuz Secret"
            $modified = $true
        }
        if ($QobuzLocale) {
            $config.Qobuz.Locale = $QobuzLocale
            Write-Verbose "Set Qobuz Locale to $QobuzLocale"
            $modified = $true
        }
    }

    # Update Discogs configuration (merge by default)
    if ($DiscogsConsumerKey -or $DiscogsConsumerSecret -or $DiscogsToken) {
        if (-not $config.Discogs) { $config.Discogs = @{} }
        
        if ($DiscogsConsumerKey) {
            $config.Discogs.ConsumerKey = $DiscogsConsumerKey
            Write-Verbose "Set Discogs ConsumerKey"
            $modified = $true
        }
        if ($DiscogsConsumerSecret) {
            $config.Discogs.ConsumerSecret = $DiscogsConsumerSecret
            Write-Verbose "Set Discogs ConsumerSecret"
            $modified = $true
        }
        if ($DiscogsToken) {
            $config.Discogs.Token = $DiscogsToken
            Write-Verbose "Set Discogs Token (legacy)"
            $modified = $true
        }
    }

    # Update Google Custom Search configuration (merge by default)
    if ($GoogleApiKey -or $GoogleCse) {
        if (-not $config.Google) { $config.Google = @{} }
        if ($GoogleApiKey) {
            $config.Google.ApiKey = $GoogleApiKey
            Write-Verbose "Set Google API key"
            $modified = $true
        }
        if ($GoogleCse) {
            $config.Google.Cse = $GoogleCse
            Write-Verbose "Set Google CSE id"
            $modified = $true
        }
    }

    # Update Cover Art configuration (merge by default)
    if ($FolderImageSize -or $TagImageSize) {
        if (-not $config.CoverArt) { $config.CoverArt = @{} }
        
        if ($FolderImageSize) {
            $config.CoverArt.FolderImageSize = $FolderImageSize
            Write-Verbose "Set CoverArt FolderImageSize to $FolderImageSize"
            $modified = $true
        }
        if ($TagImageSize) {
            $config.CoverArt.TagImageSize = $TagImageSize
            Write-Verbose "Set CoverArt TagImageSize to $TagImageSize"
            $modified = $true
        }
    }

    # Update Default Provider
    if ($DefaultProvider) {
        $config.DefaultProvider = $DefaultProvider
        Write-Verbose "Set DefaultProvider to $DefaultProvider"
        $modified = $true
    }

    # Validate that at least one value was provided
    if (-not $modified) {
        Write-Warning "No configuration values provided. Nothing to save."
        return
    }

    # Save to file
    if ($PSCmdlet.ShouldProcess($ConfigPath, "Save configuration")) {
        try {
            $config | ConvertTo-Json -Depth 10 | Set-Content -Path $ConfigPath -Encoding UTF8 -ErrorAction Stop
            Write-Host "✓ Configuration saved to: $ConfigPath" -ForegroundColor Green
            
            # Set restrictive permissions on config file (contains secrets)
            if ($IsLinux -or $IsMacOS) {
                try {
                    chmod 600 $ConfigPath
                    Write-Verbose "Set file permissions to 600 (user read/write only)"
                }
                catch {
                    Write-Warning "Could not set file permissions: $_"
                }
            }
            else {
                # Windows: Check if running as administrator before attempting to set permissions
                $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
                
                if ($isAdmin) {
                    # Remove inherited permissions and grant only current user full control
                    try {
                        $acl = Get-Acl $ConfigPath
                        $acl.SetAccessRuleProtection($true, $false)  # Disable inheritance, don't copy existing
                        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                            [System.Security.Principal.WindowsIdentity]::GetCurrent().Name,
                            "FullControl",
                            "Allow"
                        )
                        $acl.SetAccessRule($rule)
                        Set-Acl $ConfigPath $acl
                        Write-Verbose "Set restrictive file permissions (current user only)"
                    }
                    catch {
                        Write-Verbose "Could not set restrictive permissions: $($_.Exception.Message)"
                        Write-Verbose "Config file saved successfully but with default permissions"
                    }
                }
                else {
                    Write-Verbose "Skipping restrictive permission setting - requires administrator privileges. Config saved with default permissions, which are usually sufficient for personal use."
                }
            }

            return [PSCustomObject]@{
                ConfigPath = $ConfigPath
                Success = $true
            }
        }
        catch {
            Write-Error "Failed to save configuration: $_"
            return [PSCustomObject]@{
                ConfigPath = $ConfigPath
                Success = $false
                Error = $_
            }
        }
    }
}

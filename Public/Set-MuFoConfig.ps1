function Set-OMConfig {
    <#
    .SYNOPSIS
    Sets MuFo configuration values including API credentials.
    
    .DESCRIPTION
    Saves API credentials and configuration to user-specific config file.
    Creates the config directory if it doesn't exist.
    
    Config file location:
    - Linux/Mac: ~/.mufo/config.json
    - Windows: %USERPROFILE%\.mufo\config.json
    
    .PARAMETER SpotifyClientId
    Spotify API Client ID (from https://developer.spotify.com/dashboard)
    
    .PARAMETER SpotifyClientSecret
    Spotify API Client Secret
    
    .PARAMETER QobuzAppId
    Qobuz API Application ID
    
    .PARAMETER QobuzSecret
    Qobuz API Secret
    
    .PARAMETER DiscogsConsumerKey
    Discogs API Consumer Key (from https://www.discogs.com/settings/developers)
    
    .PARAMETER DiscogsConsumerSecret
    Discogs API Consumer Secret
    
    .PARAMETER DiscogsToken
    Discogs Personal Access Token (legacy/optional - for simple token-based auth)
    
    .PARAMETER ConfigPath
    Optional. Custom path for config file. If not specified, uses default location.
    
    .PARAMETER Merge
    If set, merges new values with existing config. Otherwise, replaces entire provider config.
    
    .EXAMPLE
    Set-MuFoConfig -SpotifyClientId "abc123" -SpotifyClientSecret "xyz789"
    
    .EXAMPLE
    Set-MuFoConfig -DiscogsConsumerKey "key123" -DiscogsConsumerSecret "secret456" -Merge
    
    .EXAMPLE
    Set-MuFoConfig -QobuzAppId "12345" -QobuzSecret "secret" -ConfigPath "C:\custom\config.json"
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
        [string]$DiscogsConsumerKey,

        [Parameter(Mandatory = $false)]
        [string]$DiscogsConsumerSecret,

        [Parameter(Mandatory = $false)]
        [string]$DiscogsToken,

        [Parameter(Mandatory = $false)]
        [string]$ConfigPath,

        [Parameter(Mandatory = $false)]
        [switch]$Merge
    )

    # Determine config file path
    if (-not $ConfigPath) {
        $userConfigDir = if ($IsLinux -or $IsMacOS) {
            Join-Path $env:HOME '.mufo'
        } else {
            Join-Path $env:USERPROFILE '.mufo'
        }
        
        $ConfigPath = Join-Path $userConfigDir 'config.json'
    }

    # Create directory if it doesn't exist
    $configDir = Split-Path -Parent $ConfigPath
    if (-not (Test-Path $configDir)) {
        if ($PSCmdlet.ShouldProcess($configDir, "Create config directory")) {
            New-Item -Path $configDir -ItemType Directory -Force | Out-Null
            Write-Verbose "Created config directory: $configDir"
        }
    }

    # Load existing config or start fresh
    $config = @{}
    if ((Test-Path $ConfigPath) -and $Merge) {
        try {
            $configContent = Get-Content -Path $ConfigPath -Raw -ErrorAction Stop
            $config = $configContent | ConvertFrom-Json -AsHashtable -ErrorAction Stop
            Write-Verbose "Loaded existing config for merging"
        }
        catch {
            Write-Warning "Failed to load existing config, starting fresh: $_"
        }
    }

    # Update Spotify configuration
    if ($SpotifyClientId -or $SpotifyClientSecret) {
        if (-not $config.Spotify) { $config.Spotify = @{} }
        
        if ($SpotifyClientId) {
            $config.Spotify.ClientId = $SpotifyClientId
            Write-Verbose "Set Spotify ClientId"
        }
        if ($SpotifyClientSecret) {
            $config.Spotify.ClientSecret = $SpotifyClientSecret
            Write-Verbose "Set Spotify ClientSecret"
        }
    }

    # Update Qobuz configuration
    if ($QobuzAppId -or $QobuzSecret) {
        if (-not $config.Qobuz) { $config.Qobuz = @{} }
        
        if ($QobuzAppId) {
            $config.Qobuz.AppId = $QobuzAppId
            Write-Verbose "Set Qobuz AppId"
        }
        if ($QobuzSecret) {
            $config.Qobuz.Secret = $QobuzSecret
            Write-Verbose "Set Qobuz Secret"
        }
    }

    # Update Discogs configuration
    if ($DiscogsConsumerKey -or $DiscogsConsumerSecret -or $DiscogsToken) {
        if (-not $config.Discogs) { $config.Discogs = @{} }
        
        if ($DiscogsConsumerKey) {
            $config.Discogs.ConsumerKey = $DiscogsConsumerKey
            Write-Verbose "Set Discogs ConsumerKey"
        }
        if ($DiscogsConsumerSecret) {
            $config.Discogs.ConsumerSecret = $DiscogsConsumerSecret
            Write-Verbose "Set Discogs ConsumerSecret"
        }
        if ($DiscogsToken) {
            $config.Discogs.Token = $DiscogsToken
            Write-Verbose "Set Discogs Token (legacy)"
        }
    }

    # Validate that at least one value was provided
    if ($config.Count -eq 0) {
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
                # Windows: Remove inherited permissions and grant only current user full control
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
                    Write-Verbose "Could not set restrictive permissions (requires elevated privileges): $($_.Exception.Message)"
                    Write-Verbose "Config file saved successfully but with default permissions"
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

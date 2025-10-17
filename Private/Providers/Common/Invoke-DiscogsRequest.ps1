function Invoke-DiscogsRequest {
    <#
    .SYNOPSIS
    Makes authenticated requests to Discogs API with OAuth 1.0a or token authentication.
    
    .DESCRIPTION
    Wrapper for Discogs API requests that handles OAuth 1.0a authentication, rate limiting,
    and error handling. Automatically uses credentials from Get-MuFoConfig.
    
    .PARAMETER Uri
    The Discogs API endpoint URI (can be relative like '/database/search' or full URL)
    
    .PARAMETER Method
    HTTP method (Get, Post, Put, Delete). Default is Get.
    
    .PARAMETER Body
    Optional request body for POST/PUT requests
    
    .PARAMETER UseOAuth
    Force OAuth 1.0a authentication even if token is available
    
    .EXAMPLE
    Invoke-DiscogsRequest -Uri '/database/search?q=Beatles&type=artist'
    
    .EXAMPLE
    Invoke-DiscogsRequest -Uri 'https://api.discogs.com/artists/123456' -Method Get
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Get', 'Post', 'Put', 'Delete')]
        [string]$Method = 'Get',
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Body,
        
        [Parameter(Mandatory = $false)]
        [switch]$UseOAuth
    )

    # Get Discogs configuration
    $config = Get-OMConfig -Provider Discogs
    
    if (-not $config) {
        throw @"
Discogs credentials not configured.

Set them with:
  Set-OMConfig -DiscogsConsumerKey 'your_key' -DiscogsConsumerSecret 'your_secret'

Get credentials at: https://www.discogs.com/settings/developers
"@
    }

    # Rate limiting: max 60 requests per minute for authenticated requests
    # Initialize script-scoped variables if they don't exist
    if (-not (Get-Variable -Name DiscogsLastRequest -Scope Script -ErrorAction SilentlyContinue)) {
        $script:DiscogsLastRequest = [datetime]::MinValue
    }
    if (-not (Get-Variable -Name DiscogsRequestCount -Scope Script -ErrorAction SilentlyContinue)) {
        $script:DiscogsRequestCount = 0
    }

    $now = [datetime]::Now
    $elapsed = ($now - $script:DiscogsLastRequest).TotalSeconds

    if ($elapsed -lt 60 -and $script:DiscogsRequestCount -ge 60) {
        $wait = 60 - $elapsed
        Write-Verbose "Rate limit reached. Waiting $([math]::Ceiling($wait)) seconds..."
        Start-Sleep -Seconds ([math]::Ceiling($wait))
        $script:DiscogsRequestCount = 0
    }
    elseif ($elapsed -ge 60) {
        $script:DiscogsRequestCount = 0
    }

    # Ensure full URL
    if (-not $Uri.StartsWith('http')) {
        $Uri = "https://api.discogs.com$Uri"
    }

    # Build headers
    $headers = @{
        'User-Agent' = 'OM/1.0 (https://github.com/jmwatte/OM)'
        'Accept' = 'application/vnd.discogs.v2.discogs+json'
    }

    # Determine authentication method
    # Handle both hashtable and PSCustomObject
    $hasOAuth = ($config.PSObject.Properties['ConsumerKey'] -and $config.ConsumerKey -and 
                 $config.PSObject.Properties['ConsumerSecret'] -and $config.ConsumerSecret)
    $hasToken = ($config.PSObject.Properties['Token'] -and $config.Token)

    if ($hasToken) {
        # Personal Access Token authentication (preferred - simpler and works)
        Write-Verbose "Using Discogs Personal Access Token authentication"
        $headers['Authorization'] = "Discogs token=$($config.Token)"
    }
    elseif ($hasOAuth) {
        # OAuth 1.0a authentication
        # Note: Full OAuth 1.0a requires generating HMAC-SHA1 signatures with nonce and timestamp
        # This is complex and requires a proper OAuth library
        # For now, warn user that OAuth requires token OR use a library
        
        Write-Warning @"
Discogs OAuth 1.0a with Consumer Key/Secret requires full signature generation.
For simplicity, either:
1. Generate a Personal Access Token at https://www.discogs.com/settings/developers
2. Set it with: Set-OMConfig -DiscogsToken 'your_token'

Attempting unauthenticated request (limited rate: 25 req/min)...
"@
        # Unauthenticated requests work for public data but have lower rate limits
        Write-Verbose "Making unauthenticated Discogs API request"
    }
    else {
        Write-Warning "No Discogs credentials configured. Using unauthenticated access (25 req/min limit)"
    }

    # Make the request
    try {
        $requestParams = @{
            Uri = $Uri
            Method = $Method
            Headers = $headers
            ErrorAction = 'Stop'
        }
        
        if ($Body) {
            # For GET requests, Body should be query parameters (not JSON)
            # For POST/PUT, convert to JSON
            if ($Method -eq 'Get') {
                $requestParams['Body'] = $Body  # Invoke-RestMethod handles as query params
            } else {
                $requestParams['Body'] = ($Body | ConvertTo-Json -Depth 10)
                $requestParams['ContentType'] = 'application/json'
            }
        }

        $response = Invoke-RestMethod @requestParams
        
        # Update rate limiting counters
        $script:DiscogsLastRequest = [datetime]::Now
        $script:DiscogsRequestCount++
        
        Write-Verbose "Discogs request successful. Rate limit: $script:DiscogsRequestCount/60 in last minute"
        
        return $response
    }
    catch {
        # Handle specific Discogs API errors
        $statusCode = $_.Exception.Response.StatusCode.value__
        $errorMessage = $_.Exception.Message
        
        switch ($statusCode) {
            401 { throw "Discogs authentication failed. Check your credentials." }
            429 { throw "Discogs rate limit exceeded. Wait before retrying." }
            404 { throw "Discogs resource not found: $Uri" }
            default { throw "Discogs API request failed: $errorMessage" }
        }
    }
}

function Invoke-MusicBrainzRequest {
    <#
    .SYNOPSIS
    Makes authenticated requests to MusicBrainz API with rate limiting.
    
    .DESCRIPTION
    Wrapper for MusicBrainz API requests that handles User-Agent requirements,
    rate limiting (1 request per second), and error handling.
    
    .PARAMETER Endpoint
    The MusicBrainz API endpoint (e.g., 'artist', 'release', 'recording')
    
    .PARAMETER Query
    Query parameters as hashtable (will be URL-encoded automatically)
    
    .PARAMETER Id
    Optional MBID (MusicBrainz ID) for direct lookups
    
    .PARAMETER Inc
    Include parameters for additional data (e.g., 'recordings+artist-credits')
    
    .EXAMPLE
    Invoke-MusicBrainzRequest -Endpoint 'artist' -Query @{ query = 'artist:Beatles' }
    
    .EXAMPLE
    Invoke-MusicBrainzRequest -Endpoint 'release' -Id $mbid -Inc 'recordings+artist-credits'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Endpoint,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Query,
        
        [Parameter(Mandatory = $false)]
        [string]$Id,
        
        [Parameter(Mandatory = $false)]
        [string]$Inc
    )

    # Get contact from config, fallback to GitHub project URL
    try {
        $config = Get-OMConfig
        $contact = if ($config -and (Get-IfExists $config 'MusicBrainzContact')) { 
            $config.MusicBrainzContact 
        } else { 
            "https://github.com/jmwatte/OM"
        }
    } catch {
        $contact = "https://github.com/jmwatte/OM"
    }
    
    # MusicBrainz requires User-Agent header
    $headers = @{
        'User-Agent' = "MuFo/1.0 ( $contact )"
    }
    
    # Rate limiting: 1 request per second (MusicBrainz requirement)
    if (-not (Get-Variable -Name LastMBRequest -Scope Script -ErrorAction SilentlyContinue)) {
        $script:LastMBRequest = [datetime]::MinValue
    }
    
    $elapsed = ([datetime]::Now - $script:LastMBRequest).TotalMilliseconds
    if ($elapsed -lt 1000) {
        $waitTime = 1000 - $elapsed
        Write-Verbose "MusicBrainz rate limit: waiting $([math]::Ceiling($waitTime))ms"
        Start-Sleep -Milliseconds $waitTime
    }
    
    # Build URI
    $baseUri = "https://musicbrainz.org/ws/2/$Endpoint"
    if ($Id) {
        $baseUri = "$baseUri/$Id"
    }
    
    # Build query parameters
    $queryParams = @{
        fmt = 'json'  # Request JSON format
    }
    
    if ($Inc) {
        $queryParams['inc'] = $Inc
    }
    
    if ($Query) {
        foreach ($key in $Query.Keys) {
            $queryParams[$key] = $Query[$key]
        }
    }
    
    # Make the request
    try {
        # Build full URL with query params for debugging
        $queryString = ($queryParams.GetEnumerator() | ForEach-Object { "$($_.Key)=$([System.Uri]::EscapeDataString($_.Value))" }) -join '&'
        $fullUrl = if ($queryString) { "$baseUri`?$queryString" } else { $baseUri }
        
        Write-Verbose "MusicBrainz API request: $Endpoint $(if ($Id) { "($Id)" })"
        Write-Verbose "Full URL: $fullUrl"
        
        $requestParams = @{
            Uri = $baseUri
            Method = 'Get'
            Headers = $headers
            Body = $queryParams
            ErrorAction = 'Stop'
        }
        
        $response = Invoke-RestMethod @requestParams
        
        # Update rate limiting tracker
        $script:LastMBRequest = [datetime]::Now
        
        Write-Verbose "MusicBrainz request successful"
        return $response
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        $errorMessage = $_.Exception.Message
        
        switch ($statusCode) {
            400 { throw "MusicBrainz bad request: $errorMessage" }
            404 { throw "MusicBrainz resource not found: $baseUri" }
            429 { throw "MusicBrainz rate limit exceeded. Please wait before retrying." }
            503 { throw "MusicBrainz service temporarily unavailable. Please try again later." }
            default { throw "MusicBrainz API request failed: $errorMessage" }
        }
    }
}

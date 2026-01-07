function Switch-OMProvider {
    <#
    .SYNOPSIS
        Switches the current provider based on user input shortcode.
    
    .DESCRIPTION
        Parses provider shortcodes (ps, pq, pd, pm) and returns the provider name.
        Returns $null if the input is not a recognized provider shortcode.
    
    .PARAMETER Input
        The user input to check for provider switch codes.
    
    .PARAMETER Context
        The OM context object for displaying messages.
    
    .PARAMETER Silent
        If specified, does not show the "Switched to provider" message.
    
    .OUTPUTS
        String - The provider name if input was a provider shortcode, or $null otherwise.
    
    .EXAMPLE
        $newProvider = Switch-OMProvider -Input 'ps' -Context $Context
        # Returns 'Spotify' and shows message
    
    .EXAMPLE
        $newProvider = Switch-OMProvider -Input 'hello' -Context $Context
        # Returns $null (not a provider shortcode)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Input,
        
        [Parameter()]
        [hashtable]$Context,
        
        [Parameter()]
        [switch]$Silent
    )
    
    $provider = switch ($Input.ToLower()) {
        'ps' { 'Spotify' }
        'pq' { 'Qobuz' }
        'pd' { 'Discogs' }
        'pm' { 'MusicBrainz' }
        default { $null }
    }
    
    if ($provider -and -not $Silent) {
        Show-Message -Message "Switched to provider: $provider" -ForegroundColor Green -Context $Context
    }
    
    return $provider
}

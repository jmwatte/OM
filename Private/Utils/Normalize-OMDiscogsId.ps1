function Normalize-OMDiscogsId {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$InputId
    )
    
    Write-Verbose "Normalizing Discogs ID: $InputId"
    
    $id = $InputId.Trim()
    
    # Remove brackets if present: [r2388472] → r2388472, [m1764178] → m1764178
    $id = $id -replace '^\[|\]$', ''
    
    return $id
}

function ConvertTo-DiscogsId {
    <#
    .SYNOPSIS
        Normalizes a Discogs ID by removing brackets.

    .DESCRIPTION
        Takes a Discogs ID (release or master) and normalizes it by:
        - Trimming whitespace
        - Removing surrounding brackets: [r2388472] → r2388472

    .PARAMETER InputId
        The Discogs ID to normalize.

    .EXAMPLE
        ConvertTo-DiscogsId -InputId "[r2388472]"
        # Returns: r2388472

    .EXAMPLE
        ConvertTo-DiscogsId -InputId "m1764178"
        # Returns: m1764178
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$InputId
    )

    $id = $InputId.Trim()
    
    # Remove brackets if present: [r2388472] → r2388472, [m1764178] → m1764178
    $id = $id -replace '^\[|\]$', ''
    
    return $id
}

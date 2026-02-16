function Undo-PathSanitization {
    <#
    .SYNOPSIS
        Reverses common sanitization artifacts from folder names for use in search queries.

    .DESCRIPTION
        When Approve-PathSegment sanitizes names for the filesystem (replacing : \ / with _),
        the resulting folder names contain underscores that degrade search API results.
        This function performs a best-effort reverse: replacing underscores with spaces and
        collapsing whitespace, so provider searches get cleaner queries.

        This is intentionally lossy — we cannot know if the original had a colon, slash,
        or actual underscore. The goal is improved search hit rates, not perfect restoration.

    .PARAMETER Name
        The folder-derived name to clean up for search use.

    .OUTPUTS
        String — cleaned name suitable for provider API queries.

    .EXAMPLE
        Undo-PathSanitization -Name 'Tchaikovsky_ Symphonies'
        # Returns: 'Tchaikovsky Symphonies'

    .EXAMPLE
        Undo-PathSanitization -Name 'TRON_ Legacy'
        # Returns: 'TRON Legacy'

    .EXAMPLE
        'AC_DC' | Undo-PathSanitization
        # Returns: 'AC DC'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [AllowEmptyString()]
        [string]$Name
    )

    process {
        if ([string]::IsNullOrWhiteSpace($Name)) { return $Name }

        $result = $Name

        # Replace underscores with spaces (primary sanitization artifact)
        $result = $result -replace '_', ' '

        # Collapse multiple spaces into one
        $result = $result -replace '\s{2,}', ' '

        # Trim leading/trailing whitespace
        $result = $result.Trim()

        return $result
    }
}

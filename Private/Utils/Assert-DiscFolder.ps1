function Assert-DiscFolder {
    <#
    .SYNOPSIS
        Tests if a folder name matches disc/CD folder patterns.

    .DESCRIPTION
        Returns $true if the folder name matches patterns like:
        Disc1, Disc 1, Disc 01, CD1, CD 1, CD01, Disk1, Disk 1, Disk01, etc.

    .PARAMETER FolderName
        The folder name to test.

    .EXAMPLE
        Assert-DiscFolder -FolderName "Disc 1"
        # Returns: $true

    .EXAMPLE
        Assert-DiscFolder -FolderName "Bonus Tracks"
        # Returns: $false
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$FolderName
    )

    # Match patterns: Disc1, Disc 1, Disc 01, CD1, CD 1, CD01, Disk1, Disk 1, Disk01, etc.
    return $FolderName -match '^\s*(Disc|CD|Disk)\s*\d+\s*$'
}

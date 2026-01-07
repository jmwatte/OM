function ConvertTo-AlbumArtistString {
    <#
    .SYNOPSIS
        Converts a ManualAlbumArtist value to a string, handling arrays and other types.
    
    .DESCRIPTION
        Ensures the AlbumArtist value is properly converted to a string for use in tag parameters.
        Handles string, array, and other object types.
    
    .PARAMETER Value
        The ManualAlbumArtist value to convert.
    
    .OUTPUTS
        String representation of the album artist.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Value
    )

    if ($Value -is [string]) {
        return $Value
    }
    elseif ($Value -is [array]) {
        return $Value -join '; '
    }
    else {
        return $Value.ToString()
    }
}

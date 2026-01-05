function Get-OMTagFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    # Wrapper around TagLib to allow mocking in tests
    return [TagLib.File]::Create($FilePath)
}
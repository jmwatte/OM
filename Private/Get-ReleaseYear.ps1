function Get-ReleaseYear {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)]$ReleaseDate)

    if ($ReleaseDate -is [datetime]) { return $ReleaseDate.Year }
    if (-not $ReleaseDate) { return '' }

    $s = [string]$ReleaseDate
    if ($s -match '^(?<y>\d{4})') { return $matches.y }

    try { return ([datetime]::Parse($s)).Year } catch { return '' }
}
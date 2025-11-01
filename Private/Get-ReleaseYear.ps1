function Get-ReleaseYear {
    [CmdletBinding()]
    param([Parameter(Mandatory = $false)]$ReleaseDate)

    if ($ReleaseDate -is [datetime]) { return $ReleaseDate.Year }
    if (-not $ReleaseDate) { return '0000' }

    $s = [string]$ReleaseDate

    # Look for 4-digit years anywhere in the string
    if ($s -match '(?<y>\d{4})') {
        $year = [int]$matches.y
        # Validate that it's a reasonable year (1900-2030)
        if ($year -ge 1900 -and $year -le 2030) {
            return $year
        }
    }

    # Try parsing as datetime with current culture
    try {
        return ([datetime]::Parse($s, [System.Globalization.CultureInfo]::CurrentCulture)).Year
    } catch {
        # Try with invariant culture as fallback
        try {
            return ([datetime]::Parse($s, [System.Globalization.CultureInfo]::InvariantCulture)).Year
        } catch {
            return '0000'
        }
    }
}
function Get-ReleaseYear {
    [CmdletBinding()]
    param([Parameter(Mandatory = $false)]$ReleaseDate)

    if ($ReleaseDate -is [datetime]) { return [int]$ReleaseDate.Year }
    if (-not $ReleaseDate) { return [int]0 }

    $s = [string]$ReleaseDate

    # Look for 4-digit years anywhere in the string
    if ($s -match '(?<y>\d{4})') {
        $year = [int]$matches.y
        # Validate that it's a reasonable year (1900-2099)
        if ($year -ge 1900 -and $year -le 2099) {
            return [int]$year
        }
    }

    # Try parsing as datetime with current culture
    try {
        return [int]([datetime]::Parse($s, [System.Globalization.CultureInfo]::CurrentCulture)).Year
    } catch {
        # Try with invariant culture as fallback
        try {
            return [int]([datetime]::Parse($s, [System.Globalization.CultureInfo]::InvariantCulture)).Year
        } catch {
            return [int]0
        }
    }
}
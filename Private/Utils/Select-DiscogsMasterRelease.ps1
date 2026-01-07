function Select-DiscogsMasterRelease {
    <#
    .SYNOPSIS
        Display and select a release from a Discogs master release.

    .DESCRIPTION
        Shows a list of releases for a Discogs master and handles user selection.
        Returns the selected release or navigation action.

    .PARAMETER MasterName
        The name of the master release to display.

    .PARAMETER MasterId
        The Discogs master ID (for fetching main_release).

    .PARAMETER Releases
        Array of release objects from the master.

    .PARAMETER Context
        The OM context object for display operations.

    .OUTPUTS
        Hashtable with:
        - Action: 'Selected', 'Back', or 'Continue'
        - SelectedRelease: The selected release object (if Action='Selected')
        - ProviderAlbum: Updated album object with release info (if Action='Selected')
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$MasterName,

        [Parameter(Mandatory)]
        [string]$MasterId,

        [Parameter(Mandatory)]
        [array]$Releases,

        [Parameter()]
        [object]$Context
    )

    $result = @{
        Action = 'Continue'
        SelectedRelease = $null
        ProviderAlbum = $null
    }

    # Clear screen and show header
    if ($VerbosePreference -ne 'Continue') { Clear-Host }
    Show-Message -Message "📀 Discogs MASTER: $MasterName" -ForegroundColor Yellow -Context $Context
    Show-Message -Message "Found $($Releases.Count) releases:`n" -ForegroundColor Cyan -Context $Context
    
    # Display releases (max 20)
    for ($i = 0; $i -lt [Math]::Min(20, $Releases.Count); $i++) {
        $rel = $Releases[$i]
        $country = if (Get-IfExists $rel 'country') { " [$($rel.country)]" } else { "" }
        $format = if (Get-IfExists $rel 'format') { " - $($rel.format)" } else { "" }
        $label = if (Get-IfExists $rel 'label') { " ($($rel.label))" } else { "" }
        Show-Message -Message "[$($i+1)] $($rel.title)$country$format$label" -ForegroundColor Gray -Context $Context
    }
    
    if ($Releases.Count -gt 20) {
        Show-Message -Message "... and $($Releases.Count - 20) more" -ForegroundColor DarkGray -Context $Context
    }
    
    # Get user selection
    $relInput = Show-OMPrompt -Prompt "Select release [1-$($Releases.Count)], [0] for main_release, 'b' for album list, or Enter for #1" -Context $Context
    
    # Handle 'back' action
    if ($relInput -eq 'b') {
        $result.Action = 'Back'
        return $result
    }
    
    # Determine selected release
    $selectedRelease = $null
    
    if ($relInput -eq '') {
        # Default to first release
        $selectedRelease = $Releases[0]
    }
    elseif ($relInput -eq '0' -or $relInput -eq 'main') {
        # Fetch main_release from master
        try {
            $masterDetails = Invoke-DiscogsRequest -Uri "/masters/$MasterId"
            if ($masterDetails -and (Get-IfExists $masterDetails 'main_release')) {
                $mainReleaseId = [string]$masterDetails.main_release
                Show-Message -Message "Using main_release: $mainReleaseId" -ForegroundColor Green -Context $Context
                $selectedRelease = @{ id = $mainReleaseId; title = $MasterName }
            }
            else {
                Write-Warning "Master has no main_release, using first release"
                $selectedRelease = $Releases[0]
            }
        }
        catch {
            Write-Warning "Failed to fetch main_release: $_. Using first release."
            $selectedRelease = $Releases[0]
        }
    }
    elseif ($relInput -match '^\d+$') {
        $idx = [int]$relInput
        if ($idx -ge 1 -and $idx -le $Releases.Count) {
            $selectedRelease = $Releases[$idx - 1]
        }
        else {
            Write-Warning "Invalid selection, using first release"
            $selectedRelease = $Releases[0]
        }
    }
    else {
        Write-Warning "Invalid input, using first release"
        $selectedRelease = $Releases[0]
    }
    
    # Build result
    Show-Message -Message "✓ Selected release: $($selectedRelease.id) - $($selectedRelease.title)" -ForegroundColor Green -Context $Context
    
    $result.Action = 'Selected'
    $result.SelectedRelease = $selectedRelease
    $result.ProviderAlbum = @{
        id                  = [string]$selectedRelease.id
        name                = $selectedRelease.title
        type                = 'release'
        _resolvedFromMaster = $MasterId
        _masterReleases     = $Releases
        _masterName         = $MasterName
    }
    
    return $result
}

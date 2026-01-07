function Join-PathSafe {
    <#
    .SYNOPSIS
        Safe wrapper around Join-Path that validates inputs.
    
    .DESCRIPTION
        Ensures both Parent and Child paths are non-empty before calling Join-Path,
        preventing prompting behavior when child path is empty.
    
    .PARAMETER Parent
        The parent path.
    
    .PARAMETER Child
        The child path to join.
    
    .OUTPUTS
        The combined path.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Parent,
        
        [Parameter(Mandatory = $true)]
        [string]$Child
    )
    
    if ([string]::IsNullOrWhiteSpace($Parent)) { 
        throw "Join-PathSafe: Parent path is empty" 
    }
    if ([string]::IsNullOrWhiteSpace($Child)) { 
        throw "Join-PathSafe: Child path is empty" 
    }
    
    return Join-Path -Path $Parent -ChildPath $Child
}

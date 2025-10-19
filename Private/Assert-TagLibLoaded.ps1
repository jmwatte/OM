function Assert-TagLibLoaded {
    <#
    .SYNOPSIS
        Ensure TagLib-Sharp is loaded into the current session.

    .DESCRIPTION
        Checks whether TagLib is already available. If not, searches several sensible
        locations (module lib folder relative to this file, installed module base,
        PSModulePath, and the NuGet cache) for TagLib.dll and tries to load it.
        Returns $true when TagLib is available, $false otherwise (or throws when -ThrowOnError).
    .PARAMETER ThrowOnError
        Throw a terminating error if TagLib cannot be found or loaded.
    #>
    [CmdletBinding()]
    param(
        [switch]$ThrowOnError
    )

    begin {
        $savedEAP = $ErrorActionPreference
        $ErrorActionPreference = 'Stop'
    }

    process {
        try {
            # Quick type check
            try {
                if ([System.Type]::GetType('TagLib.File, TagLib', $false, $false)) {
                    Write-Verbose "TagLib.File type already available in session."
                    return $true
                }
            } catch {
                # ignore and continue
                Write-Verbose "Type-level check threw: $($_.Exception.Message)"
            }

            $candidates = New-Object System.Collections.Generic.List[string]

            # 1) Try to determine module root from the script file that defines this function
            $invPath = $MyInvocation.MyCommand.Path
            if (-not $invPath) {
                # fallback to PSScriptRoot if available
                $invPath = if ($PSScriptRoot) { Join-Path $PSScriptRoot '' } else { $null }
            }

            if ($invPath) {
                # If script is in ...\Private\<file>, go up one level to module root
                $privateDir = Split-Path -Parent $invPath
                if ($privateDir) {
                    $moduleRootFromScript = Split-Path -Parent $privateDir
                    if ($moduleRootFromScript) {
                        $libPath = Join-Path $moduleRootFromScript 'lib\TagLib.dll'
                        if (Test-Path -LiteralPath $libPath) {
                            $candidates.Add((Resolve-Path -LiteralPath $libPath).ProviderPath)
                            Write-Verbose "Found candidate (module lib): $libPath"
                        }

                        # search moduleRoot\lib recursively
                        $libDir = Join-Path $moduleRootFromScript 'lib'
                        if (Test-Path -LiteralPath $libDir) {
                            Get-ChildItem -Path $libDir -Filter 'TagLib*.dll' -File -Recurse -ErrorAction SilentlyContinue |
                                ForEach-Object { $candidates.Add($_.FullName); Write-Verbose "Found candidate in lib subtree: $($_.FullName)" }
                        }
                    }
                }
            } else {
                Write-Verbose "MyInvocation path and PSScriptRoot not available; will try Get-Module and PSModulePath fallbacks."
            }

            # 2) Try Get-Module to find installed module base
            try {
                $mod = Get-Module -Name MuFo -ListAvailable | Select-Object -First 1
                if ($mod) {
                    $modLib = Join-Path $mod.ModuleBase 'lib\TagLib.dll'
                    if (Test-Path -LiteralPath $modLib) {
                        $candidates.Add((Resolve-Path -LiteralPath $modLib).ProviderPath)
                        Write-Verbose "Found candidate (module installed): $modLib"
                    }

                    # also search module base recursively
                    Get-ChildItem -Path $mod.ModuleBase -Filter 'TagLib*.dll' -File -Recurse -ErrorAction SilentlyContinue |
                        ForEach-Object { $candidates.Add($_.FullName); Write-Verbose "Found candidate under module base: $($_.FullName)" }
                }
            } catch {
                Write-Verbose "Get-Module check failed: $($_.Exception.Message)"
            }

            # 3) Try PSModulePath (common locations)
            foreach ($p in ($env:PSModulePath -split ';' | Where-Object { $_ -and (Test-Path $_) })) {
                $maybe = Join-Path $p 'MuFo\lib\TagLib.dll'
                if (Test-Path -LiteralPath $maybe) {
                    $candidates.Add((Resolve-Path -LiteralPath $maybe).ProviderPath)
                    Write-Verbose "Found candidate (PSModulePath): $maybe"
                }
            }

            # 4) NuGet packages cache fallback
            try {
                $nugetRoot = Join-Path $env:USERPROFILE '.nuget\packages'
                if (Test-Path -LiteralPath $nugetRoot) {
                    $found = Get-ChildItem -Path $nugetRoot -Filter 'TagLib.dll' -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
                    if ($found) {
                        $candidates.Add($found.FullName)
                        Write-Verbose "Found candidate (nuget cache): $($found.FullName)"
                    }
                }
            } catch {
                Write-Verbose "NuGet search failed: $($_.Exception.Message)"
            }

            # Unique the candidates and ensure they exist
            $candidates = $candidates | Select-Object -Unique | Where-Object { Test-Path -LiteralPath $_ }

            if (-not $candidates -or $candidates.Count -eq 0) {
                $msg = "TagLib.dll not found in module lib folder or fallbacks. Searched module lib, installed module base, PSModulePath and NuGet cache."
                Write-Verbose $msg
                if ($ThrowOnError) { throw $msg } else { return $false }
            }

            # Attempt to load each candidate
            foreach ($path in $candidates) {
                try {
                    Write-Verbose "Attempting to load TagLib from: $path"
                    Add-Type -Path $path -ErrorAction Stop

                    # verify type
                    if ([System.Type]::GetType('TagLib.File, TagLib', $false, $false)) {
                        Write-Verbose "TagLib loaded successfully from: $path"
                        return $true
                    } else {
                        # try referencing the type directly as a final check
                        try { [void][TagLib.File]; Write-Verbose "TagLib type now available after Add-Type ($path)"; return $true } catch { Write-Verbose "Type still unavailable after Add-Type ($path): $($_.Exception.Message)" }
                    }
                } catch {
                    Write-Verbose "Add-Type failed for '$path': $($_.Exception.Message)"
                    # continue to next candidate
                }
            }

            $finalMsg = "Failed to load TagLib from any candidate path."
            Write-Verbose $finalMsg
            if ($ThrowOnError) { throw $finalMsg } else { return $false }
        } finally {
            $ErrorActionPreference = $savedEAP
        }
    } # process
}
function Install-TagLibSharp {
<#
.SYNOPSIS
    Helper function to install TagLib-Sharp for MuFo track tagging functionality.

.DESCRIPTION
    This function attempts to install TagLib-Sharp using various methods and validates
    the installation. It provides user-friendly feedback and handles common installation issues.

.PARAMETER Force
    Force reinstallation even if TagLib-Sharp is already available.

.PARAMETER Scope
    Installation scope: 'AllUsers' or 'CurrentUser'. Default is 'CurrentUser'.

.EXAMPLE
    Install-TagLibSharp
    
    Installs TagLib-Sharp for the current user.

.EXAMPLE
    Install-TagLibSharp -Force -Scope AllUsers
    
    Forces reinstallation for all users.

.NOTES
    This is a helper function for MuFo's track tagging capabilities.
    Author: jmw
#>
    [CmdletBinding()]
    param(
        [switch]$Force,
        
        [ValidateSet('AllUsers', 'CurrentUser')]
        [string]$Scope = 'CurrentUser'
    )
    #make this print only with verbose
    Write-Verbose "Starting TagLib-Sharp installation process..."
    #Write-Host "=== TagLib-Sharp Installation Helper ===" -ForegroundColor Cyan
    
    # Check if already installed (unless forcing)
    if (-not $Force) {
        $existing = [System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.FullName -like '*TagLib*' }
        if ($existing) {
            Write-Host "✓ TagLib-Sharp is already loaded in current session" -ForegroundColor Green
            return
        }
        
        # Check for installed packages
        $installedPaths = @(
            "$env:USERPROFILE\.nuget\packages\taglib*\lib\*\TagLib.dll",
            "$env:USERPROFILE\.nuget\packages\taglibsharp*\lib\*\TagLib.dll"
        )
        
        $found = $false
        foreach ($path in $installedPaths) {
            $dll = Get-ChildItem -Path $path -Recurse -ErrorAction SilentlyContinue | 
                   Where-Object { $_.Name -eq 'TagLib.dll' } | 
                   Select-Object -First 1
            if ($dll) {
                Write-Host "✓ TagLib-Sharp found at: $($dll.FullName)" -ForegroundColor Green
                $found = $true
                break
            }
        }
        
        if ($found) {
            Write-Host "TagLib-Sharp is available. Run Read-AudioFileTags or Get-OMTags to use it." -ForegroundColor Green
            return
        }
    }
    
    # Attempt installation
    Write-Host "Installing TagLib-Sharp..." -ForegroundColor Yellow
    
    $installSuccess = $false
    
    try {
        # Method 1: Setup NuGet provider and install properly
        Write-Host "Setting up NuGet provider for TagLib-Sharp installation..." -ForegroundColor Yellow
        
        # Ensure NuGet provider is available
        $nugetProvider = Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue
        if (-not $nugetProvider) {
            Write-Host "Installing NuGet provider..." -ForegroundColor Cyan
            Find-PackageProvider -Name NuGet | Install-PackageProvider -Force -Scope $Scope
        }
        
        # Register nuget.org source if not already registered
        $nugetSource = Get-PackageSource -Name "nuget.org" -ErrorAction SilentlyContinue
        if (-not $nugetSource) {
            Write-Host "Registering NuGet package source..." -ForegroundColor Cyan
            Register-PackageSource -Name "nuget.org" -Location "https://www.nuget.org/api/v2" -ProviderName NuGet -Force
        }
        
        # Create destination folder in module directory
        $moduleDir = Split-Path $PSScriptRoot -Parent
        $libDir = Join-Path $moduleDir "lib"
        if (-not (Test-Path $libDir)) {
            New-Item -ItemType Directory -Path $libDir -Force | Out-Null
        }
        
        # Find and install TagLibSharp package
        Write-Host "Locating TagLibSharp package..." -ForegroundColor Cyan
        $package = Find-Package -ProviderName NuGet -Name TagLibSharp -ErrorAction Stop
        Write-Host "Found TagLibSharp version: $($package.Version)" -ForegroundColor Green
        
        # Install to our lib directory
        Write-Host "Installing TagLibSharp to module directory..." -ForegroundColor Cyan
        Install-Package -InputObject $package -Destination $libDir -Force -ErrorAction Stop
        
        # Find the installed TagLib.dll
        $installedDll = Get-ChildItem -Path $libDir -Name "TagLib.dll" -Recurse | Select-Object -First 1
        if ($installedDll) {
            $dllPath = Join-Path $libDir $installedDll
            Write-Host "✓ TagLib-Sharp installed successfully to: $dllPath" -ForegroundColor Green
            $installSuccess = $true
        } else {
            throw "TagLib.dll not found after installation"
        }
    }
    catch {
        Write-Warning "NuGet provider installation failed: $($_.Exception.Message)"
        
        # Method 2: Fallback to PackageManagement
        try {
            Write-Host "Trying PackageManagement fallback..." -ForegroundColor Yellow
            
            $installParams = @{
                Name = 'TagLibSharp'
                Scope = $Scope
                Force = $Force
                SkipDependencies = $true
                ProviderName = 'NuGet'
                ErrorAction = 'Stop'
            }
            
            Install-Package @installParams
            $installSuccess = $true
            Write-Host "✓ TagLib-Sharp installed via PackageManagement" -ForegroundColor Green
        }
        catch {
            Write-Warning "PackageManagement fallback failed: $($_.Exception.Message)"
            
            # Method 3: Download from GitHub releases (preferred direct method)
            try {
                Write-Host "Downloading TagLib-Sharp from GitHub releases..." -ForegroundColor Yellow
                
                # Get the latest release from GitHub API
                $apiUrl = "https://api.github.com/repos/mono/taglib-sharp/releases/latest"
                $releaseInfo = Invoke-RestMethod -Uri $apiUrl -ErrorAction Stop
                
                # Find the source code zip
                $downloadUrl = $releaseInfo.zipball_url
                Write-Host "Found latest release: $($releaseInfo.tag_name)" -ForegroundColor Cyan
                
                $tempZip = "$env:TEMP\TagLibSharp-GitHub.zip"
                $moduleDir = Split-Path $PSScriptRoot -Parent  # Get MuFo module root
                $libDir = Join-Path $moduleDir "lib"
                
                # Create lib directory if it doesn't exist
                if (-not (Test-Path $libDir)) {
                    New-Item -ItemType Directory -Path $libDir -Force | Out-Null
                }
                
                # Download the release
                Write-Host "Downloading from: $downloadUrl" -ForegroundColor Gray
                Invoke-WebRequest -Uri $downloadUrl -OutFile $tempZip -ErrorAction Stop
                
                # Extract to temp location
                $tempExtract = "$env:TEMP\TagLibSharp_GitHub_Extract"
                if (Test-Path $tempExtract) {
                    Remove-Item $tempExtract -Recurse -Force
                }
                
                # Extract using .NET
                Add-Type -AssemblyName System.IO.Compression.FileSystem
                [System.IO.Compression.ZipFile]::ExtractToDirectory($tempZip, $tempExtract)
                
                # Find the compiled TagLib.dll (look in bin/Debug or bin/Release directories)
                $possiblePaths = @(
                    "src\bin\Release\*\TagLib.dll",
                    "src\bin\Debug\*\TagLib.dll", 
                    "**\TagLib.dll"
                )
                
                $tagLibDll = $null
                foreach ($pattern in $possiblePaths) {
                    $tagLibDll = Get-ChildItem -Path $tempExtract -Filter "TagLib.dll" -Recurse -ErrorAction SilentlyContinue | 
                                 Select-Object -First 1
                    if ($tagLibDll) { break }
                }
                
                if ($tagLibDll) {
                    $destDll = Join-Path $libDir "TagLib.dll"
                    Copy-Item $tagLibDll.FullName $destDll -Force
                    Write-Host "✓ TagLib.dll installed from GitHub to: $destDll" -ForegroundColor Green
                    $installSuccess = $true
                } else {
                    # If no compiled DLL found, this is source code - need to inform user
                    Write-Warning "GitHub release contains source code, not compiled binaries."
                    throw "No compiled TagLib.dll found in GitHub release"
                }
                
                # Clean up
                Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
                Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
            }
            catch {
                Write-Warning "GitHub installation failed: $($_.Exception.Message)"
                
                # Method 4: Download directly from NuGet API (fallback)
                try {
                    Write-Host "Downloading TagLib-Sharp directly from NuGet..." -ForegroundColor Yellow
                    
                    $nugetUrl = "https://www.nuget.org/api/v2/package/TagLibSharp"
                    $tempZip = "$env:TEMP\TagLibSharp-NuGet.zip"
                    $moduleDir = Split-Path $PSScriptRoot -Parent  # Get MuFo module root
                    $libDir = Join-Path $moduleDir "lib"
                    
                    # Create lib directory if it doesn't exist
                    if (-not (Test-Path $libDir)) {
                        New-Item -ItemType Directory -Path $libDir -Force | Out-Null
                    }
                    
                    # Download the package
                    Invoke-WebRequest -Uri $nugetUrl -OutFile $tempZip -ErrorAction Stop
                    
                    # Extract to temp location first
                    $tempExtract = "$env:TEMP\TagLibSharp_NuGet_Extract"
                    if (Test-Path $tempExtract) {
                        Remove-Item $tempExtract -Recurse -Force
                    }
                    
                    # Extract using .NET
                    Add-Type -AssemblyName System.IO.Compression.FileSystem
                    [System.IO.Compression.ZipFile]::ExtractToDirectory($tempZip, $tempExtract)
                    
                    # Find the TagLib.dll in lib folder (look for .NET versions)
                    $possibleDlls = Get-ChildItem -Path $tempExtract -Name "TagLib.dll" -Recurse | 
                                   Where-Object { $_ -like "*lib*" } | 
                                   Select-Object -First 1
                    
                    if ($possibleDlls) {
                        $sourceDll = Join-Path $tempExtract $possibleDlls
                        $destDll = Join-Path $libDir "TagLib.dll"
                        Copy-Item $sourceDll $destDll -Force
                        Write-Host "✓ TagLib.dll installed from NuGet to: $destDll" -ForegroundColor Green
                        $installSuccess = $true
                    } else {
                        throw "TagLib.dll not found in NuGet package"
                    }
                    
                    # Clean up
                    Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
                    Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
                }
                catch {
                    Write-Error "All automatic installation methods failed:"
                    Write-Host ""
                    Write-Host "The automatic installation encountered errors. Please try manual installation:" -ForegroundColor Yellow
                    Write-Host ""
                    Write-Host "Option 1: NuGet Provider Setup (recommended)" -ForegroundColor Cyan
                    Write-Host "  # Setup NuGet support" -ForegroundColor White
                    Write-Host "  Find-PackageProvider -Name NuGet | Install-PackageProvider -Force" -ForegroundColor White
                    Write-Host "  Register-PackageSource -Name nuget.org -Location https://www.nuget.org/api/v2 -ProviderName NuGet" -ForegroundColor White
                    Write-Host "  # Install TagLibSharp" -ForegroundColor White
                    Write-Host "  Find-Package -ProviderName NuGet -Name TagLibSharp | Install-Package -Destination $(Join-Path $moduleDir 'lib')" -ForegroundColor White
                    Write-Host ""
                    Write-Host "Option 2: PowerShell Package Manager (retry)" -ForegroundColor Cyan
                    Write-Host "  Install-Package TagLibSharp -Scope CurrentUser -Force" -ForegroundColor White
                    Write-Host ""
                    Write-Host "Option 3: NuGet CLI" -ForegroundColor Cyan
                    Write-Host "  nuget install TagLibSharp -OutputDirectory `$env:USERPROFILE\.nuget\packages" -ForegroundColor White
                    Write-Host ""
                    Write-Host "Option 4: Manual NuGet Download" -ForegroundColor Cyan
                    Write-Host "  1. Visit: https://www.nuget.org/packages/TagLibSharp/" -ForegroundColor White
                    Write-Host "  2. Download the .nupkg file" -ForegroundColor White
                    Write-Host "  3. Extract TagLib.dll to the MuFo module lib directory" -ForegroundColor White
                    Write-Host ""
                    Write-Host "Option 5: GitHub Release (latest)" -ForegroundColor Cyan
                    Write-Host "  1. Visit: https://github.com/mono/taglib-sharp/releases/latest" -ForegroundColor White
                    Write-Host "  2. Download the compiled binaries or source" -ForegroundColor White
                    Write-Host "  3. Copy TagLib.dll to: $(Join-Path $moduleDir 'lib')" -ForegroundColor White
                    Write-Host ""
                    Write-Host "Option 6: Direct GitHub Archive" -ForegroundColor Cyan
                    Write-Host "  1. Download: https://github.com/mono/taglib-sharp/archive/refs/tags/TaglibSharp-2.3.0.0.zip" -ForegroundColor White
                    Write-Host "  2. Compile or extract TagLib.dll" -ForegroundColor White
                    Write-Host "  3. Copy to MuFo lib directory" -ForegroundColor White
                    
                    return
                }
            }
        }
    }
    
    if (-not $installSuccess) {
        Write-Warning "Installation may have failed. Proceeding with verification..."
    }
    
    # Verify installation
    Write-Host "Verifying installation..." -ForegroundColor Yellow
    
    $moduleDir = Split-Path $PSScriptRoot -Parent
    $verifyPaths = @(
        (Join-Path $moduleDir "lib\TagLib.dll"),                                    # Module lib folder (preferred)
        "$env:USERPROFILE\.nuget\packages\taglib*\lib\*\TagLib.dll",              # NuGet packages
        "$env:USERPROFILE\.nuget\packages\taglibsharp*\lib\*\TagLib.dll",
        "$env:USERPROFILE\.nuget\packages\taglibsharp*\**\TagLib.dll"
    )
    
    $verified = $false
    $foundDll = $null
    
    foreach ($path in $verifyPaths) {
        if ($path -like "*\*") {
            # Handle wildcard paths
            $dlls = Get-ChildItem -Path $path -Recurse -ErrorAction SilentlyContinue | 
                    Where-Object { $_.Name -eq 'TagLib.dll' }
            
            if ($dlls) {
                $foundDll = $dlls | Select-Object -First 1
                Write-Host "✓ Installation verified: $($foundDll.FullName)" -ForegroundColor Green
                $verified = $true
                break
            }
        } elseif (Test-Path $path) {
            $foundDll = Get-Item $path
            Write-Host "✓ Installation verified: $($foundDll.FullName)" -ForegroundColor Green
            $verified = $true
            break
        }
    }
    
    if (-not $verified) {
        # Try to find any TagLib.dll in the packages directory
        $packagesDir = "$env:USERPROFILE\.nuget\packages"
        if (Test-Path $packagesDir) {
            $anyTagLib = Get-ChildItem -Path $packagesDir -Name "TagLib.dll" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($anyTagLib) {
                $foundDll = Get-Item (Join-Path $packagesDir $anyTagLib)
                Write-Host "✓ Found TagLib.dll: $($foundDll.FullName)" -ForegroundColor Green
                $verified = $true
            }
        }
    }
    
    if (-not $verified) {
        Write-Warning "Could not verify TagLib-Sharp installation. It may not be in the expected location."
        Write-Host "Please check: $env:USERPROFILE\.nuget\packages for TagLib-Sharp" -ForegroundColor Yellow
        return
    }
    
    # Test loading
    try {
        Add-Type -Path $foundDll.FullName
        Write-Host "✓ TagLib-Sharp loaded successfully!" -ForegroundColor Green
        Write-Host ""
        Write-Host "You can now use OM's track tagging features:" -ForegroundColor Cyan
        Write-Host "  Start-OM -Path 'C:\Music' -IncludeTracks" -ForegroundColor White
    }
    catch {
        Write-Warning "TagLib-Sharp installed but failed to load: $($_.Exception.Message)"
        Write-Host "You may need to restart PowerShell." -ForegroundColor Yellow
    }
}
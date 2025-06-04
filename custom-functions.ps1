# Custom utility funcs

function localpack {
    param(
        [string]$ProjectPath = ".",
        [string]$OutputDirectory = "$env:USERPROFILE\LocalNugets",
        [string]$Configuration = "Release",
        [string]$VersionSuffix = "-local",
        [bool]$Clean = $true,
        [string]$Version = $null,
        [switch]$Install
    )

    if ($Install) {
        Write-Output "Checking if 'Local Packages' feed already exists"
        $nugetConfigPath = "$env:APPDATA\NuGet\NuGet.Config"
        if (-not (Test-Path -Path $nugetConfigPath)) {
            Write-Output "Creating NuGet.Config file at $nugetConfigPath"
            [xml]$nugetConfig = New-Object xml
            $nugetConfig.LoadXml("<configuration><packageSources></packageSources></configuration>")
        }
        else {
            [xml]$nugetConfig = Get-Content -Path $nugetConfigPath -Raw | Out-String
        }

        $packageSources = $nugetConfig.configuration.packageSources
        if (-not $packageSources) {
            $packageSources = $nugetConfig.CreateElement("packageSources")
            $nugetConfig.configuration.AppendChild($packageSources) | Out-Null
        }

        $localSource = $packageSources.SelectSingleNode("add[@key='Local Packages']")
        if ($localSource) {
            Write-Output "'Local Packages' feed already exists. No changes made."
        }
        else {
            Write-Output "Adding $OutputDirectory as a local NuGet feed called 'Local Packages'"
            $newSource = $packageSources.CreateElement("add")
            $newSource.SetAttribute("key", "Local Packages")
            $newSource.SetAttribute("value", $OutputDirectory)
            $packageSources.AppendChild($newSource) | Out-Null
            $nugetConfig.Save($nugetConfigPath)
            Write-Output "Local Packages feed added to NuGet.Config"
        }
        return
    }

    $projectFile = Get-ChildItem -Path $ProjectPath -Filter *.csproj | Select-Object -First 1
    if (-not $projectFile) {
        Write-Error "No .csproj file found in the specified path: $ProjectPath"
        return
    }
    
    $projectName = [System.IO.Path]::GetFileNameWithoutExtension($projectFile.Name)
    
    $nugetCachePath = "$env:USERPROFILE\.nuget\packages\$projectName"
    
    if (Test-Path -Path $nugetCachePath) {
        Write-Output "Deleting existing NuGet package directory: $nugetCachePath"
        Remove-Item -Recurse -Force -Path $nugetCachePath
    }
    else {
        Write-Output "No existing package directory found for $projectName in ~/.nuget/packages."
    }

    if ($Clean) {
        dotnet clean $ProjectPath --configuration $Configuration
    }

    
    if (-not $Version) {
        $csprojContent = Get-Content -Path $projectFile.FullName
        $csprojVersion = [regex]::Match($csprojContent, '<Version>(.*?)</Version>').Groups[1].Value
        if ($csprojVersion) {
            $Version = $csprojVersion
            $Version = $Version -replace "\$\(.+?\)", ""
            Write-Output "Version determined from .csproj file: $Version"
        }
        else {
            Write-Output "No version found in .csproj file. Using default version suffix."
            $Version = "0.0.1"
        }
    }
    else {
        Write-Output "Version provided as input: $Version"
    }

    $versionArg = "/p:Version=$Version$VersionSuffix"
    
    Write-Output "Packing `"$projectName $Version$VersionSuffix`" to $OutputDirectory"
    dotnet pack $ProjectPath -o $OutputDirectory -p:IncludeSymbols=true -p:SymbolPackageFormat=snupkg --configuration $Configuration $versionArg
}

function localpack-children {
    param(
        [string]$StartPath = ".",
        [string]$OutputDirectory = "$env:USERPROFILE\LocalNugets",
        [string]$Configuration = "Release",
        [string]$VersionSuffix = "-local",
        [bool]$Clean = $true,
        [string]$Version = $null,
        [switch]$Install
    )
    
    # Find all .csproj files recursively from the start path
    $csprojFiles = Get-ChildItem -Path $StartPath -Recurse -Filter *.csproj
    
    if ($csprojFiles.Count -eq 0) {
        Write-Error "No .csproj files found in the specified path: $StartPath"
        return
    }
    

    $customFunctionsPath = (Join-Path (Split-Path $PROFILE -Parent) "custom-functions.ps1")

    $csprojFiles | ForEach-Object -Parallel {
        . $using:customFunctionsPath
        Write-Output "Processing $($_.FullName)"
        localpack -ProjectPath $_.DirectoryName -OutputDirectory $using:OutputDirectory -Configuration $using:Configuration -VersionSuffix $using:VersionSuffix -Clean $using:Clean -Version $using:Version -Install:$using:Install
    } -ThrottleLimit 4
}

function which ($command) {
    Get-Command -Name $command -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty Path -ErrorAction SilentlyContinue
}

Function gig {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$list
    )
    $params = ($list | ForEach-Object { [uri]::EscapeDataString($_) }) -join ","
    Invoke-WebRequest -Uri "https://www.toptal.com/developers/gitignore/api/$params" | Select-Object -ExpandProperty content | Out-File -FilePath $(Join-Path -path $pwd -ChildPath ".gitignore") -Encoding ascii
}

function Restart-PowerShell {
    Invoke-Command { & "pwsh.exe" } -NoNewScope 
}
Set-Alias -Name 'reload' -Value 'Restart-PowerShell'

function Remove-BinObjFolders {
    # Get the current working directory
    $currentDir = Get-Location

    # Recursively search for "bin" and "obj" folders and remove them
    Get-ChildItem -Path $currentDir -Recurse -Directory | Where-Object { $_.Name -in @('bin', 'obj') } | Remove-Item -Recurse -Force
}
Set-Alias -Name 'clean' -Value 'Remove-BinObjFolders'

function Remove-BinObjFolders-Params {
    param(
        [Parameter(Mandatory = $true, ValueFromRemainingArguments = $true)]
        [string[]]$Folders
    )
    $currentDir = Get-Location

    # Recursively search for inputted folders
    Get-ChildItem -Path $currentDir -Recurse -Directory | Where-Object { $_.Name -in $Folders } | Remove-Item -Recurse -Force
}
Set-Alias -Name 'cleanDir' -Value 'Remove-BinObjFolders-Params'


function Set-Link {
    param(
        [string]$from,
        [string]$to
    )
    New-Item -Path $to -ItemType SymbolicLink -Value $from
}

Set-Alias -Name 'ln' -Value 'Set-Link'

Set-Alias -Name 'unfuckwinget' -Value 'Repair-WinGetPackageManager'
Set-Alias -Name 'sudo' -Value 'gsudo'

function Get-String-Value-Line {
    param (
        [string]$pattern,
        [switch]$ignoreCase
    )

    process {
        if ($ignoreCase) {
            $_ | Select-String -Pattern $pattern -CaseSensitive:$false
        }
        else {
            $_ | Select-String -Pattern $pattern
        }
    }
}

Set-Alias -Name 'grep' -Value 'Get-String-Value-Line'

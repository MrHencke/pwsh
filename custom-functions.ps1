# Custom utility funcs

function localpack {
    [CmdletBinding()]
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
    [CmdletBinding()]
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
    if ($currentDir -eq $HOME) {
        Write-Error "We have already tried this one, dont do that again!"
        return
    }
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

function Convert-LineEndings {
    [CmdletBinding()]
    param (
        [string]$Path = (Get-Location),
        [bool]$ToLF = $true
    )

    Write-Host "Processing files in: $Path"
    Write-Host "Converting to: $([string]::Join('', $(if ($ToLF) { 'LF (`\n`)' } else { 'CRLF (`\r\n`)' })))"

    Get-ChildItem -Path $Path -Recurse -File | ForEach-Object {
        $filePath = $_.FullName
        try {
            $content = Get-Content -Path $filePath -Raw

            if ($ToLF) {
                # Convert CRLF to LF
                $newContent = $content -replace "`r`n", "`n"
            }
            else {
                # Normalize to LF first, then convert LF to CRLF
                $normalized = $content -replace "`r`n", "`n"
                $newContent = $normalized -replace "`n", "`r`n"
            }

            Set-Content -Path $filePath -Value $newContent -NoNewline
            Write-Host "Converted: $filePath"
        }
        catch {
            Write-Warning "Failed to process: $filePath. Error: $_"
        }
    }
}

function ToLF {
    param (
        [string]$Path = (Get-Location) 
    )
    Convert-LineEndings -Path $Path -ToLF:$true
}

function ToCRLF {
    param (
        [string]$Path = (Get-Location) 
    )
    Convert-LineEndings -Path $Path -ToLF:$false
}


function Show-PowerStateEvents {
    # Shows power state events for a specified date
    # Was bootstrapped by Copilot, then fine tuned manually
    [CmdletBinding()]
    param (
        [int]$DaysBack = 7,
        [bool]$OnlyLid = $true
    )

    # Start from midnight of the day DaysBack ago
    $startDate = (Get-Date).Date.AddDays(-$DaysBack)

    # Fetch Kernel-Power events
    $events = Get-WinEvent -FilterHashtable @{
        LogName      = 'System'
        ProviderName = 'Microsoft-Windows-Kernel-Power'
        StartTime    = $startDate
    } | Select-Object TimeCreated, Id, Message

    if (-not $events) {
        Write-Host "No Kernel-Power events found since $startDate."
        return
    }

    # Map event IDs and extract reason text
    $mappedEvents = $events | ForEach-Object {
        $eventType = switch ($_.Id) {
            40 { "Driver blocked power transition" }
            41 { "Unexpected shutdown or reboot" }
            42 { "System entering sleep" }
            105 { "Power source change" }
            107 { "System resumed from sleep" }
            172 { "Connectivity state in standby" }
            506 { "Entering Modern Standby" }
            507 { "Exiting Modern Standby" }
            566 { "Session transition" }
            default {
                if ($_.Id) { "Event ID $($_.Id)" } else { "Unknown Event" }
            }
        }

        # Extract reason from message if available
        $reason = if ($_.Message -match "Reason: (.+?)(\r|\n|$)") {
            $matches[1].Trim()
        }
        elseif ($_.Message -match "Reason (.+?)(\r|\n|$)") {
            $matches[1].Trim()
        }
        else {
            $null
        }

        [PSCustomObject]@{
            DateTime  = $_.TimeCreated
            EventType = $eventType
            Reason    = $reason
        }
    }

    # Apply lid filter if enabled
    if ($OnlyLid) {
        $mappedEvents = $mappedEvents | Where-Object {
            $_.Reason -and $_.Reason -match 'lid'
        }
    }

    # Remove consecutive duplicates (same EventType and Reason)
    $filteredEvents = @()
    $lastEvent = $null
    foreach ($e in $mappedEvents | Sort-Object DateTime) {
        if ($lastEvent -and
            $e.EventType -eq $lastEvent.EventType -and
            $e.Reason -eq $lastEvent.Reason) {
            continue
        }
        $filteredEvents += $e
        $lastEvent = $e
    }

    # Get unique dates only (yyyy-MM-dd)
    $uniqueDates = $filteredEvents.DateTime |
    ForEach-Object { $_.ToString("yyyy-MM-dd") } |
    Sort-Object -Unique

    if (-not $uniqueDates) {
        Write-Host "No events found matching the filter criteria."
        return
    }

    # Display dropdown in terminal
    Write-Host "`nAvailable Dates:"
    for ($i = 0; $i -lt $uniqueDates.Count; $i++) {
        Write-Host "${i}: $($uniqueDates[$i])"
    }

    # Prompt user to select a date
    $selection = Read-Host "`nEnter the number of the date you want to view (press Enter for latest date)"
    if ($selection -eq "") {
        $selectedDate = $uniqueDates[-1]  # Latest date
        Write-Host "`nNo selection made. Showing latest date: $selectedDate.`n"
    }
    elseif ($selection -match '^\d+$' -and [int]$selection -ge 0 -and [int]$selection -lt $uniqueDates.Count) {
        $selectedDate = $uniqueDates[$selection]
        Write-Host "`nPower State Events for ${selectedDate}:`n"
    }
    else {
        Write-Host "Invalid selection. Please run the function again."
        return
    }

    # Display filtered events
    $final = $filteredEvents | Where-Object { $_.DateTime.ToString("yyyy-MM-dd") -eq $selectedDate }
    foreach ($item in $final) {
        $line = "$($item.DateTime.ToString("yyyy-MM-dd HH:mm:ss")) - $($item.EventType)"
        if ($item.Reason) {
            $line += " (Reason: $($item.Reason))"
        }
        Write-Host $line
    }
}

function gitlog {
    # Quick shortcut to pretty print git commits on current branch that have been made after diverging from master
    git log master..HEAD --oneline --pretty=format:"- %s"
}

function psqlad {
    $env:PGPASSWORD = az account get-access-token --resource-type oss-rdbms --query accessToken -o tsv

    if (-not ($args -match '^-U$') && -not ($args -match '^--username$') && $null -ne $PsqlUser) {
        psql (@('-U', $PsqlUser) + $args)
    }
    else {
        psql $args
    }
}

function Write-Host-Padded {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Msg
    )

    $width = [Console]::WindowWidth
    $Msg = $Msg.Substring(0, [Math]::Min($Msg.Length, $width - 1))
    $paddedMsg = ("`r{0}" -f $Msg.PadRight($width))

    Write-Host $paddedMsg -NoNewline
}

# Create development HTTPS certificates for ASP.NET Core projects in the same manner as visual studio does
function Create-DevCerts {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ProjectsRoot = "src"
    )

    $processedCount = 0
    $certsCreated = 0
    $secretName = "Kestrel:Certificates:Development:Password"

    $certFolder = Join-Path $env:APPDATA "ASP.NET\Https"
    if (-not (Test-Path $certFolder)) {
        New-Item -ItemType Directory -Path $certFolder | Out-Null
    }

    $projects = Get-ChildItem -Path $ProjectsRoot -Recurse -Filter "*.csproj"
    foreach ($project in $projects) {
        [xml]$projXml = Get-Content $project.FullName
        $sdkAttr = $projXml.Project.Sdk
        
        if ($sdkAttr -ne "Microsoft.NET.Sdk.Web") {
            continue
        }
        
        $processedCount++
        $projectName = [System.IO.Path]::GetFileNameWithoutExtension($project.FullName)
        Write-Host-Padded "Checking project: $projectName"
        $certPath = Join-Path $certFolder "$projectName.pfx"

        $hasUserSecrets = Select-String -Path $project.FullName -Pattern "<UserSecretsId>" -Quiet
        if (-not $hasUserSecrets) {
            dotnet user-secrets init --project $project.FullName | Out-Null
        }

        $secretLine = dotnet user-secrets list --project $project.FullName |
        Select-String -Pattern ([regex]::Escape($secretName))
        $secretValue = $null
        if ($secretLine) {
            $secretValue = ($secretLine -split "=", 2)[1].Trim()
        }

        $certExists = Test-Path $certPath
        $secretExists = [string]::IsNullOrWhiteSpace($secretValue) -eq $false

        $certIsValid = $false
        if ($certExists -and $secretExists) {
            try {
                $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certPath, $secretValue)
                $certIsValid = $true
            }
            catch {
                $certIsValid = $false
            }
        }

        if ($certIsValid) {
            continue
        }
        else {
            if (-not $certIsValid -and $certExists) {
                Remove-Item $certPath -Force
            } 

            $password = [guid]::NewGuid().ToString()

            dotnet dev-certs https -ep $certPath -p $password | Out-Null
            dotnet user-secrets set $secretName $password --project $project.FullName | Out-Null

            Write-Host "`r[" -NoNewline
            Write-Host $projectName -ForegroundColor Green -NoNewline
            Write-Host "] Created certificate and kestrel password secret"
            $certsCreated++
        }
    }
    Write-Host-Padded "Done! Checked $processedCount candidate projects, created $certsCreated new certificates."
}

# Fetches updates and reloads profile
function Update-Profile {
    $profileFolder = Split-Path $PROFILE
    Push-Location $profileFolder

    $pullResult = git pull
    if ($pullResult -notmatch "Already up to date") {
        Write-Host "Update complete. Reloading."
        Pop-Location
        Invoke-Command { & "pwsh.exe" } -NoNewScope
    }
    else {
        Write-Host "No changes."
        Pop-Location
    }
}

function Reset-Profile {
    git fetch | Out-Null
    git reset --hard origin/master
}

# Fixes an unscrollable terminal if bugged (https://github.com/microsoft/terminal/issues/18441)
function Fix-Scroll {
    Write-Output "`e[?1049l"
}

function Touch {
    param([Parameter(Mandatory = $true)][string]$Path)
    
    $full = [IO.Path]::GetFullPath((Join-Path (Get-Location) $Path))
    $directory = Split-Path $full -Parent
    
    if (-not (Test-Path $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
    
    if (Test-Path $full) {
        (Get-Item $full).LastWriteTime = Get-Date
    }
    else {
        New-Item -ItemType File -Path $full -Force | Out-Null
    }
}
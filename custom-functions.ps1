# Custom utility funcs

function localpack {
    <#
    .SYNOPSIS
        Packages a .NET project locally as a NuGet package.

    .DESCRIPTION
        Creates a local NuGet package from a .NET project and optionally adds it to the local NuGet feed.
        Handles version extraction from .csproj files and manages NuGet cache cleanup.

    .PARAMETER ProjectPath
        The path to the project directory containing the .csproj file. Default: current directory.

    .PARAMETER OutputDirectory
        The output directory for the NuGet package. Default: $env:USERPROFILE\LocalNugets.

    .PARAMETER Configuration
        Build configuration (Release, Debug, etc.). Default: Release.

    .PARAMETER VersionSuffix
        Version suffix to append (e.g., "-local"). Default: -local.

    .PARAMETER Clean
        Whether to run 'dotnet clean' before packing. Default: $true.

    .PARAMETER Version
        Explicit version number. If not provided, extracted from .csproj.

    .PARAMETER Install
        Register the output directory as a local NuGet feed.

    .EXAMPLE
        localpack -ProjectPath "./MyProject" -Install
    #>
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
    <#
    .SYNOPSIS
        Packages all .NET projects in a directory tree locally.

    .DESCRIPTION
        Recursively finds and packages all .NET projects from a starting path to a local NuGet directory.
        Processes projects in parallel with a throttle limit.

    .PARAMETER StartPath
        The root path to search for .csproj files recursively. Default: current directory.

    .PARAMETER OutputDirectory
        The output directory for NuGet packages. Default: $env:USERPROFILE\LocalNugets.

    .PARAMETER Configuration
        Build configuration. Default: Release.

    .PARAMETER VersionSuffix
        Version suffix to append. Default: -local.

    .PARAMETER Clean
        Whether to run 'dotnet clean' before packing. Default: $true.

    .PARAMETER Version
        Explicit version number for all projects.

    .PARAMETER Install
        Register the output directory as a local NuGet feed.

    .EXAMPLE
        localpack-children -StartPath "./src" -Install
    #>
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

function which {
    <#
    .SYNOPSIS
        Locates the path of a command or executable.

    .DESCRIPTION
        Displays the full path of a command by querying PowerShell's command discovery.
        Similar to the Unix 'which' command.

    .PARAMETER command
        The name of the command to locate.

    .EXAMPLE
        which powershell
    #>
    param($command)
    Get-Command -Name $command -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty Path -ErrorAction SilentlyContinue
}

Function gig {
    <#
    .SYNOPSIS
        Generates a .gitignore file for specified technologies.

    .DESCRIPTION
        Downloads a preconfigured .gitignore file from the Toptal API for specified languages/frameworks
        and saves it to the current directory.

    .PARAMETER list
        One or more programming languages or frameworks (e.g., "csharp", "node", "python").

    .EXAMPLE
        gig csharp

    .EXAMPLE
        gig csharp, node, python
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$list
    )
    $params = ($list | ForEach-Object { [uri]::EscapeDataString($_) }) -join ","
    Invoke-WebRequest -Uri "https://www.toptal.com/developers/gitignore/api/$params" | Select-Object -ExpandProperty content | Out-File -FilePath $(Join-Path -path $pwd -ChildPath ".gitignore") -Encoding ascii
}

function Restart-PowerShell {
    <#
    .SYNOPSIS
        Restarts PowerShell in the current window.

    .DESCRIPTION
        Launches a new instance of pwsh.exe to refresh the shell environment.
        Alias: 'reload'.
    #>
    Invoke-Command { & "pwsh.exe" } -NoNewScope 
}
Set-Alias -Name 'reload' -Value 'Restart-PowerShell'

function Remove-BinObjFolders {
    <#
    .SYNOPSIS
        Removes all 'bin' and 'obj' folders recursively.

    .DESCRIPTION
        Recursively searches the current directory for 'bin' and 'obj' folders (common in .NET projects)
        and removes them. Prevents running in home directory as a safety measure.
        Alias: 'clean'.
    #>
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
    <#
    .SYNOPSIS
        Removes specified folders recursively.

    .DESCRIPTION
        Recursively removes folders with specified names from the current directory.
        Alias: 'cleanDir'.

    .PARAMETER Folders
        One or more folder names to delete (e.g., "bin", "obj", "dist").

    .EXAMPLE
        cleanDir bin obj dist
    #>
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
    <#
    .SYNOPSIS
        Creates a symbolic link.

    .DESCRIPTION
        Creates a symbolic link from a source to a target path.
        Alias: 'ln'.

    .PARAMETER from
        The source path to link from.

    .PARAMETER to
        The target path for the symbolic link.

    .EXAMPLE
        ln "C:\source\folder" "C:\target\link"
    #>
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
    <#
    .SYNOPSIS
        Searches for lines matching a pattern.

    .DESCRIPTION
        Filters input to find lines matching a regular expression pattern.
        Alias: 'grep'.

    .PARAMETER pattern
        The regex pattern to search for.

    .PARAMETER ignoreCase
        Perform case-insensitive search.

    .EXAMPLE
        Get-Content file.txt | grep "error"
    #>
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
    <#
    .SYNOPSIS
        Converts line endings in files.

    .DESCRIPTION
        Recursively converts line endings in all files within a directory.
        Can convert between LF (Unix) and CRLF (Windows) formats.

    .PARAMETER Path
        The directory path to process. Default: current directory.

    .PARAMETER ToLF
        If $true, convert to LF. If $false, convert to CRLF. Default: $true.

    .EXAMPLE
        Convert-LineEndings -Path "./src" -ToLF:$true
    #>
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
    <#
    .SYNOPSIS
        Converts all line endings to LF (Unix format).

    .DESCRIPTION
        Recursively converts all files in a directory to use LF (\n) line endings.

    .PARAMETER Path
        The directory path to process. Default: current directory.

    .EXAMPLE
        ToLF -Path "./src"
    #>
    param (
        [string]$Path = (Get-Location) 
    )
    Convert-LineEndings -Path $Path -ToLF:$true
}

function ToCRLF {
    <#
    .SYNOPSIS
        Converts all line endings to CRLF (Windows format).

    .DESCRIPTION
        Recursively converts all files in a directory to use CRLF (\r\n) line endings.

    .PARAMETER Path
        The directory path to process. Default: current directory.

    .EXAMPLE
        ToCRLF -Path "./src"
    #>
    param (
        [string]$Path = (Get-Location) 
    )
    Convert-LineEndings -Path $Path -ToLF:$false
}


function Show-PowerStateEvents {
    <#
    .SYNOPSIS
        Displays system power state events from the event log.

    .DESCRIPTION
        Retrieves and displays Kernel-Power events from the Windows event log for a specified date range.
        Events are filtered, deduplicated, and can be restricted to lid-specific events.
        User selects which date to view from available options.

    .PARAMETER DaysBack
        Number of days to look back in the event log. Default: 7.

    .PARAMETER OnlyLid
        Filter to only show lid-related events. Default: $true.

    .EXAMPLE
        Show-PowerStateEvents -DaysBack 14

    .EXAMPLE
        Show-PowerStateEvents -DaysBack 30 -OnlyLid:$false
    #>
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
    <#
    .SYNOPSIS
        Displays commits made after branching from master.

    .DESCRIPTION
        Shows a formatted list of commits on the current branch that have been made after diverging from the master branch.
    #>
    # Quick shortcut to pretty print git commits on current branch that have been made after diverging from master
    git log master..HEAD --oneline --pretty=format:"- %s"
}

function psqlad {
    <#
    .SYNOPSIS
        Connects to PostgreSQL via Azure AD authentication.

    .DESCRIPTION
        Retrieves an Azure access token for the current user and connects to PostgreSQL using it.
        Passes through all psql arguments, with optional user override.

    .PARAMETER PsqlUser
        Optional PostgreSQL user (uses $PsqlUser variable if not specified with -U flag).

    .EXAMPLE
        psqlad -h myserver.postgres.database.azure.com
    #>
    $env:PGPASSWORD = az account get-access-token --resource-type oss-rdbms --query accessToken -o tsv

    if (-not ($args -match '^-U$') && -not ($args -match '^--username$') && $null -ne $PsqlUser) {
        psql (@('-U', $PsqlUser) + $args)
    }
    else {
        psql $args
    }
}

function Write-Host-Padded {
    <#
    .SYNOPSIS
        Displays a message padded to the console width.

    .DESCRIPTION
        Writes a message to the console padded to the current window width, using carriage return
        to overwrite the line. Useful for progress messages.

    .PARAMETER Msg
        The message to display.

    .EXAMPLE
        Write-Host-Padded "Processing item 5/10..."
    #>
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

function Create-DevCerts {
    <#
    .SYNOPSIS
        Creates development HTTPS certificates for ASP.NET Core projects.

    .DESCRIPTION
        Automatically creates development HTTPS certificates for all ASP.NET Core projects
        (SDK = Microsoft.NET.Sdk.Web) in the specified directory. Similar to Visual Studio's behavior.
        Stores certificates in the ASP.NET Https folder and manages user secrets.

    .PARAMETER ProjectsRoot
        The root directory to search for .csproj files. Default: 'src'.

    .EXAMPLE
        Create-DevCerts

    .EXAMPLE
        Create-DevCerts -ProjectsRoot "./MyProjects"
    #>
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

function Update-Profile {
    <#
    .SYNOPSIS
        Fetches profile updates from the repository and reloads.

    .DESCRIPTION
        Pulls the latest changes from the PowerShell profile repository and automatically
        reloads PowerShell if updates were found.
    #>
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
    <#
    .SYNOPSIS
        Resets the profile to match the remote master branch.

    .DESCRIPTION
        Hard resets the local profile repository to match origin/master,
        discarding any local changes.
    #>
    git fetch | Out-Null
    git reset --hard origin/master
}

function Fix-Scroll {
    <#
    .SYNOPSIS
        Fixes an unscrollable terminal bug.

    .DESCRIPTION
        Outputs the escape sequence to fix the terminal scrolling issue
        described in https://github.com/microsoft/terminal/issues/18441.

    .EXAMPLE
        Fix-Scroll
    #>
    Write-Output "`e[?1049l"
}

function Touch {
    <#
    .SYNOPSIS
        Creates a file or updates its timestamp.

    .DESCRIPTION
        Creates a new file at the specified path, or updates the modification time of an existing file.
        Creates parent directories if needed. Similar to the Unix 'touch' command.

    .PARAMETER Path
        The path of the file to create or touch.

    .EXAMPLE
        Touch "./src/newfile.txt"
    #>
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

function Register-CronJob {
    <#
    .SYNOPSIS
        Registers a command as a scheduled task in Windows Task Scheduler.

    .DESCRIPTION
        This script creates a scheduled task that runs a specified command at defined intervals,
        similar to cron jobs in Linux/Unix systems.

    .PARAMETER TaskName
        The name of the scheduled task to create.

    .PARAMETER Command
        The command or script to execute.

    .PARAMETER Schedule
        The schedule type: Daily, Weekly, Monthly, OnStartup, OnLogon, or Hourly.

    .PARAMETER Time
        The time to run the task (24-hour format, e.g., "14:30"). Required for Daily/Weekly/Monthly.

    .PARAMETER Interval
        For Daily: number of days between runs (default: 1)
        For Weekly: day of week (Monday, Tuesday, etc.)
        For Hourly: number of hours between runs (default: 1)

    .PARAMETER Description
        Optional description for the task.

    .PARAMETER RunAsUser
        The user account to run the task under (default: current user).

    .PARAMETER RunElevated
        Run the task with highest privileges.

    .EXAMPLE
        Register-CronJob -TaskName "BackupDaily" -Command "C:\Scripts\backup.ps1" -Schedule Daily -Time "02:00"

    .EXAMPLE
        Register-CronJob -TaskName "EveryTwoHours" -Command "C:\Scripts\check.ps1" -Schedule Hourly -Interval 2

    .EXAMPLE
        Register-CronJob -TaskName "WeeklyCleanup" -Command "powershell.exe -File C:\Scripts\cleanup.ps1" -Schedule Weekly -Time "18:00" -Interval Sunday
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TaskName,

        [Parameter(Mandatory = $true)]
        [string]$Command,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Daily", "Weekly", "Monthly", "OnStartup", "OnLogon", "Hourly")]
        [string]$Schedule,

        [string]$Time,

        $Interval,

        [string]$Description = "Scheduled task created by Register-CronJob",

        [string]$RunAsUser = $env:USERNAME,

        [switch]$RunElevated,

        [bool]$Silent = $true
    )

    try {        
        # Validate time parameter for schedules that require it
        if ($Schedule -in @("Daily", "Weekly", "Monthly") -and -not $Time) {
            throw "Time parameter is required for $Schedule schedule type."
        }

        $psArgs = "-NoProfile -ExecutionPolicy Bypass"

        if ($Silent) {
            $psArgs += " -NonInteractive -WindowStyle Hidden"
        }

        if ($Command -match '\.ps1$') {
            $action = New-ScheduledTaskAction `
                -Execute "powershell.exe" `
                -Argument "$psArgs -File `"$Command`""
        }
        elseif ($Command -match '\.(exe|bat|cmd)$') {
            $action = New-ScheduledTaskAction -Execute $Command
        }
        else {
            $action = New-ScheduledTaskAction `
                -Execute "powershell.exe" `
                -Argument "$psArgs -Command `"$Command`""
        }

        switch ($Schedule) {
            "Daily" {
                $days = if ($Interval) { [int]$Interval } else { 1 }
                $trigger = New-ScheduledTaskTrigger -Daily -At $Time -DaysInterval $days
            }
            "Weekly" {
                $day = if ($Interval) { $Interval } else { "Monday" }
                $trigger = New-ScheduledTaskTrigger -Weekly -At $Time -DaysOfWeek $day
            }
            "Monthly" {
                $trigger = New-ScheduledTaskTrigger -Daily -At $Time
            }
            "Hourly" {
                $hours = if ($Interval) { [int]$Interval } else { 1 }
                $start = if ($Time) { $Time } else { (Get-Date).ToString("HH:mm") }

                $trigger = New-ScheduledTaskTrigger `
                    -Once `
                    -At $start `
                    -RepetitionInterval (New-TimeSpan -Hours $hours)

            }
            "OnStartup" {
                $trigger = New-ScheduledTaskTrigger -AtStartup
            }
            "OnLogon" {
                $trigger = New-ScheduledTaskTrigger -AtLogOn -User $RunAsUser
            }
        }

        $principalParams = @{
            UserId = $RunAsUser
        }

        if ($RunElevated) {
            $principalParams.RunLevel = "Highest"
        }

        $principal = New-ScheduledTaskPrincipal @principalParams

        $settingsParams = @{
            AllowStartIfOnBatteries    = $true
            DontStopIfGoingOnBatteries = $true
            StartWhenAvailable         = $true
        }

        if ($Silent) {
            $settingsParams.Hidden = $true
        }

        $settings = New-ScheduledTaskSettingsSet @settingsParams

        $task = Register-ScheduledTask `
            -TaskName $TaskName `
            -Action $action `
            -Trigger $trigger `
            -Principal $principal `
            -Settings $settings `
            -Description $Description `
            -Force

        Write-Host "✓ Registered scheduled task: $TaskName" -ForegroundColor Green
        Write-Host "  Schedule: $Schedule" -ForegroundColor Cyan
        Write-Host "  Silent:   $Silent" -ForegroundColor Cyan
        Write-Host "  Command:  $Command" -ForegroundColor Cyan

        return $task
    }
    catch {
        Write-Error "Failed to register scheduled task: $_"
        return $null
    }
}
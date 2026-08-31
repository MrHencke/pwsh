function Get-ProfileSettings {
    $settingsPath = "$PSScriptRoot\settings.json"
    $overridesPath = "$PSScriptRoot\settings.overrides.json"

    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json -AsHashtable

    if (Test-Path $overridesPath) {
        $overrides = Get-Content $overridesPath -Raw | ConvertFrom-Json -AsHashtable
        foreach ($section in $overrides.Keys) {
            if ($section -eq '_comment') { continue }
            if (-not $settings.ContainsKey($section)) { $settings[$section] = @{} }
            foreach ($key in $overrides[$section].Keys) {
                $settings[$section][$key] = $overrides[$section][$key]
            }
        }
    }

    return $settings
}

function Install-WingetPackage {
    param([Parameter(Mandatory)][string]$PackageId)
    if (-not ((winget list --id $PackageId --exact 2>$null) | Select-String $PackageId)) {
        Write-Host "Installing $PackageId..."
        winget install --id $PackageId -e --accept-source-agreements --accept-package-agreements
    }
}

function Install-RequiredModule {
    param([Parameter(Mandatory)][string]$ModuleName)
    if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
        Write-Host "Installing module: $ModuleName"
        Install-Module -Name $ModuleName -Force -Scope CurrentUser
    }
}

function Set-StarshipConfig {
    $dest = "$env:USERPROFILE\.config\starship.toml"
    $target = "$PSScriptRoot\starship.toml"
    $existing = Get-Item $dest -ErrorAction SilentlyContinue
    if (-not ($existing.Target -contains $target)) {
        if ($existing) {
            $i = 1
            while (Test-Path "$env:USERPROFILE\.config\starship.old$i.toml") { $i++ }
            Rename-Item $dest "$env:USERPROFILE\.config\starship.old$i.toml"
            Write-Host "Existing starship.toml renamed to starship.old$i.toml"
        }
        New-Item -ItemType SymbolicLink -Path $dest -Target $target | Out-Null
        Write-Host "Linked starship.toml"
    }
}

function Initialize-Environment {
    param($Settings = $script:ProfileSettings)
    Write-Host "`n--- Initializing Packages ---`n"
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Error "winget is not available."
        return
    }
    foreach ($pkg in $Settings.install.wingetPackages) { Install-WingetPackage $pkg }
    foreach ($v in $Settings.install.dotnetVersions) { Install-WingetPackage "Microsoft.DotNet.SDK.$v" }
    foreach ($mod in $Settings.install.powershellModules) { Install-RequiredModule $mod }
    if ($Settings.starship.autoSymlink) { Set-StarshipConfig }
    Write-Host "`nInitialization complete.`n"
}

function Update-Environment {
    param($Settings = $script:ProfileSettings)
    Write-Host "`n--- Updating Packages ---`n"
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Error "winget is not available."
        return
    }
    foreach ($pkg in $Settings.install.wingetPackages) { winget upgrade --id $pkg -e --accept-source-agreements --accept-package-agreements }
    foreach ($v in $Settings.install.dotnetVersions) { winget upgrade --id "Microsoft.DotNet.SDK.$v" -e --accept-source-agreements --accept-package-agreements }
    foreach ($mod in $Settings.install.powershellModules) { Update-Module $mod -Force -ErrorAction SilentlyContinue }
    Write-Host "`nUpdate complete.`n"
}

$script:ProfileSettings = Get-ProfileSettings

if ($script:ProfileSettings.general.enabled) {
    $lastRunFile = "$env:LOCALAPPDATA\pwsh_init.lastrun"
    $lastRun = if (Test-Path $lastRunFile) { [datetime](Get-Content $lastRunFile) } else { [datetime]::MinValue }
    $daysSince = ((Get-Date) - $lastRun).TotalDays

    if ($daysSince -ge $script:ProfileSettings.general.checkIntervalDays) {
        $flagFile = "$env:LOCALAPPDATA\pwsh_init.hash"
        $gitHash = git -C $PSScriptRoot log -1 --format=%H -- init.ps1 2>$null
        $lastHash = if (Test-Path $flagFile) { Get-Content $flagFile } else { "" }
        if ($gitHash -and $gitHash -ne $lastHash) {
            Initialize-Environment
            Set-Content $flagFile $gitHash
        }
        Set-Content $lastRunFile (Get-Date).ToString("o")
    }
}

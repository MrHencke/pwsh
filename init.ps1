$script:WingetPackages = @(
    "ajeetdsouza.zoxide"
    "Starship.Starship"
    "Schniz.fnm"
    "gerardog.gsudo"
    "junegunn.fzf"
    "Derailed.k9s"
    "Neovim.Neovim"
    "Git.Git"
    "aristocratos.btop4win"
    "JesseDuffield.Lazydocker"
    "Rustlang.Rustup"
)
$script:DotnetVersions = @(
    "8" 
    "9" 
    "10" 
    "Preview"
)
$script:PsModules = @(
    "PSFzf"
    "CompletionPredictor"
    "Microsoft.WinGet.CommandNotFound"
)

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
    Write-Host "`n--- Initializing Packages ---`n"
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Error "winget is not available."
        return
    }
    foreach ($pkg in $script:WingetPackages) { Install-WingetPackage $pkg }
    foreach ($v in $script:DotnetVersions) { Install-WingetPackage "Microsoft.DotNet.SDK.$v" }
    foreach ($mod in $script:PsModules) { Install-RequiredModule $mod }
    Set-StarshipConfig
    Write-Host "`nInitialization complete.`n"
}

function Update-Environment {
    Write-Host "`n--- Updating Packages ---`n"
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Error "winget is not available."
        return
    }
    foreach ($pkg in $script:WingetPackages) { winget upgrade --id $pkg -e --accept-source-agreements --accept-package-agreements }
    foreach ($v in $script:DotnetVersions) { winget upgrade --id "Microsoft.DotNet.SDK.$v" -e --accept-source-agreements --accept-package-agreements }
    foreach ($mod in $script:PsModules) { Update-Module $mod -Force -ErrorAction SilentlyContinue }
    Write-Host "`nUpdate complete.`n"
}

$dateFile = "$env:LOCALAPPDATA\pwsh_init.date"
$today = (Get-Date).ToString("yyyy-MM-dd")
$lastDate = if (Test-Path $dateFile) { Get-Content $dateFile } else { "" }

if ($lastDate -ne $today) {
    $flagFile = "$env:LOCALAPPDATA\pwsh_init.hash"
    $gitHash = git -C $PSScriptRoot log -1 --format=%H -- init.ps1 2>$null
    $lastHash = if (Test-Path $flagFile) { Get-Content $flagFile } else { "" }
    if ($gitHash -and $gitHash -ne $lastHash) {
        Initialize-Environment
        Set-Content $flagFile $gitHash
    }
    Set-Content $dateFile $today
}


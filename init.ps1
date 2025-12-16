function Ensure-Winget {
    param (
        [Parameter(Mandatory = $true)]
        [string]$PackageId,

        [string]$DisplayName = $null 
    )

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Error "winget is not available. Please install winget first."
        return
    }

    $pkgName = if ($DisplayName) { $DisplayName } else { $PackageId }
    $isInstalled = (winget list --id $PackageId 2>$null) -match $PackageId

    if (-not $isInstalled) {
        Write-Host "$pkgName is not installed. Installing..."
        winget install --id $PackageId -e --accept-source-agreements --accept-package-agreements
    }
    else {
        Write-Host "$pkgName is already installed."
    }
}

function Ensure-Module {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ModuleName
    )
    $moduleIsInstalled = [bool](Get-Module -ListAvailable -Name $ModuleName)
    if (-not $moduleIsInstalled) {
        Write-Host "Installing PowerShell module: $ModuleName"
        Install-Module -Name $ModuleName -Force -Scope CurrentUser
    }
    else {
        Write-Host "$ModuleName module is already installed."
    }
}

function Init {
    Write-Host "`n--- Initializing Packages ---`n"

    Ensure-Winget -PackageId "ajeetdsouza.zoxide" -DisplayName "Zoxide"
    Ensure-Winget -PackageId "Starship.Starship" -DisplayName "Starship Prompt"
    Ensure-Winget -PackageId "Schniz.fnm" -DisplayName "FNM (Node Version Manager)"
    Ensure-Winget -PackageId "gerardog.gsudo" -DisplayName "gsudo (Elevated Command Execution)"
    Ensure-Winget -PackageId "junegunn.fzf" -DisplayName "FZF (Command-line Fuzzy Finder)"
    Ensure-Winget -PackageId "Derailed.k9s" -DisplayName "K9s (Kubernetes CLI)"
    Ensure-Winget -PackageId "Neovim.Neovim" -DisplayName "Neovim"
    ensure-Winget -PackageId "Git.Git" -DisplayName "Git"
    ensure-Winget -PackageId "aristocratos.btop4win" -DisplayName "btop"
    ensure-Winget -PackageId "RedHat.Podman" -DisplayName "Podman"
    ensure-Winget -PackageId "RedHat.Podman-Desktop" -DisplayName "Podman Desktop"
    ensure-Winget -PackageId "Containers.PodmanTUI" -DisplayName "Podman TUI"
    ensure-Winget -PackageId "JesseDuffield.Lazydocker" -DisplayName "Docker TUI"

    ensure-Winget -PackageId "Microsoft.DotNet.SDK.8" -DisplayName "Dotnet 8"
    ensure-Winget -PackageId "Microsoft.DotNet.SDK.9" -DisplayName "Dotnet 9"
    ensure-Winget -PackageId "Microsoft.DotNet.SDK.10" -DisplayName "Dotnet 10"

    Ensure-Module -ModuleName "PSReadLine"
    Ensure-Module -ModuleName "PSFzf"
    Ensure-Module -ModuleName "CompletionPredictor"
    Ensure-Module -ModuleName "Microsoft.WinGet.CommandNotFound"

    if (Get-Command "kubectl" -ErrorAction SilentlyContinue) {
        kubectl completion powershell | Out-String > $profile/../generated/kubectl-completions.ps1
    }
    if (Get-Command "rustup" -ErrorAction SilentlyContinue) {
        rustup completions powershell | Out-String > $profile/../generated/rustup-completions.ps1
    }
}

$FlagFile = "$env:LOCALAPPDATA\init_env_flag"

if (-not (Test-Path $FlagFile)) {
    Init
    New-Item -Path $FlagFile -ItemType File -Force | Out-Null
    Write-Host "`nInitialization complete. Flag saved at $FlagFile`n"
} 

$starshipSource = Join-Path (Split-Path -Parent $PROFILE) "starship.toml"
$starshipDestination = "$env:USERPROFILE\.config\starship.toml"

if (-Not (Test-Path $starshipDestination)) {
    Write-Output "Linking starship.toml to $starshipDestination"
    Set-Link -From $starshipSource -To $starshipDestination
}
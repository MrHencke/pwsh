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

    $isInstalled = winget list --id $PackageId 2>&1 | Where-Object { $_ -notmatch "No installed package found" }

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
    if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
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
    Ensure-Winget -PackageId "fzf" -DisplayName "FZF (Command-line Fuzzy Finder)"
    Ensure-Winget -PackageId "Derailed.k9s" -DisplayName "K9s (Kubernetes CLI)"
    Ensure-Winget -PackageId "Neovim.Neovim" -DisplayName "Neovim"
    ensure-Winget -PackageId "Git.Git" -DisplayName "Git"

    Ensure-Module -ModuleName "PSReadLine"
    Ensure-Module -ModuleName "PSFzf"
    Ensure-Module -ModuleName "CompletionPredictor"
    Ensure-Module -ModuleName "Microsoft.WinGet.CommandNotFound"

    kubectl completion powershell | Out-String > $profile/../generated/kubectl-completions.ps1
    rustup completions powershell | Out-String > $profile/../generated/rustup-completions.ps1
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
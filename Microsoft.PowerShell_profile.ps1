# Required packages:
# winget install --id ajeetdsouza.zoxide
# winget install -e --id Starship.Starship
# winget install fzf
# winget install Schniz.fnm
# winget install gerardog.gsudo
# Install-Module -Name PSReadLine
# Install-Module -Name PSFzf

# FNM
fnm env --use-on-cd | Out-String | Invoke-Expression


. "$PSScriptRoot\zoxide.ps1"
. "$PSScriptRoot\custom-functions.ps1"

# Link starship config to correct folder
$source = Join-Path (Split-Path -Parent $PROFILE) "starship.toml"
$destination = "$env:USERPROFILE\.config\starship.toml"

if (-Not (Test-Path $destination)) {
    Write-Output "Linking starship.toml to $destination"
    Set-Link -From $source -To $destination
}

# Starship
Invoke-Expression (&'C:\Program Files\starship\bin\starship.exe' init powershell)

# PSReadLine
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -EditMode Windows

#Fzf
Import-Module PSFzf
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+f' -PSReadlineChordReverseHistory 'Ctrl+r'
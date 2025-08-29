
. "$PSScriptRoot\init.ps1"
. "$PSScriptRoot\zoxide.ps1"
. "$PSScriptRoot\custom-functions.ps1"
. "$PSScriptRoot\rustup-completions.ps1"

# FNM
fnm env --use-on-cd | Out-String | Invoke-Expression

# Starship
Invoke-Expression (&'C:\Program Files\starship\bin\starship.exe' init powershell)

# PSReadLine
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -EditMode Windows

#Fzf
Import-Module PSFzf
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+f' -PSReadlineChordReverseHistory 'Ctrl+r'
#f45873b3-b655-43a6-b217-97c00aa0db58 PowerToys CommandNotFound module

Import-Module -Name Microsoft.WinGet.CommandNotFound
#f45873b3-b655-43a6-b217-97c00aa0db58

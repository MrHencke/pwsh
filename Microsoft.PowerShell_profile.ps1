
. "$PSScriptRoot\init.ps1"
. "$PSScriptRoot\zoxide.ps1"
. "$PSScriptRoot\custom-functions.ps1"

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

. "$PSScriptRoot\init.ps1"
. "$PSScriptRoot\custom-functions.ps1"

$generatedScriptFolder = Join-Path $PSScriptRoot "generated"
$scriptFiles = Get-ChildItem -Path $generatedScriptFolder -Filter *.ps1
foreach ($script in $scriptFiles) {
    . $script.FullName
}

# FNM
fnm env --use-on-cd | Out-String | Invoke-Expression

# Starship
Invoke-Expression (&'C:\Program Files\starship\bin\starship.exe' init powershell)

# PSReadLine
Import-Module -Name CompletionPredictor
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -EditMode Windows

#Fzf
Import-Module PSFzf
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+f' -PSReadlineChordReverseHistory 'Ctrl+r'

# Winget notfound helper
Import-Module -Name Microsoft.WinGet.CommandNotFound

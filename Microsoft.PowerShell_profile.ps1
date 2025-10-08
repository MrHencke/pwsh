$scripts = @(
    "init.ps1"
    "custom-functions.ps1"
    "env.ps1",
    "k9s.ps1"
)

foreach ($scriptName in $scripts) {
    $scriptPath = Join-Path $PSScriptRoot $scriptName
    if (Test-Path $scriptPath) {
        . $scriptPath
    }
}

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

# Zoxide
Invoke-Expression (& { (zoxide init --cmd cd powershell | Out-String) })
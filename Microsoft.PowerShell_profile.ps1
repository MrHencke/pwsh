function Use-Cache([string]$Cache, [string[]]$Sources, [scriptblock]$Init) {
    $cacheTime = if (Test-Path $Cache) { (Get-Item $Cache).LastWriteTime } else { [datetime]::MinValue }
    $needsRegen = $Sources | Where-Object { (Test-Path $_) -and (Get-Item $_).LastWriteTime -gt $cacheTime }
    if ($needsRegen -or $cacheTime -eq [datetime]::MinValue) {
        & $Init | Set-Content $Cache -Encoding UTF8
    }
    . $Cache
}

foreach ($s in "init.ps1", "env.ps1", "custom-functions.ps1") {
    $p = "$PSScriptRoot\$s"
    if (Test-Path $p) { . $p }
}

$cache = "$PSScriptRoot\cache"
if (-not (Test-Path $cache)) { New-Item $cache -ItemType Directory | Out-Null }

foreach ($tool in ($script:ProfileSettings.tools.Values | Sort-Object order)) {
    $init = [scriptblock]::Create($tool.init)
    $bin = (Get-Command $tool.bin -ErrorAction SilentlyContinue).Source
    if ($bin -and $tool.cache) { Use-Cache "$cache\$($tool.cache)" @($bin) $init }
    else { & $init }
}

Import-Module CompletionPredictor
Set-PSReadLineOption -PredictionSource HistoryAndPlugin `
    -PredictionViewStyle ListView -EditMode Windows
    
$script:fzfLoaded = $false

function _EnsureFzf {
    if ($script:fzfLoaded) { return }
    Import-Module PSFzf
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+f' `
        -PSReadlineChordReverseHistory 'Ctrl+r' `
        -TabExpansion
    $script:fzfLoaded = $true
}

Set-PSReadLineKeyHandler -Chord 'Ctrl+f' -ScriptBlock { _EnsureFzf; & (Get-Module PSFzf) { Invoke-FzfPsReadlineHandlerProvider } }
Set-PSReadLineKeyHandler -Chord 'Ctrl+r' -ScriptBlock { _EnsureFzf; & (Get-Module PSFzf) { Invoke-FzfPsReadlineHandlerHistory } }

function sudo { Remove-Item Function:\sudo; Import-Module gsudoModule; sudo @args }

$ExecutionContext.InvokeCommand.CommandNotFoundAction = {
    param($Name, $e)
    Write-Output "Command not found: $Name"
    $ExecutionContext.InvokeCommand.CommandNotFoundAction = $null
    Import-Module Microsoft.WinGet.CommandNotFound
}
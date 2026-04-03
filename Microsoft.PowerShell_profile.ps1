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

$tools = @(
    @{ Name = "starship"; Cache = "starship.ps1"; LoadOrder = 1; Init = { starship init powershell --print-full-init | Out-String } }
    @{ Name = "fnm"; Cache = "fnm.ps1"; LoadOrder = 2; Init = { fnm env --use-on-cd | Out-String } }
    @{ Name = "dotnet"; Cache = "completions_dotnet.ps1"; LoadOrder = 3; Init = { $env:DOTNET_NOLOGO = 1; dotnet completions script pwsh | Out-String } }
    @{ Name = "kubectl"; Cache = "completions_kubectl.ps1"; LoadOrder = 3; Init = { kubectl completion powershell | Out-String } }
    @{ Name = "k9s"; Cache = "completions_k9s.ps1"; LoadOrder = 3; Init = { k9s completion powershell | Out-String } }
    @{ Name = "rustup"; Cache = "completions_rustup.ps1"; LoadOrder = 3; Init = { rustup completions powershell | Out-String } }
    @{ Name = "zoxide"; Cache = "zoxide.ps1"; LoadOrder = 4; Init = { zoxide init --cmd cd powershell | Out-String } }
)

foreach ($tool in ($tools | Sort-Object LoadOrder)) {
    $bin = (Get-Command $tool.Name -ErrorAction SilentlyContinue).Source
    if ($bin) { Use-Cache "$cache\$($tool.Cache)" @($bin) $tool.Init }
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
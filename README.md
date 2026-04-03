# Henckes PowerShell Profile

A feature-rich PowerShell 7 configuration with lazy-loaded modules, performance optimizations, and useful utility functions.

## Features

- **Lazy-loaded modules** - PSFzf and other heavy modules load on-demand for faster startup
- **Smart caching** - Completion scripts cached to avoid repeated generation
- **Fuzzy finding** - Integrated fzf for file/history selection with Ctrl+F and Ctrl+R
- **Enhanced prompt** - Starship prompt with git integration and custom styling
- **Utility functions** - Quick commands for common development tasks (.NET, git, files, etc.)
- **Environment initialization** - Automatic dependency management with winget

## Installation

### Prerequisites
- PowerShell 7+ (`winget install Microsoft.Powershell`)
- Git (for version tracking, if you zip clone this repo please stop and get some help)
- Windows Terminal (highly recommended, but not required)

### Setup Steps

1. **Clone the repository**
   ```powershell
   git clone <repo-url> "$env:USERPROFILE\Documents\PowerShell"
   ```

   Please make sure to backup your own existing profile if applicable.

2. **Set execution policy (if needed)**
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine
   ```

3. **Unblock files (if needed)**
   ```powershell
   Get-ChildItem -Path "$env:USERPROFILE\Documents\PowerShell" -Recurse -File | Unblock-File
   ```

4. **Run initialization** (on first load, the profile will automatically initialize)
   - Allow the first shell load to complete the setup process
   - If you see "Administrator rights required" errors during module installation, run this:
     ```powershell
     Add-MpPreference -ControlledFolderAccessAllowedApplications "C:\Program Files\PowerShell\7\pwsh.exe"
     ```

## Usage

### Common Commands

**Profile Management**
- `Update-Profile` - Pull latest changes from git and reload
- `Reset-Profile` - Hard reset to origin/master (discards local changes)
- `Initialize-Environment` - Manually run package initialization (Is done automatically each time HEAD hash changes)
- `Update-Environment` - Update all installed packages
- `reload` - Restart PowerShell

**Fuzzy Finding**
- `Ctrl+F` - Fuzzy search files in current directory
- `Ctrl+R` - Fuzzy search command history

**File & Directory**
- `cd [dir]` - Navigate with zoxide
- `clean` - Remove all bin/obj folders recursively
- `cleanDir [folders...]` - Remove specific folders recursively
- `ln [source] [target]` - Create symbolic links
- `touch [path]` - Create empty file
- `which [command]` - Find command path

**Development (.NET)**
- `localpack [path]` - Package a .NET project locally as NuGet
- `localpack-children [path]` - Package all child .csproj files
- `Create-DevCerts [path]` - Generate HTTPS certs for ASP.NET projects (useful if CLI or rider user, VS does this automatically)

**Git**
- `gitlog` - Show commits on current branch since divergence from master
- Standard git commands (integrated with fzf for branch/file selection)

**Utilities**
- `gig [templates...]` - Generate .gitignore file from toptal.com (e.g., `gig csharp,node,python`)
- `grep [pattern]` - Filter piped content (alias for `Get-String-Value-Line`)
- `sudo` - Run command with elevated privileges (requires gsudo)
- `ToLF [path]` / `ToCRLF [path]` - Convert line endings recursively
- `Show-PowerStateEvents` - View system power state history (useful for knowing when you showed up to work, and/or left)

**Task Scheduling**
- `Register-CronJob` - Create Windows scheduled tasks
  - Example: Daily winget updates and Azure registry refresh
    ```powershell
    Register-CronJob -TaskName "DailyWingetUpdate" -Command "winget upgrade --all" -Schedule Daily -Time "12:00" -RunElevated
    ```  
    - Example: Refresh Azure ACR login every 2 hours
    ```powershell
    Register-CronJob -TaskName "AzACRLoginRefresh" -Command "az acr login -n myregistry" -Schedule Hourly -Interval 2
    ```
**Database**
- `psqlad [args]` - Connect to Azure PostgreSQL with automatic token auth

## Configuration

### Editing the Profile
The main profile file is split into logical parts:
- `Microsoft.PowerShell_profile.ps1` - Main entry point, module initialization
- `init.ps1` - Package/module installation and environment setup
- `custom-functions.ps1` - User-defined utility functions

Edit these files to customize behavior. The profile reloads on shell restart or with `reload`.

### Modifying Packages
In `init.ps1`, edit these arrays:
- `$script:WingetPackages` - Packages installed via winget
- `$script:DotnetVersions` - .NET SDK versions to install
- `$script:PsModules` - PowerShell modules to install

Changes are detected automatically on the next day's shell load (via git hash comparison).

## Performance

The profile uses several optimizations:
- **Lazy loading** - PSFzf loads on first use (Ctrl+F/Ctrl+R), not at startup
- **Completion caching** - fzf, dotnet, kubectl completions cached and reused
- **Conditional imports** - Modules only imported if commands are available

Typical startup time: ~450ms on modern hardware.

## Troubleshooting

**Module installation fails**
- Ensure winget is available: `winget --version`
- Check Windows Defender isn't blocking PowerShell: Add exemption via `Add-MpPreference`
- Run manually: `Initialize-Environment`

**fzf commands not working**
- Ensure fzf is installed: `winget install junegunn.fzf`
- Verify it's in PATH: `which fzf`

**Git commands not recognized**
- Install git: `winget install Git.Git`
- Restart PowerShell after installation

**Profile not updating**
- Use `Update-Profile` to pull latest changes
- Use `Reset-Profile` to discard local changes and sync with remote

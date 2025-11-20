# About

This is my personal powershell profile, filled with random utility functions and a riced starship prompt.


## Installation steps
- Ensure you have Powershell 7+ installed (`winget install Microsoft.Powershell`)
- Clone this repo into your userprofile location (usually Documents/Powershell)
- Ensure your executionpolicy is at least remotesigned (`Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine`)
- If script execution is blocked, unblock the files from this repo with Unblock-File
- Start a shell in Powershell 7+, allow init process to run
    - If module installation is blocked with a generic "Administrator rights required" error message, attempt to let pwsh through defender using `Add-MpPreference -ControlledFolderAccessAllowedApplications "C:\Program Files\PowerShell\7\pwsh.exe"`
- Update profile (from git) using `Update-Profile`, if you want to reset state to master use the `--force` flag.
- If changes are made to the init script, you can rerun it manually using `Init`
- ???
- Profit

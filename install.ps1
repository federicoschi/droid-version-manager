#Requires -Version 5.1
<#
  Installs dvm (Droid Version Manager) on Windows.

  Copies dvm.ps1 and the dvm.cmd shim into %USERPROFILE%\bin (matching
  where Factory's own installer puts droid.exe) and adds that directory
  to the user PATH if needed.

  Override the target with -InstallDir or $env:DVM_INSTALL_DIR.
#>

[CmdletBinding()]
param(
  [string]$InstallDir = $(if ($env:DVM_INSTALL_DIR) { $env:DVM_INSTALL_DIR } else { Join-Path $env:USERPROFILE 'bin' })
)

$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sources = @('dvm.ps1', 'dvm.cmd') | ForEach-Object { Join-Path $here $_ }

foreach ($src in $sources) {
  if (-not (Test-Path $src)) {
    Write-Host "error: $src not found" -ForegroundColor Red
    exit 1
  }
}

New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
foreach ($src in $sources) {
  Copy-Item -Path $src -Destination $InstallDir -Force
}

Write-Host "Installed dvm to $InstallDir" -ForegroundColor Green

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$onPath = ($userPath -split ';' | Where-Object { $_ -and ($_.TrimEnd('\') -ieq $InstallDir.TrimEnd('\')) })

if (-not $onPath) {
  [Environment]::SetEnvironmentVariable('Path', "$userPath;$InstallDir", 'User')
  $env:PATH = "$InstallDir;$env:PATH"
  Write-Host "Added $InstallDir to your user PATH. Open a new terminal for it to take effect elsewhere." -ForegroundColor Yellow
} else {
  Write-Host "dvm is ready — run 'dvm help' to get started." -ForegroundColor Green
}

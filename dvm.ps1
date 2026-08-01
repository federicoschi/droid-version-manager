#Requires -Version 5.1
<#
  dvm — Droid Version Manager (Windows)

  Pin Factory AI's droid CLI to a specific npm version when the
  auto-updating distribution channel is unstable, and revert cleanly
  when it stabilises.
#>

# No param() block on purpose: it would swallow "-v" / "--version" / "-h"
# during PowerShell parameter binding. $args receives everything verbatim.
$ErrorActionPreference = 'Stop'

$Command = if ($args.Count -ge 1) { [string]$args[0] } else { 'status' }
$Rest    = if ($args.Count -ge 2) { $args[1..($args.Count - 1)] } else { @() }

$DvmVersion        = '1.0.0'
$FactoryInstallUrl = 'https://app.factory.ai/cli/windows'
$FactoryBin        = Join-Path $env:USERPROFILE 'bin\droid.exe'
$StateDir          = Join-Path $env:LOCALAPPDATA 'dvm'
$StateFile         = Join-Path $StateDir 'pin'

# ── helpers ────────────────────────────────────────────────────────────
function Write-Info { param([string]$Message) Write-Host 'info ' -ForegroundColor Cyan -NoNewline; Write-Host " $Message" }
function Write-Ok   { param([string]$Message) Write-Host '  ok ' -ForegroundColor Green -NoNewline; Write-Host " $Message" }
function Write-Warn { param([string]$Message) Write-Host 'warn ' -ForegroundColor Yellow -NoNewline; Write-Host " $Message" }
function Die        { param([string]$Message) Write-Host ' err ' -ForegroundColor Red -NoNewline; Write-Host " $Message"; exit 1 }

function Get-PackageManager {
  if (Get-Command pnpm -ErrorAction SilentlyContinue) { return 'pnpm' }
  if (Get-Command npm  -ErrorAction SilentlyContinue) { return 'npm' }
  Die 'Neither pnpm nor npm found. Install one and retry.'
}

function Save-PinState {
  param([string]$Version)
  New-Item -ItemType Directory -Path $StateDir -Force | Out-Null
  Set-Content -Path $StateFile -Value $Version -Encoding ASCII
}

function Clear-PinState {
  Remove-Item -Path $StateFile -Force -ErrorAction SilentlyContinue
}

function Read-PinState {
  if (Test-Path $StateFile) { return (Get-Content $StateFile -Raw).Trim() }
  return ''
}

function Get-DroidCommand {
  Get-Command droid -ErrorAction SilentlyContinue | Select-Object -First 1
}

function Get-CurrentVersion {
  $cmd = Get-DroidCommand
  if (-not $cmd) { return '(not installed)' }
  $out = & droid --version 2>$null
  $v = @($out) | Where-Object { $_ -match '\d+\.\d+' } | Select-Object -First 1
  if ([string]::IsNullOrWhiteSpace($v)) { return '(unknown)' }
  return ([string]$v).Trim()
}

function Get-DroidSource {
  $cmd = Get-DroidCommand
  if (-not $cmd) { return 'none' }
  $path = $cmd.Source
  if (-not $path) { return "unknown ($($cmd.Name))" }

  if ($path -ieq $FactoryBin)          { return 'factory' }
  if ($path -imatch '\\npm\\')         { return 'npm' }
  if ($path -imatch '\\pnpm\\')        { return 'npm' }
  if ($path -imatch '\\node_modules\\'){ return 'npm' }
  return "unknown ($path)"
}

function Get-AvailableVersions {
  if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    Die "'npm' is required to query the registry but was not found in PATH."
  }
  $json = (& npm view droid versions --json 2>$null) -join ''
  if ([string]::IsNullOrWhiteSpace($json)) {
    Die 'Could not fetch versions. Check your network connection.'
  }
  return @($json | ConvertFrom-Json)
}

function Remove-FactoryBinary {
  # Windows locks a running .exe, so a plain delete fails when droid is open
  # (including when dvm itself was launched from inside a droid session).
  # Renaming a locked file is allowed, so fall back to that and clean up later.
  try {
    Remove-Item -Path $FactoryBin -Force
    Write-Ok 'Factory binary removed.'
    return
  } catch {
    $stale = "$FactoryBin.dvm-old"
    Remove-Item -Path $stale -Force -ErrorAction SilentlyContinue
    try {
      Move-Item -Path $FactoryBin -Destination $stale -Force
      Write-Ok "Factory binary was in use; moved aside to $stale"
    } catch {
      Die "Could not remove $FactoryBin ($($_.Exception.Message)). Close any running droid session and retry."
    }
  }
}

# ── commands ───────────────────────────────────────────────────────────

function Invoke-Status {
  $ver    = Get-CurrentVersion
  $src    = Get-DroidSource
  $pinned = Read-PinState

  Write-Host ''
  Write-Host '  Droid Version Manager ' -ForegroundColor White -NoNewline
  Write-Host "v$DvmVersion"
  Write-Host '  ─────────────────────────────'
  Write-Host '  Current version :' -ForegroundColor DarkGray -NoNewline
  Write-Host "  $ver"
  Write-Host '  Binary source   :' -ForegroundColor DarkGray -NoNewline
  Write-Host "  $src"
  Write-Host '  Pinned to       :' -ForegroundColor DarkGray -NoNewline
  if ($pinned) {
    Write-Host "  $pinned" -ForegroundColor Yellow
  } else {
    Write-Host '  (none — using factory channel)' -ForegroundColor Green
  }
  Write-Host ''
}

function Invoke-List {
  Write-Info 'Fetching available versions from npm registry...'
  $versions = Get-AvailableVersions
  $current  = Get-CurrentVersion
  $pinned   = Read-PinState

  Write-Host ''
  Write-Host '  Available droid versions' -ForegroundColor White
  Write-Host '  ───────────────────────'
  foreach ($v in $versions) {
    if ($v -eq $pinned) {
      Write-Host "  $v" -NoNewline; Write-Host '  ◀ pinned' -ForegroundColor Yellow
    } elseif ($v -eq $current) {
      Write-Host "  $v" -NoNewline; Write-Host '  ◀ current' -ForegroundColor Green
    } else {
      Write-Host "  $v"
    }
  }
  Write-Host ''
}

function Invoke-Pin {
  param([string]$Target)

  if ([string]::IsNullOrWhiteSpace($Target)) {
    Die 'Usage: dvm pin <version>  (e.g. dvm pin 0.61.0)'
  }

  $pm = Get-PackageManager

  Write-Info "Installing droid@$Target via $pm..."
  if ($pm -eq 'pnpm') { & pnpm i -g "droid@$Target" } else { & npm i -g "droid@$Target" }
  if ($LASTEXITCODE -ne 0) { Die "$pm failed to install droid@$Target." }

  if (Test-Path $FactoryBin) {
    Write-Info "Removing factory auto-updating binary at $FactoryBin..."
    Remove-FactoryBinary
  }

  Save-PinState $Target

  $resolved = Get-CurrentVersion
  Write-Ok "Pinned to droid@$resolved"
  Write-Host ''
  Write-Host '  Run ' -NoNewline; Write-Host 'dvm status' -ForegroundColor White -NoNewline
  Write-Host ' to confirm, or ' -NoNewline; Write-Host 'dvm unpin' -ForegroundColor White -NoNewline
  Write-Host ' to revert.'
  Write-Host ''
}

function Invoke-Unpin {
  $pinned = Read-PinState
  if (-not $pinned) {
    Write-Warn 'No version is currently pinned. Nothing to do.'
    return
  }

  $pm = Get-PackageManager

  Write-Info "Removing npm-installed droid ($pm rm -g droid)..."
  if ($pm -eq 'pnpm') { & pnpm rm -g droid 2>$null } else { & npm rm -g droid 2>$null }
  Write-Ok 'npm package removed.'

  Remove-Item -Path "$FactoryBin.dvm-old" -Force -ErrorAction SilentlyContinue

  Write-Info 'Reinstalling factory distribution channel...'
  $installer = Join-Path ([System.IO.Path]::GetTempPath()) "factory-cli-install-$([guid]::NewGuid().ToString('N')).ps1"
  try {
    Invoke-WebRequest -Uri $FactoryInstallUrl -OutFile $installer -UseBasicParsing
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installer
    if ($LASTEXITCODE -ne 0) { Die 'Factory installer failed.' }
  } finally {
    Remove-Item $installer -Force -ErrorAction SilentlyContinue
  }
  Write-Ok 'Factory installer executed.'

  Clear-PinState

  # Refresh PATH so the freshly installed binary resolves in this session.
  $env:PATH = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
              [Environment]::GetEnvironmentVariable('Path', 'User')

  $resolved = Get-CurrentVersion
  Write-Ok "Restored to factory channel (droid@$resolved)"
  Write-Host ''
}

function Invoke-Help {
  Write-Host ''
  Write-Host '  dvm' -ForegroundColor White -NoNewline
  Write-Host " — Droid Version Manager v$DvmVersion"
  Write-Host ''
  Write-Host '  USAGE' -ForegroundColor White
  Write-Host '    dvm <command> [args]'
  Write-Host ''
  Write-Host '  COMMANDS' -ForegroundColor White
  Write-Host '    status        ' -ForegroundColor Cyan -NoNewline; Write-Host '    Show current droid version, source and pin state'
  Write-Host '    list          ' -ForegroundColor Cyan -NoNewline; Write-Host '    List all available versions on the npm registry'
  Write-Host '    pin <version> ' -ForegroundColor Cyan -NoNewline; Write-Host '    Pin droid to a specific npm version (e.g. 0.61.0)'
  Write-Host '    unpin         ' -ForegroundColor Cyan -NoNewline; Write-Host '    Remove the pin and restore the factory channel'
  Write-Host '    current       ' -ForegroundColor Cyan -NoNewline; Write-Host '    Print the current droid version (machine-friendly)'
  Write-Host '    help          ' -ForegroundColor Cyan -NoNewline; Write-Host '    Show this help message'
  Write-Host ''
  Write-Host '  EXAMPLES' -ForegroundColor White
  Write-Host '    dvm pin 0.61.0    # downgrade to a known-good release'
  Write-Host '    dvm status        # check what you are running'
  Write-Host '    dvm unpin         # go back to factory auto-updates'
  Write-Host ''
  Write-Host '  PREREQUISITES' -ForegroundColor White
  Write-Host '    Node.js and pnpm or npm must be installed.'
  Write-Host ''
}

# ── main dispatch ──────────────────────────────────────────────────────
switch ($Command.ToLowerInvariant()) {
  'status'    { Invoke-Status }
  'list'      { Invoke-List }
  'ls'        { Invoke-List }
  'pin'       { Invoke-Pin $Rest[0] }
  'unpin'     { Invoke-Unpin }
  'current'   { Get-CurrentVersion }
  'help'      { Invoke-Help }
  '-h'        { Invoke-Help }
  '--help'    { Invoke-Help }
  'version'   { Write-Output "dvm $DvmVersion" }
  '-v'        { Write-Output "dvm $DvmVersion" }
  '--version' { Write-Output "dvm $DvmVersion" }
  default     { Die "Unknown command: $Command. Run 'dvm help' for usage." }
}

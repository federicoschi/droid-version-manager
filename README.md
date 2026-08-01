# dvm — Droid Version Manager

A tiny CLI to pin [Factory AI](https://factory.ai)'s `droid` CLI to a specific version when the auto-updating distribution channel is unstable, and revert cleanly when it stabilises.

Runs on **macOS/Linux** (bash) and **Windows 10/11** (PowerShell).

## Why

Factory ships `droid` through a self-updating binary — `~/.local/bin/droid` on macOS/Linux, `%USERPROFILE%\bin\droid.exe` on Windows. When a release introduces regressions, the only escape hatch is a manual dance of npm-installing an older version, deleting the auto-updater binary, and remembering to undo it all later. `dvm` wraps that entire workflow into two commands.

## Prerequisites

- **Node.js** (any recent version)
- **pnpm** or **npm** (dvm auto-detects whichever is available)
- **curl** (only needed for `dvm unpin` on macOS/Linux; Windows uses PowerShell)

## Install

### macOS / Linux

```bash
git clone https://github.com/<you>/droid-version-manager.git
cd droid-version-manager
./install.sh
```

This copies `dvm` to `~/.local/bin`. If that directory is not in your `PATH`, the installer will tell you what to add to your shell profile.

Or just copy the script directly:

```bash
curl -fsSL https://raw.githubusercontent.com/<you>/droid-version-manager/main/dvm -o ~/.local/bin/dvm
chmod +x ~/.local/bin/dvm
```

### Windows 10 / 11

```powershell
git clone https://github.com/<you>/droid-version-manager.git
cd droid-version-manager
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

This copies `dvm.ps1` and the `dvm.cmd` shim to `%USERPROFILE%\bin` (the same directory Factory's own installer uses) and adds it to your user `PATH` if it is not already there. Open a new terminal afterwards, then run `dvm status`.

Override the target directory with `-InstallDir` or the `DVM_INSTALL_DIR` environment variable.

The `dvm.cmd` shim means `dvm <command>` works identically from PowerShell, `cmd.exe`, and Windows Terminal. Under Git Bash / WSL, use the bash `dvm` script instead.

## Usage

### Check what you're running

```
$ dvm status

  Droid Version Manager v1.0.0
  ─────────────────────────────
  Current version :  0.61.0
  Binary source   :  npm
  Pinned to       :  0.61.0
```

### List available versions

```
$ dvm list

  Available droid versions
  ───────────────────────
  0.57.5
  0.57.6
  ...
  0.61.0  ◀ pinned
  0.62.0
  0.62.1
```

### Pin to a known-good release

```bash
dvm pin 0.61.0
```

This will:

1. Install `droid@0.61.0` globally via pnpm (or npm).
2. Remove the factory auto-updating binary (`~/.local/bin/droid`, or `%USERPROFILE%\bin\droid.exe` on Windows) if it exists.
3. Record the pin so `dvm status` reflects it.

On Windows, if `droid.exe` is locked because a droid session is running (including the one you may be typing this from), dvm renames it to `droid.exe.dvm-old` instead of failing, and cleans it up on `dvm unpin`.

### Unpin and restore factory updates

```bash
dvm unpin
```

This will:

1. Remove the npm-installed `droid` package.
2. Re-run Factory's official installer — `curl -fsSL https://app.factory.ai/cli | sh` on macOS/Linux, or the PowerShell installer at `https://app.factory.ai/cli/windows` on Windows.
3. Clear the pin state.

### All commands

| Command           | Description                                          |
| ----------------- | ---------------------------------------------------- |
| `dvm status`      | Show current version, binary source, and pin state   |
| `dvm list`        | List all versions available on the npm registry      |
| `dvm pin <ver>`   | Pin droid to a specific version                      |
| `dvm unpin`       | Remove the pin and restore the factory channel       |
| `dvm current`     | Print the current droid version (machine-friendly)   |
| `dvm help`        | Show usage information                               |
| `dvm --version`   | Print dvm's own version                              |

## How it works

`dvm` is a single script per platform with no dependencies beyond what's already on your machine — `dvm` (bash) for macOS/Linux, `dvm.ps1` (PowerShell 5.1+, no extra modules) for Windows. Pin state lives in `~/.local/state/dvm/pin` (respects `XDG_STATE_HOME`) or `%LOCALAPPDATA%\dvm\pin` on Windows, so it survives shell restarts. The core trick is the same manual workaround — install a specific version from npm and shadow the factory binary — but wrapped in a repeatable, reversible interface.

### Platform differences

| | macOS / Linux | Windows |
| --- | --- | --- |
| Script | `dvm` (bash) | `dvm.ps1` + `dvm.cmd` shim |
| Installer | `install.sh` | `install.ps1` |
| Factory binary | `~/.local/bin/droid` | `%USERPROFILE%\bin\droid.exe` |
| Pin state | `~/.local/state/dvm/pin` | `%LOCALAPPDATA%\dvm\pin` |
| Factory installer | `https://app.factory.ai/cli` | `https://app.factory.ai/cli/windows` |

## License

MIT

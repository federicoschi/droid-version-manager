# dvm — Droid Version Manager

A tiny CLI to pin [Factory AI](https://factory.ai)'s `droid` CLI to a specific version when the auto-updating distribution channel is unstable, and revert cleanly when it stabilises.

## Why

Factory ships `droid` through a self-updating binary at `~/.local/bin/droid`. When a release introduces regressions, the only escape hatch is a manual dance of npm-installing an older version, deleting the auto-updater binary, and remembering to undo it all later. `dvm` wraps that entire workflow into two commands.

## Prerequisites

- **Node.js** (any recent version)
- **pnpm** or **npm** (dvm auto-detects whichever is available)
- **curl** (only needed for `dvm unpin`)

## Install

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
2. Remove the factory auto-updating binary at `~/.local/bin/droid` if it exists.
3. Record the pin so `dvm status` reflects it.

### Unpin and restore factory updates

```bash
dvm unpin
```

This will:

1. Remove the npm-installed `droid` package.
2. Re-run Factory's official installer (`curl -fsSL https://app.factory.ai/cli | sh`).
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

`dvm` is a single bash script with no dependencies beyond what's already on your machine. It stores pin state in `~/.local/state/dvm/pin` (respects `XDG_STATE_HOME`) so it survives shell restarts. The core trick is the same manual workaround — install a specific version from npm and shadow the factory binary — but wrapped in a repeatable, reversible interface.

## License

MIT

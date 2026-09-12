# Tarvos

Tarvos is a Python-to-native compiler and CLI for statically analyzable,
compute-heavy Python workloads. It generates optimized standalone binaries
with a zero-administrator installation experience.

This is the **public distribution repository**. It contains installers,
documentation, the Python launcher, checksums, and downloadable releases.
The compiler implementation and private development workflow are maintained in
the private `repo-tech/tarvos` repository and are intentionally not published
here.

## Install Tarvos

### Windows graphical setup

Download `Tarvos-Setup-Windows-x86_64.exe` from the latest Release and launch
it like a normal Python, Node.js, or VS Code setup. It uses Tarvos blue
branding, installs under the current user's profile, registers the current
user's `PATH`, and does not require administrator rights.

The PowerShell scripts remain available for automated and developer installs,
but end users should use the downloadable setup executable.

From PowerShell:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\install-gui.ps1
```

The setup requires a published `v1.5.0` release in this repository. If the
release is not present yet, the installer reports that clearly instead of
showing an opaque GitHub 404.

For automation without the GUI:

```powershell
.\install.ps1
```

### Linux and macOS

```bash
curl --fail --location https://raw.githubusercontent.com/repo-tech/tarvos-engine/main/install.sh | bash
exec "$SHELL" -l
tarvos --version
```

The installer uses `~/.tarvos/bin`, verifies the downloaded checksum, and
updates the user's shell profile without requiring `sudo`.

### Python wrapper

```bash
python -m pip install .
tarvos --version
```

The wrapper downloads the matching release binary on first use and verifies
its SHA-256 checksum.

## First commands

```bash
tarvos doctor
tarvos run examples/fibonacci.py
tarvos build app.py --output app
tarvos package ./my-python-project --entry main.py --output-dir ./dist
```

## Updates and uninstall

Run the installer again with the desired `TARVOS_VERSION` to update. To
uninstall, remove `~/.tarvos/bin` (or `%USERPROFILE%\.tarvos\bin`) and remove
that directory from the current user's `PATH`.

## Release contract

Release automation runs from the private `repo-tech/tarvos` repository. Each
public release must publish these assets in this repository:

```text
Tarvos-Setup-Windows-x86_64.exe
Tarvos-Setup-Windows-x86_64.exe.sha256
tarvos-windows-x86_64.exe
tarvos-windows-x86_64.exe.sha256
tarvos-linux-x86_64
tarvos-linux-x86_64.sha256
tarvos-macos-x86_64
tarvos-macos-x86_64.sha256
```

This repository intentionally does not contain the compiler source.

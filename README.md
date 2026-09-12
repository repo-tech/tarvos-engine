# Tarvos Distribution

This repository contains the public Tarvos distribution surface:

- zero-admin Windows and Unix installers;
- the Python wrapper package;
- release documentation and checksums;
- downloadable, optimized Tarvos binaries.

The compiler implementation, internal tests, and development workflow are not
published here. They are maintained in the private `repo-tech/tarvos`
development repository.

## Install

### Windows

```powershell
.\install.ps1
```

The installer downloads `v1.5.0` into
`%USERPROFILE%\.tarvos\bin` and updates only the current user's `PATH`.
For a private fork, set `TARVOS_GITHUB_TOKEN` before running the installer.

### Linux and macOS

```bash
curl --fail --location https://raw.githubusercontent.com/repo-tech/tarvos-engine/main/install.sh | bash
```

The Unix installer stores the binary in `~/.tarvos/bin`. Add that directory to
your shell `PATH` if it is not already present.

### Python wrapper

```bash
python -m pip install .
tarvos --version
```

The wrapper downloads the matching release binary on first use and verifies
its SHA-256 checksum.

## Release contract

Release automation runs from the private `repo-tech/tarvos` repository. Each
public release must publish these assets here:

```text
tarvos-windows-x86_64.exe
tarvos-windows-x86_64.exe.sha256
tarvos-linux-x86_64
tarvos-linux-x86_64.sha256
tarvos-macos-x86_64
tarvos-macos-x86_64.sha256
```

This repository intentionally does not contain the compiler source.

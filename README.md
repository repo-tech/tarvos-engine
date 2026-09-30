# Tarvos Engine

[![Release](https://img.shields.io/badge/version-1.1.0--rc.6-blue.svg)](https://github.com/repo-tech/tarvos-engine/releases)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey.svg)]()

**Python to native Rust. No Rust installation required.**

Tarvos Engine is the public distribution layer for Tarvos 1.1.0-rc.6: a
Python-to-native Rust compiler and CLI for statically analyzable, compute-heavy
Python workloads. Point it at a `.py` file and get an optimized standalone
native executable — no Python runtime on the target, no `rustc` on the build
machine, and no administrator rights during install.

```bash
tarvos run kernel.py          # transpile, compile, and execute
tarvos build kernel.py -o kernel
```

This is the **public distribution repository**: installers, documentation, the
Python launcher, checksums, and downloadable releases. The compiler
implementation is developed privately in `repo-tech/tarvos`; this repository
owns everything a user touches.

## Why Tarvos

**A compute kernel written in Python leaves most of the machine unused.**
CPython executes each operation through an interpreter loop. Tarvos parses your
Python, type-checks it, lowers it to an intermediate representation, optimizes
that IR, and emits Rust that the compiler turns into machine code. On a
compute-bound kernel the difference is not marginal:

| | CPython 3.13.13 | Tarvos 1.1.0-rc.6 |
|---|---|---|
| Median execution | 1713.14 ms | **13.40 ms** |
| Minimum | 1445.00 ms | 11.54 ms |
| Needs Python at run time | yes | **no** |

That is **127.9× on the median** for the `fair_no_fold` kernel, with output
verified byte-identical to CPython. Read [BENCHMARKS.md](BENCHMARKS.md) for the
method and the caveats before quoting a number — the honest framing matters more
than the headline.

### Known issues, honestly stated

Two compiler bugs surfaced while validating this documentation, and one is
still open. All three are in the compiler repository and written up there.

- **Fixed in `1.1.0-rc.6`:** a tuple assignment inside a loop could leave a stale
  constant, so `fib` returned `0` instead of `832040`. The workload that
  reproduces it is now in the differential suite.
- **Fixed after `rc.6` was tagged:** a `return` inside an `except` handler
  produced Rust that did not compile (`error[E0426]`).
- **Still open:** native `try`/`except` lowers correctly but does not yet catch
  every exception type at run time. A `ZeroDivisionError` raised inside a `try`
  still aborts the native binary rather than reaching its handler.

  ```python
  def safe_div(a: int, b: int) -> int:
      try:
          return a // b
      except ZeroDivisionError:
          return -1
  ```

  CPython prints `5` then `-1`. The native build prints `5` and then panics.

**Treat native `try`/`except` as partial for now.** If your code relies on
catching an error to keep going, use CPython or
`tarvos run --python-fallback`. Every example in [EXAMPLES.md](EXAMPLES.md) was
run and verified on the current build.

Four things this project is built around:

- **No toolchain to install.** `tarvos toolchain install` fetches and verifies a
  pinned Rust channel for you. You install Tarvos, not a language ecosystem.
- **No silent fallbacks.** A construct outside the supported subset produces a
  named diagnostic, never a quietly different program.
- **Verified output, not assumed output.** Every release is gated on differential
  tests that compare compiled-binary stdout against CPython.
- **No administrator rights.** Everything lands under your user profile.

## Supported subset

Tarvos is **not** a drop-in CPython replacement and this repository does not
pretend otherwise. It targets statically analyzable, compute-heavy Python. At
this release the capability matrix covers **95 features — 52 supported, 18
partial, 24 unsupported, 1 planned**.

Native standard-library surface includes `math`, `time`, `os.path` (`join`,
`basename`, `dirname`, `exists`, `isfile`, `isdir`), `statistics`, and the
Python exception hierarchy with real `try`/`except`/`else`/`finally` and
`raise`.

Check before you build:

```bash
tarvos doctor
tarvos scan ./my-project
```

`scan` reports which loops and library calls are inside the native subset, so you
know what will compile before you rely on it.

## Install Tarvos

### Windows (graphical, recommended)

Download `Tarvos-Setup-Windows-x86_64.exe` from the latest Release and launch
it like a normal Python, Node.js, or VS Code setup. It installs under your user
profile, registers your `PATH`, and requires no administrator rights.

Automated install without the GUI:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\install.ps1
```

### Linux and macOS

```bash
curl --fail --location https://raw.githubusercontent.com/repo-tech/tarvos-engine/main/install.sh | bash
exec "$SHELL" -l
tarvos --version
```

The installer places the CLI in `~/.tarvos/bin`, verifies the downloaded
SHA-256 before installing, and never needs `sudo`.

### Python wrapper

```bash
python -m pip install .
tarvos --version
```

The wrapper downloads the matching release binary on first use and verifies its
SHA-256.

### First run: get a compiler

The released binary needs a Rust toolchain the first time you build. Tarvos
installs and verifies one for you:

```bash
tarvos toolchain install     # pinned and verified, into ~/.tarvos/toolchain
tarvos toolchain --status    # show what resolved and why
tarvos toolchain --verify    # re-run validation stage by stage
```

If you already have Rust and want to use it instead, pass `--system-rust`; that
compiler is validated before use and is never silently swapped for another.

## Everyday commands

```bash
tarvos doctor                                   # environment and toolchain check
tarvos run kernel.py                            # transpile, compile, run
tarvos build kernel.py -o kernel                # standalone native binary
tarvos compile kernel.py out.rs --source-only   # Rust only, no compiler needed
tarvos scan ./my-project                        # what is inside the native subset
tarvos package ./my-project --entry main.py     # Cargo project plus dist binary
```

More worked examples: [EXAMPLES.md](EXAMPLES.md).
Worked benchmark walkthrough: [SHOWCASE.md](SHOWCASE.md).

## Documentation

| Document | What it covers |
|---|---|
| [BENCHMARKS.md](BENCHMARKS.md) | Benchmark method, the measured matrix, and how to read a result honestly |
| [SHOWCASE.md](SHOWCASE.md) | End-to-end walkthrough of a real kernel with before/after timings |
| [EXAMPLES.md](EXAMPLES.md) | Copy-paste examples per task, with what each one produces |
| [RELEASE_NOTES.md](RELEASE_NOTES.md) | What shipped in each release |
| [installer/README.md](installer/README.md) | Windows setup executable details |

## Updates and uninstall

Re-run the installer with a different `TARVOS_VERSION` to update. To uninstall,
remove `~/.tarvos/bin` (or `%USERPROFILE%\.tarvos\bin`) and drop that directory
from your user `PATH`. The managed toolchain lives separately in
`~/.tarvos/toolchain` and can be removed independently.

## Release contract

Tarvos 1.1.0-rc.6 is the tuple-assignment correctness release. Release
automation runs from the private compiler repository and publishes these assets
here:

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

Every asset ships with a `.sha256` that the installers verify before writing
anything to disk.

This repository intentionally does not contain the compiler source.

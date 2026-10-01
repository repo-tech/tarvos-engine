# Tarvos Compiler

[![Release](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/repo-tech/tarvos-engine/releases)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey.svg)]()

**Python to native Rust. No Rust installation required.**

Tarvos Engine is the public distribution layer for Tarvos 1.0.0: a
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
implementation is developed privately; this repository owns everything a user
touches.

## Why Tarvos

**A compute kernel written in Python leaves most of the machine unused.**
CPython executes each operation through an interpreter loop. Tarvos parses your
Python, type-checks it, lowers it to an intermediate representation, optimizes
that IR, and emits Rust that the compiler turns into machine code. On a
compute-bound kernel the difference is not marginal:

| | CPython 3.13.13 | Tarvos 1.0.0 |
|---|---|---|
| Median execution | 1713.14 ms | **13.40 ms** |
| Minimum | 1445.00 ms | 11.54 ms |
| Needs Python at run time | yes | **no** |

That is **127.9× on the median** for the `fair_no_fold` kernel, with output
verified byte-identical to CPython. Read [BENCHMARKS.md](BENCHMARKS.md) for the
method and the caveats before quoting a number — the honest framing matters more
than the headline.

### Bugs found and fixed while writing these docs

Three compiler bugs surfaced when the examples on this page were run and their
output compared against CPython. All three are fixed and covered by tests. They
are written up here because they are the reason to trust the numbers on this
page rather than take them on faith.

- **A tuple assignment inside a loop could leave a stale constant.** `fib`
  returned `0` instead of `832040`. The binary built, ran, and printed a
  plausible integer. The workload that reproduces it is now in the differential
  suite.
- **A `return` inside an `except` handler produced Rust that did not compile**
  (`error[E0426]`).
- **A zero divisor aborted the process instead of reaching its handler.**
  `a // b` with `b == 0` called `.expect("ZeroDivisionError")` and killed the
  binary, so `except ZeroDivisionError` was unreachable. Float `/` was worse
  than a crash: it produced `inf` and the program carried on with a wrong
  number.

  ```python
  def safe_div(a: int, b: int) -> int:
      try:
          return a // b
      except ZeroDivisionError:
          return -1

  print(safe_div(10, 2))   # 5
  print(safe_div(1, 0))    # -1
  ```

  Both lines now match CPython exactly, for `//`, `/` on integers, `/` on
  floats, and `//` on floats.

Exception handling is native and the common cases are correct. What is still
missing is listed in [COMPATIBILITY.md](COMPATIBILITY.md): bare `raise`,
exception chaining, user-defined exception classes, and traceback formatting on
an uncaught exception.

Four things this project is built around:

- **No toolchain to install.** `tarvos toolchain --install` fetches and verifies a
  pinned Rust channel for you. You install Tarvos, not a language ecosystem.
- **No silent fallbacks.** A construct outside the supported subset produces a
  named diagnostic, never a quietly different program.
- **Verified output, not assumed output.** Every release is gated on differential
  tests that compare compiled-binary stdout against CPython.
- **No administrator rights.** Everything lands under your user profile.

## Supported subset

95 features are classified, and the classification is published rather than
implied: 52 supported, 18 partial, 24 unsupported, 1 planned. "Supported" means
a differential test compiles the construct to a native binary and compares its
output against CPython — not that it merely compiles.

**Read [COMPATIBILITY.md](COMPATIBILITY.md) before you port anything.** It lists
every supported feature, every partial one with the exact limit, and everything
that is refused.

The short version: variables, arithmetic, control flow, typed functions,
recursion, lists, dictionaries, strings, tuples, f-strings, local imports,
`try`/`except`/`else`/`finally` with `raise`, and the `math`, `time`, `os.path`,
`statistics` and `json` surfaces that the subset covers.

What it is not: a CPython replacement, a NumPy or Pandas substitute, or a
speedup for I/O-bound work. GUI toolkits, networking, metaprogramming, and
third-party packages are outside the subset by design and are reported as such.

`tarvos scan ./your-project` tells you where a project stands before you invest
in a migration.

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
tarvos toolchain --install     # pinned and verified, into ~/.tarvos/toolchain
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
| [COMPATIBILITY.md](COMPATIBILITY.md) | Every supported feature, every partial one with its exact limit, and what is refused |
| [ROADMAP.md](ROADMAP.md) | Where the compiler is going, and what is deliberately out of scope |
| [BENCHMARKS.md](BENCHMARKS.md) | Benchmark method, the measured matrix, and how to read a result honestly |
| [SHOWCASE.md](SHOWCASE.md) | End-to-end walkthrough of a real kernel with before/after timings |
| [EXAMPLES.md](EXAMPLES.md) | Copy-paste examples per task, with what each one produces |
| [RELEASE_NOTES.md](RELEASE_NOTES.md) | What shipped in each release |
| [installer/README.md](installer/README.md) | Windows setup executable details |

## Credits

Tarvos is built and maintained by **Repo-Tech**. The compiler is developed
privately; this repository is the public distribution layer, its documentation,
and its release history.

## Versioning

Tarvos Engine has its **own version line**, separate from the compiler's.

The compiler ships many release candidates as it develops. The public
distribution is cut when there is something worth publishing. That means a
compiler release does **not** automatically become a product release here, and
the version you see on this page is not the compiler's internal version.

`VERSION` in this repository is the single source of truth for the public
version. The release pipeline reads it, so cutting a public release is a change
to this repository and nothing else.

## Release history

| Version | What it was |
|---|---|
| `v1.0.0` | First stable public release. Managed toolchain, measured performance, full documentation, and an honest account of the open exception-handling limitation. |
| `v1.1.0-rc.2` | Early pre-release. |
| `v1.1.0-rc.1` | Early pre-release. |

The `v1.1.0-rc.*` pre-releases tracked the compiler's release candidates. They
are superseded by `v1.0.0`, which replaces that scheme with an independent one.

Full detail for each release is in [RELEASE_NOTES.md](RELEASE_NOTES.md).

## Updates and uninstall

Re-run the installer with a different `TARVOS_VERSION` to update. To uninstall,
remove `~/.tarvos/bin` (or `%USERPROFILE%\.tarvos\bin`) and drop that directory
from your user `PATH`. The managed toolchain lives separately in
`~/.tarvos/toolchain` and can be removed independently.

## Release contract

Tarvos 1.0.0 is the first stable public release. Release
automation runs from the compiler's build pipeline and publishes these assets
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

<p align="center">
<img width="1798" height="576" alt="logo" src="https://github.com/user-attachments/assets/39b79d21-da41-497b-b42a-2d2afdcba3cd" />
</p>

<div align="center">
<h1>
  <img src="https://github.com/user-attachments/assets/0ed06e55-2cd3-46f5-ade8-539be53e1ba8" alt="tarvos" height="40" align="absmiddle">
  Tarvos
</h1>

[![CI](https://github.com/repo-tech/Tarvos/actions/workflows/ci.yml/badge.svg)](https://github.com/repo-tech/Tarvos/actions/workflows/ci.yml)
[![Release](https://img.shields.io/badge/version-1.3.1-blue.svg)](https://github.com/repo-tech/Tarvos/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey.svg)]()

</div>
**Python to native Rust. No Rust installation required.**

Tarvos Engine is the public distribution layer for Tarvos 1.3.1: a
Python-to-native Rust compiler and CLI for statically analyzable, compute-heavy
Python workloads. Point it at a `.py` file and get an optimized standalone
native executable — no Python runtime on the target, no `rustc` on the build
machine, and no administrator rights during install.

```bash
tarvos run hello.py          # transpile, compile, and execute
tarvos build hello.py -o hello.exe
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

| | CPython 3.13.13 | Tarvos 1.3.1 |
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

### What "standalone" means, precisely

A native Tarvos binary embeds its own lowered Rust. Copy it to a machine with no
Python, no packages, no Rust, and no Tarvos, and it runs. That is the claim, and
`tarvos validate-artifact` will tell you whether an artifact is entitled to it:

```console
$ tarvos validate-artifact hello.exe
Artifact:          hello.exe
Format:            PE
Target:            windows-x86_64
Native:            YES
Python required:   NO
Temporary .py:     NO
External packages: NONE
Status:            PASS
```

The format is read from the file's own header, not from its name, so a binary
built for the wrong platform is reported as the mismatch it is rather than
trusting the `.exe` suffix.

If a program imports something the compiler cannot lower — `flask`, `requests`,
`numpy` outside its supported shapes — the build **stops and names it**:

```console
$ tarvos build server.py
TARVOS NATIVE COMPILATION BLOCKED

Unbuildable dependencies:
  EXTERNAL_RUNTIME  flask

Choose:
  1. Rewrite this part with a native module (math, time, os, os.path, json, statistics)
  2. Run it as Python on a machine that has these packages installed: `tarvos run`
  3. Build a compatibility launcher and accept that it needs Python at run time:
     `tarvos build --compat-launcher`
```

You can still get a working file for such a program by asking for it explicitly
with `--compat-launcher`. It is a single executable that carries its own source
and runs it through the target machine's Python. **It is not a native binary**, it
needs Python and every package your program imports installed on the machine that
runs it, and its manifest says so:

```console
$ tarvos validate-artifact server.exe
Native:            NO
Python required:   YES
External packages: flask
Status:            COMPATIBILITY
```

Every `tarvos build` writes a `<artifact>.tarvos-manifest.json` beside what it
produced, so you can check this claim later rather than trusting it.

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

### Names that change type

Since 1.3.0 a variable may change type and still compile natively:

```python
x = 0
x = "cecece"
print(x)          # cecece
```

A name that genuinely changes type is emitted as a tagged runtime value so
both assignments agree on one Rust type. Arithmetic, comparison, concatenation
and truthiness on such a name follow Python's rules — `int + float` widens, `/`
yields a float, dividing by zero raises `ZeroDivisionError`, `"a" + 1` raises
the same `TypeError` CPython raises.

Only names that actually change type are boxed. A program with fixed types keeps
its plain `i64`/`f64`/`String` representation and never pays for the tagged-value
runtime, which is emitted only when one is reachable.

### Refused rather than silently wrong

Anything outside the subset is named and the build stops. This is a deliberate
choice: a tool that says "no" is more useful than one that compiles a subtly
different program. In particular Tarvos will not hand your program to CPython
behind your back. If you want CPython semantics for something outside the subset,
run it with `tarvos run --python-fallback` and know that you asked for it.

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

## Upgrade

```powershell
irm https://github.com/repo-tech/tarvos-engine/releases/download/v1.3.1/install.ps1 | iex
tarvos --version
```

### Linux

```bash
curl -fsSL https://github.com/repo-tech/tarvos-engine/releases/download/v1.3.1/install.sh | sh
tarvos --version
```

The installer is fetched from the release rather than from
`raw.githubusercontent.com` on purpose. On a measured connection the release
asset arrived in 0.9s where the raw host took 30s for the same 1.3 kB script,
which reads to a user as a frozen installer rather than as a slow one. If you
prefer the raw URL it still works, it is just the slower of the two:

```bash
curl --fail --location https://raw.githubusercontent.com/repo-tech/tarvos-engine/main/install.sh | bash
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
tarvos run hello.py                            # transpile, compile, run
tarvos build hello.py -o hello                # standalone native binary
tarvos validate-artifact hello                 # what does it need to run?
tarvos compile hello.py out.rs --source-only   # Rust only, no compiler needed
tarvos scan ./my-project                        # what is inside the native subset
tarvos package ./my-project --entry main.py     # Cargo project plus dist binary
```

More worked examples: [EXAMPLES.md](EXAMPLES.md).
Worked benchmark walkthrough: [SHOWCASE.md](SHOWCASE.md).

## Documentation

| Document | What it covers |
|---|---|
| [LIMITATIONS.md](LIMITATIONS.md) | What Tarvos cannot do and why — start here if you are deciding whether to port |
| [COMPATIBILITY.md](COMPATIBILITY.md) | Every supported feature, every partial one with its exact limit, and what is refused |
| [ROADMAP.md](ROADMAP.md) | Where the compiler is going, and what is deliberately out of scope |
| [BENCHMARKS.md](BENCHMARKS.md) | Benchmark method, the measured matrix, and how to read a result honestly |
| [SHOWCASE.md](SHOWCASE.md) | End-to-end walkthrough of a real kernel with before/after timings |
| [EXAMPLES.md](EXAMPLES.md) | Copy-paste examples per task, with what each one produces |
| [RELEASE_NOTES.md](RELEASE_NOTES.md) | What shipped in each release |
| [installer/README.md](installer/README.md) | Windows setup executable details |

## Benchmarks
<p align="center">
  <img width="850" height="fit-content" alt="tarvos_benchmark_comparison" src="https://github.com/user-attachments/assets/26abac08-da2c-47ea-9bc6-429479371bb2" />
</p>
<p align="center">
  <img width="850" height="fit-content" alt="tarvos_benchmark_source_workloads_complete" src="https://github.com/user-attachments/assets/df97e5fe-b6c9-4167-899c-0da974a9880d" />
</p>

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
| `v1.3.1` | Maintenance release. Version synchronization across both repositories, two native-codegen fixes (float division zero-guard, `sum()` over a range), and this documentation pass. |
| `v1.3.0` | First stable release with native dynamic typing: ordinary Python compiles instead of silently falling back to CPython. |
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

Tarvos 1.3.1 is the first stable public release. Release
automation runs from the compiler's build pipeline and publishes these assets
here:

```text
Tarvos-Setup-Windows-x86_64.exe
Tarvos-Setup-Windows-x86_64.exe.sha256
tarvos-windows-x86_64.exe
tarvos-windows-x86_64.exe.sha256
tarvos-linux-x86_64
tarvos-linux-x86_64.sha256
```

Every asset ships with a `.sha256` that the installers verify before writing
anything to disk.

**There is no macOS asset.** macOS was removed from the build and release
matrices in 1.3.0 and is not coming back in this line. On macOS the launcher
fails with an explicit unsupported-platform message naming `TARVOS_VERSION`
rather than downloading something that will not run. Serving an x86_64 binary to
Apple silicon would work only under Rosetta, which costs memory the user may not
have and fails outright without it - promising it silently is worse than
refusing.

**Windows and Linux x86_64 only.** There is no 32-bit and no aarch64 build.
Running a 32-bit binary on a 64-bit host would need WoW64 emulation, and an
aarch64 artifact would have to be cross-compiled and tested on real ARM hardware
before it could be published honestly.

This repository intentionally does not contain the compiler source.

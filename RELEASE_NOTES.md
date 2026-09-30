# Tarvos Engine 1.0.0

The first stable public release of Tarvos Engine.

This is not a rebrand of an early preview. It is the point at which the product
has a working compiler, a verified install path on all three platforms, a
measured performance result, and a documented compatibility boundary — and,
just as importantly, an honest account of what it still cannot do.

## What Tarvos Engine is

A Python-to-native-Rust compiler and the distribution layer that ships it. You
install one thing, you point it at a `.py` file, and you get a standalone native
executable:

- **No Rust installation.** `tarvos toolchain install` fetches and verifies a
  pinned compiler for you. You are not asked to become a Rust developer to use
  a Python compiler.
- **No Python at run time.** The output is a native binary. The machine it runs
  on does not need an interpreter.
- **No administrator rights.** Everything lands under your user profile on
  Windows, `~/.tarvos` on Linux and macOS.
- **No silent fallbacks.** Code outside the supported subset produces a named
  diagnostic, never a quietly different program.

## What is in this release

### Performance, measured

One deterministic integer kernel, 1 warm-up run plus 7 samples, medians
compared, and output byte-compared against CPython:

| Runtime | Median | Min | Max |
|---|---|---|---|
| CPython 3.13.13 | 1713.14 ms | 1445.00 ms | 3326.79 ms |
| **Tarvos** | **13.40 ms** | 11.54 ms | 14.94 ms |
| hand-written Rust 1.98.0 | 29.28 ms | 28.64 ms | 29.65 ms |

**127.9× on the median**, with byte-identical output. Compile time (12.71 s) is
reported separately and is not part of that ratio. The caveats — one workload,
one machine, a noisy CPython baseline, and the workload classes where this does
*not* apply — are in [BENCHMARKS.md](BENCHMARKS.md) and are part of the claim,
not an appendix to it.

### Correctness

Every release is gated on a differential suite that compiles each workload to a
native binary and compares its stdout against CPython. At this release:

| Gate | Result |
|---|---|
| Differential parity | 20 passed, 0 failed, 1 skipped |
| Workspace test suite | 0 failures |
| Capability matrix | 95 features: 52 supported, 18 partial, 24 unsupported, 1 planned |
| Formatting and version gates | pass |

The skipped case is a competitor-comparison harness that imports modules outside
the native subset. It is reported as skipped rather than dropped from the
denominator.

### Supported subset

95 features are classified, and the classification is published rather than
implied: 52 supported, 18 partial, 24 unsupported, 1 planned. The native
standard-library surface includes `math`, `time`, `os.path` (`join`, `basename`,
`dirname`, `exists`, `isfile`, `isdir`), `statistics`, and the Python exception
hierarchy. `tarvos scan ./your-project` tells you where a project stands before
you invest in a migration.

### Installation

| Platform | Method | Needs admin |
|---|---|---|
| Windows | `Tarvos-Setup-Windows-x86_64.exe`, or `install.ps1` | No |
| Linux | `install.sh` | No |
| macOS | `install.sh` | No |
| Any | `pip install .` (downloads and verifies the binary) | No |

Every asset ships with a `.sha256` that the installers verify before writing
anything to disk.

## Two compiler bugs found while validating this release

Both were found by running the documentation examples and comparing against
CPython, and both are written up in the compiler repository. They are recorded
here because they shaped this release.

- **A tuple assignment inside a loop returned a stale constant.** This loop:

  ```python
  def fib(n: int) -> int:
      a = 0
      b = 1
      for _ in range(n):
          a, b = b, a + b
      return a
  ```

  returned `0` instead of `832040`. The optimizer recorded `a = 0` as a known
  constant and never learned that the tuple assignment rebinds it, so
  `return a` compiled to `return 0_i64`. The binary built, linked, ran, and
  printed a plausible integer.

  It survived because writing the initial values on one line — `a, b = 0, 1` —
  does not trigger it, so the more idiomatic spelling happened to be the working
  one. Fixed, and the workload that reproduces it is now in the differential
  suite so it is checked against CPython rather than only by a unit assertion.

- **A `return` inside an `except` handler produced Rust that did not compile.**
  The `try` body lowers to a labelled block; the handler was still emitted
  against that block after it had closed, producing
  `error[E0426]: use of undeclared label`. Fixed.

A parity guarantee is only as strong as the programs fed through it. "20 of 21
passing" says nothing about the shape you never thought to test, and the honest
lesson from this release is that our corpus had a hole in it.

## Still open, and stated rather than hidden

Native `try`/`except` lowers correctly but **does not yet catch every exception
type at run time**. A `ZeroDivisionError` raised inside a `try` still aborts the
native binary instead of reaching its handler:

```python
def safe_div(a: int, b: int) -> int:
    try:
        return a // b
    except ZeroDivisionError:
        return -1
```

CPython prints `5` then `-1`. The native build prints `5` and then panics.

A `try` whose body returns without raising works correctly, and handler bodies
that `return` compile and run. **If your code depends on catching an error to
continue, keep it on CPython** or use `tarvos run --python-fallback`. This is
tracked as an open bug; it is written here because a compiler that quietly
produces a crashing binary is worse than one that states its limit.

## What this release does not claim

- Not a CPython replacement. Dynamic Python, reflection, metaprogramming, and
  arbitrary third-party imports are outside the native subset.
- Not a NumPy, Pandas, TensorFlow, or PyTorch replacement. If your numeric work
  lives in those libraries, this is the wrong tool.
- Not a speedup for I/O-bound programs. The interpreter was never the
  bottleneck there.
- No comparison against PyPy, Numba, Nuitka, or Codon is claimed: they were not
  installed on the measurement machine, and they are reported as unavailable
  rather than quietly omitted.

## Versioning

Tarvos Engine is versioned **independently** of the compiler. The compiler ships
many release candidates; the public distribution is cut when there is
worthwhile. A compiler release does not automatically become a product release
here, and this repository's `VERSION` file is the single source of truth for
the public version line.

## Earlier pre-releases

`v1.1.0-rc.1` and `v1.1.0-rc.2` were early pre-releases that tracked the
compiler's release candidates. They are superseded by this release, which
replaces their tag scheme with an independent one.

## Documentation

| Document | Covers |
|---|---|
| [README.md](README.md) | Product, subset, install on all three platforms |
| [BENCHMARKS.md](BENCHMARKS.md) | Method, measured matrix, how to read a result |
| [EXAMPLES.md](EXAMPLES.md) | Worked examples, each verified against CPython |
| [SHOWCASE.md](SHOWCASE.md) | One kernel, end to end |

This repository intentionally does not contain the compiler source.

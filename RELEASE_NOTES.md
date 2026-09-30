# Tarvos Engine 1.1.0-rc.6

## Highlights

- Installer and Python wrapper defaults now target `v1.1.0-rc.6`.
- Distribution metadata is aligned with the compiler repository's release
  candidate and documented compatibility boundary.
- Benchmark numbers in `BENCHMARKS.md` were re-measured on the `rc.6` build with
  the documented method: 1 warm-up run, 7 samples, medians compared, and output
  parity enforced against CPython.
- This release does not claim full CPython, NumPy, Pandas, TensorFlow, or
  PyTorch native conversion.

## Known issues

Two compiler bugs found while validating the documentation examples. Both are
in the compiler repository, not here, and both are written up there.

- **A tuple assignment inside a loop could return a stale constant.** A
  Fibonacci written as `a = 0; b = 1; for ...: a, b = b, a + b; return a`
  returned `0` instead of `832040`. Fixed in `1.1.0-rc.6`; the workload that
  reproduces it is now part of the differential suite. The one-line form
  `a, b = 0, 1` was never affected.
- **A `return` inside an `except` handler produced Rust that did not compile.**
  The handler was emitted against a labelled block that had already been
  closed, so the generated binary failed to build with `error[E0426]`. Fixed
  after `rc.6` was tagged, on the compiler repository's `main`.

### Still open, and it matters

Native exception handling **compiles and lowers correctly but does not yet
catch every exception type at run time.** Specifically, a `ZeroDivisionError`
raised inside a `try` still aborts the native binary instead of reaching its
`except` handler:

```python
def safe_div(a: int, b: int) -> int:
    try:
        return a // b
    except ZeroDivisionError:
        return -1
```

On CPython this prints `5` then `-1`. On the current build it prints `5` and
then panics. A `try` whose body returns without raising works correctly, and
handler bodies that `return` now compile and run.

**Treat native `try`/`except` as partial.** If your code depends on catching an
error to continue, either run it through CPython or use
`tarvos run --python-fallback`. This is documented rather than hidden because a
compiler that silently produces a crashing binary is worse than one that
admits a limit.

The canonical compiler implementation and release build remain in
[`repo-tech/tarvos`](https://github.com/repo-tech/tarvos).

Tarvos Engine 1.0.0 remains the previous stable public distribution for Tarvos.

This repository provides the user-facing release layer:

- Windows setup and user-local installation.
- Linux and macOS shell installation.
- Python wrapper metadata.
- Release checksums and downloadable binary contracts.
- Product documentation and benchmark guidance.

The compiler implementation is maintained in
[`repo-tech/tarvos`](https://github.com/repo-tech/tarvos). The previous stable
tag is `v1.0.0`; this distribution tracks the `v1.1.0-rc.6` candidate.

Tarvos targets a statically analyzable Python subset and reports unsupported
dynamic features explicitly rather than promising full CPython compatibility.
The native standard-library surface currently includes `math`, `time`, and
the supported `os.path` operations documented in the compiler repository.

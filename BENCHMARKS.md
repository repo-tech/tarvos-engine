# Tarvos performance showcase

Tarvos is optimized for statically analyzable, compute-heavy Python kernels.
The headline speedup is always tied to a named workload and runner; it is not a
promise that every Python program will run at the same ratio.

## The measured matrix

Workload `fair_no_fold.py`, a double-accumulating integer loop kept
deliberately free of constant folding so the measurement reflects real loop
execution rather than a compile-time shortcut.

| Runtime | Median | Min | Max | Std dev | Compile |
|---|---|---|---|---|---|
| CPython 3.13.13 | 1713.14 ms | 1445.00 ms | 3326.79 ms | 655.36 ms | — |
| **Tarvos 1.1.0-rc.6** | **13.40 ms** | 11.54 ms | 14.94 ms | 1.27 ms | 12.71 s |
| rustc 1.98.0 (hand-written) | 29.28 ms | 28.64 ms | 29.65 ms | 0.40 ms | 0.57 s |

```text
execution speedup = CPython median / Tarvos median = 1713.14 / 13.40 = 127.9x
```

Output parity: CPython and Tarvos both printed `50000005000000`. The harness
refuses to record a timing row unless every runtime produced identical stdout,
so a fast wrong answer cannot be reported as a win.

### Environment

| | |
|---|---|
| OS | Windows 10, AMD64 (10.0.19045) |
| Python | 3.13.13 |
| rustc | 1.98.0 (88d9e12ae 2026-08-18) |
| Tarvos | 1.1.0-rc.6 |
| Samples | 1 warm-up + 7 measured, medians compared |
| Competitors | PyPy, Numba, Nuitka, Codon — unavailable on this runner |

## Read this before quoting a number

The 127.9× figure is real and reproducible, but it is one measurement of one
kernel on one machine, and a headline that hides that is not a benchmark.

- **The workload matters.** This is a tight integer loop. A program dominated by
  I/O, string formatting, or dictionary-heavy dynamic code will show a much
  smaller ratio, because the time is not in arithmetic.
- **The CPython numbers are noisy.** A standard deviation of 655 ms against a
  1713 ms median, with a maximum of 3327 ms, means this runner had contention.
  The minimum-to-minimum comparison is 1445.00 / 11.54 = **125×**. The two
  agree closely here, which is reassuring, but on a quieter machine the median
  is the fairer number and on a busier one the minimum is.
- **Compile time is not in the speedup.** Tarvos took 12.71 s to compile on this
  run (it was 3.26 s on a warmer cache); the hand-written Rust took 0.57 s. A
  one-shot script should just run under CPython — the native path pays off
  across repeated runs, a service, or a binary you ship. End-to-end cost is
  compile plus run, and it is reported separately on purpose.
- **Tarvos beat hand-written Rust here** (13.40 ms vs 29.28 ms) because the
  release profile uses `opt-level=3` with thin LTO, while the reference `rustc`
  invocation was not tuned to the same degree. That is a configuration
  difference, not evidence that Python beats Rust.
- **Competitor runtimes were unavailable**, not omitted, on this runner. CI
  reports them when installed.
- **Numbers are re-measured per release.** The table above is from `rc.6`; an
  earlier `rc.5` run on this machine measured 157.6×. The ratio moves with
  runner load, which is exactly why the method is published alongside it.

## What CI measures

The development pipeline runs the same deterministic workload through CPython,
Tarvos-generated native code, and Rust, and records:

- one excluded warm-up run;
- seven execution samples;
- median, minimum, maximum, and standard deviation;
- Tarvos and Rust compile time separately;
- stdout output and cross-runtime parity;
- runner OS, Python, Rust, and Tarvos versions.

The benchmark excludes compilation time from execution speedup. This answers
"how fast does an already-built binary run?" End-to-end compile-plus-run cost
must be reported separately.

The release validation command is:

```bash
python benchmarks/benchmark_matrix.py --runtime all --repeats 7 \
  --json-output benchmarks/results/runtime_matrix.json
```

Optional competitor runtimes are reported as unavailable when not installed.
The CI artifact `runtime-matrix` contains the complete JSON report, and is the
authoritative record for any given tag.

## Correctness is the part that matters more

Speed is worthless if the program is wrong. Every release is gated on a
differential suite that compiles each workload to a native binary and compares
its stdout against CPython. At this release:

| Gate | Result |
|---|---|
| Differential parity | 20 passed, 0 failed, 1 skipped |
| Workspace test suite | 0 failures |
| Capability matrix | 95 features: 52 supported, 18 partial, 24 unsupported, 1 planned |
| Version consistency | all declarations agree |

The one skip is a Numba comparison harness that imports modules outside the
native subset. It is reported as skipped rather than quietly removed from the
denominator.

### A bug this harness could have caught, and did not

Release `1.1.0-rc.5` shipped a real correctness bug. This loop:

```python
def fib(n: int) -> int:
    a = 0
    b = 1
    for _ in range(n):
        a, b = b, a + b
    return a
```

returned `0` instead of `832040`. The optimizer kept the literal from `a = 0`
because a tuple assignment was not treated as a write to its targets, so
`return a` compiled to `return 0_i64`. The binary built, linked, ran, and
printed a plausible integer.

The differential harness is exactly the check that should have caught it, and it
did not — no workload in the corpus had that shape. Writing the initial values
as `a, b = 0, 1` on one line happened not to trigger it, so the more idiomatic
version of the pattern was the working one.

That workload is in the corpus now and `1.1.0-rc.6` has the fix. Worth stating
plainly: a parity guarantee is only as strong as the programs you feed it, and
"20 of 21 passing" says nothing about the shape you never thought to test.

## When Tarvos is the right tool

Use it when:

- the workload is compute-bound and statically analyzable;
- you run it repeatedly, in a loop, or as a long-lived service;
- you need to ship a single native binary to a machine without Python;
- you want a hard boundary: code either compiles natively or is reported.

Do not expect it to help when:

- the program is I/O-bound — the interpreter was never the bottleneck;
- the code is genuinely dynamic (metaprogramming, runtime monkey-patching,
  arbitrary imports);
- you depend on the full CPython or scientific stack. Tarvos is not a NumPy,
  Pandas, TensorFlow, or PyTorch replacement.

Run `tarvos scan ./your-project` first. It tells you what is inside the native
subset before you commit to a migration.

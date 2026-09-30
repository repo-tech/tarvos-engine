# Tarvos showcase

A complete walkthrough: take one Python kernel, measure it, compile it, and
check that the fast answer is also the correct answer.

Every number on this page was produced on the machine described below, with the
method in [BENCHMARKS.md](BENCHMARKS.md).

## The kernel

```python
def compute(limit: int, bias: int) -> int:
    total = 0
    for i in range(limit + 1):
        total += i + bias
    return total


print(compute(10_000_000, 0))
```

This is deliberately a plain loop. No `numpy`, no clever tricks, just the thing
people actually write when the algorithm is settled and the machine is slow.

## The result

| | Median | Min | Max | Std dev |
|---|---|---|---|---|
| CPython 3.13.13 | 1713.14 ms | 1445.00 ms | 3326.79 ms | 655.36 ms |
| **Tarvos 1.1.0-rc.6** | **13.40 ms** | 11.54 ms | 14.94 ms | 1.27 ms |
| rustc 1.98.0, hand-written | 29.28 ms | 28.64 ms | 29.65 ms | 0.40 ms |

**127.9× on the median.** Both CPython and the native binary printed
`50000005000000` — the harness refuses to record a timing row unless every
runtime's stdout matches, so this is not a fast wrong answer.

Compile times, reported separately because they are not part of the speedup:

| | Compile |
|---|---|
| Tarvos | 12.71 s |
| hand-written Rust | 0.57 s |

Tarvos paid about 12 seconds to produce a binary that then runs in 13
milliseconds. If you run this once and throw it away, CPython wins. If you run
it ten thousand times, in a service, or ship the binary to a machine with no
Python on it, the arithmetic is not close.

## Reproducing it

```bash
tarvos run kernel.py
```

Reproduce the full matrix:

```bash
python benchmarks/benchmark_matrix.py --runtime all --repeats 7 \
  --json-output results/runtime_matrix.json
```

`--repeats 7` with one excluded warm-up run, medians compared, output parity
enforced. Lower the repeat count for a quick check; raise it before you believe
a result.

## What Tarvos actually did

Not "translated Python to C". The pipeline is:

1. **Parse** the file to an AST.
2. **Type-check** it, and reject anything it cannot prove — this is where
   dynamic code gets a named error instead of a silent fallback.
3. **Lower** to an intermediate representation, which is where loops and
   arithmetic become data rather than syntax.
4. **Optimize** that IR: propagate constants, fold arithmetic, replace
   induction variables with closed forms, drop dead bindings.
5. **Emit Rust**, and let the Rust compiler produce machine code.

Step 4 is where the interesting work happens, and where the bug I mentioned
earlier lived. A stale constant surviving an optimization pass is the worst
possible class of compiler bug: the program still compiles, still runs, and
still prints a number. The only defence is checking output against CPython, so
that is what the release gate does.

## The three checks worth running yourself

Speed is the least interesting property. These matter more:

```bash
tarvos doctor                    # does the environment work at all
tarvos scan ./my-project         # what is inside the native subset
tarvos run kernel.py             # does it produce the same output as Python
```

And when something looks wrong, compare directly:

```bash
python kernel.py
tarvos run kernel.py
```

If those two ever disagree, that is a compiler bug and it should be reported
with both outputs. Two such bugs were found while writing this page — one
fixed in `1.1.0-rc.6`, one fixed right after — and both are written up in
[RELEASE_NOTES.md](RELEASE_NOTES.md).

## Honest limits

- This is one kernel on one machine. An I/O-bound program sees almost none of
  this. See [BENCHMARKS.md](BENCHMARKS.md) for when *not* to expect a speedup.
- Tarvos is not a NumPy, Pandas, TensorFlow, or PyTorch replacement. If your
  numeric work lives in those libraries, this is the wrong tool.
- Native `try`/`except` lowers but does not yet catch every exception type at
  run time. See [EXAMPLES.md](EXAMPLES.md) for the specific case and the
  workaround.
- Competitor runtimes (PyPy, Numba, Nuitka, Codon) were not installed on this
  machine, so no comparison against them is claimed. CI reports them when
  available.

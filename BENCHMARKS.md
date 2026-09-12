# Tarvos performance showcase

Tarvos is optimized for statically analyzable, compute-heavy Python kernels.
The headline speedup is always tied to a named workload and runner; it is not a
promise that every Python program will run at the same ratio.

## What CI measures

The private development repository runs the same deterministic workload through
CPython, Tarvos-generated native code, and Rust. It records:

- one excluded warm-up run;
- seven execution samples;
- median, minimum, maximum, and standard deviation;
- Tarvos/Rust compiler time separately;
- stdout output and cross-runtime parity;
- runner OS, Python, Rust, and Tarvos versions.

The benchmark excludes compilation time from execution speedup. This answers
“how fast does an already-built binary run?” End-to-end compile-plus-run cost
must be reported separately.

The release validation command is:

```bash
python benchmarks/benchmark_matrix.py --runtime all --repeats 7 \
  --json-output benchmarks/results/runtime_matrix.json
```

Optional competitor runtimes are reported as unavailable when not installed.
The CI artifact `runtime-matrix` contains the complete JSON report.

## Reading a result

```text
execution speedup = CPython median / Tarvos median
```

Do not describe a single CI result as “Tarvos is always N× faster than Python.”
Use the exact workload, median, runner, and toolchain from the JSON artifact.

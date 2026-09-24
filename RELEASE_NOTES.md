# Tarvos Engine 1.1.0-rc.2

Tarvos Engine 1.1.0-rc.2 synchronizes the public distribution layer with the
Tarvos compiler's native compatibility hardening milestone.

## Highlights

- Installer and Python wrapper defaults now target `v1.1.0-rc.2`.
- Distribution metadata is aligned with the compiler repository's release
  candidate and documented compatibility boundary.
- The release description covers typed lowering, iterable/class support,
  explicit fallback diagnostics, benchmark coverage, and the Ruff prototype.
- This release does not claim full CPython, NumPy, Pandas, TensorFlow, or
  PyTorch native conversion.

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
tag is `v1.0.0`; this distribution tracks the `v1.1.0-rc.2` candidate.

Tarvos targets a statically analyzable Python subset and reports unsupported
dynamic features explicitly rather than promising full CPython compatibility.
The native standard-library surface currently includes `math`, `time`, and
the supported `os.path` operations documented in the compiler repository.

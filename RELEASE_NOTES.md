# Tarvos Engine 1.0.0

Tarvos Engine 1.0.0 is the initial stable public distribution for Tarvos.

This repository provides the user-facing release layer:

- Windows setup and user-local installation.
- Linux and macOS shell installation.
- Python wrapper metadata.
- Release checksums and downloadable binary contracts.
- Product documentation and benchmark guidance.

The compiler implementation is maintained in
[`repo-tech/tarvos`](https://github.com/repo-tech/tarvos). The canonical
initial stable tag is `v1.0.0`.

Tarvos targets a statically analyzable Python subset and reports unsupported
dynamic features explicitly rather than promising full CPython compatibility.

"""The launcher is the only Python this package ships.

These tests cover the decisions it makes that a user cannot see: which release
asset a platform resolves to, and whether the checksum it verifies is the one it
downloaded. Everything else about Tarvos is Rust.
"""
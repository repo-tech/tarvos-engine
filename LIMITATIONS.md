# Known limitations

at the customer's machine rather than in CI.

## Third-party packages are not bundled

This is the most important limitation on this page.

**Tarvos does not embed Python packages in the binary, and does not ship a
CPython interpreter.** A native artifact produced by `tarvos build` contains only
what the compiler emitted itself.

| Class | What happens | Example |
|---|---|---|
| `NATIVE_SUPPORTED` | Lowered to Rust the compiler writes | `math`, `json`, `os.path`, `statistics`, `time` |
| `NATIVE_PARTIAL` | Compiles only for recognized shapes | `numpy`, `pandas` |
| `EXTERNAL_RUNTIME` | Never lowered; needs Python with it installed | `flask`, `requests`, `scipy` |
| `UNSUPPORTED` | Never claimed; refused by name | anything else |

`numpy` and `pandas` are **partial, not supported**. Only the loop patterns the
compiler recognizes compile. An unknown name is reported `UNSUPPORTED` rather
than `EXTERNAL_RUNTIME`, because the honest answer for `mystery_lib` is that
Tarvos has never heard of it — not that you should go install it.

The classification never inspects `site-packages`. It is a property of the
compiler, not of one machine, so a program is classified the same way on a clean
build machine as on a laptop.

If you need a package with the artifact:

```bash
tarvos build app.py --compat-launcher -o app      # single file, carries its source
```

The resulting launcher records in its manifest that it is **not** a native
binary and lists what the target machine needs. Validate any artifact with:

```bash
tarvos validate-artifact app
```

which reads the real format from the file's own header rather than trusting its
name, and exits non-zero if the artifact turns out to need a Python runtime.

### Why there is no embedded CPython

Embedding one is technically possible — statically linking `python-build-standalone`
and installing a `sys.meta_path` importer that serves modules from an in-memory
buffer. It is deliberately not done, for reasons worth stating plainly:

- **It would reverse the product.** The claim is that the artifact needs no Python
  runtime. Embedding one makes the statement false while keeping the wording.
- **It would make the artifact roughly ten times larger.** The Windows binary is
  about 2.6 MB. A statically linked CPython is 10–25 MB on its own, before any
  package payload and the TLS stack an in-process build fetch would need. The
  "small standalone binary" property would be gone.
- **It would undercut the speed story.** The reason a kernel is 100× faster is
  that the interpreter loop is gone. Keeping CPython available in-process invites
  the program to drift back onto it.
- **Dynamic loading on Windows is fragile.** Static CPython links on Windows PE
  need careful `.lib` ordering and toolchain work, and the failure modes show up
  at the customer's machine rather than in CI.

<!-- PART2 -->

## Language features that are refused

## Features that are partial

These compile for some shapes and are refused for others. The exact limit is in
[COMPATIBILITY.md](COMPATIBILITY.md).

| Feature | Works | Does not |
|---|---|---|
| f-strings | Interpolation, format specs, conversions | Full nested-expression and mini-language grammar |
| List comprehensions | Simple, over a range or a list | Nested, multiple `for`/`if` clauses |
| Classes | Attributes, methods, `__init__` | Inheritance, metaclasses, `__slots__`, properties, operators |
| Boolean `and` / `or` | Simple operands | Returning non-boolean operands, as Python does |
| Keyword arguments at call sites | Reported, not silently dropped | — |
| Recursion | Direct and simple mutual | Deep recursion exhausts the native stack where CPython raises `RecursionError` |
| Dictionaries | Built by indexing, string keys | Literal `{}` assigned to a local |
| Slicing | Lists and strings, constant bounds | Computed and stepped slices in some positions |
| Relative imports | Simple cases | Deeply nested and circular graphs |
| Exceptions | `try`/`except`/`else`/`finally`, `raise X` | Bare `raise`, chaining, user-defined exception classes, traceback formatting on an uncaught exception |
| `json.dumps` | Value known at compile time | Value built at run time |

What Tarvos cannot do, why, and what it does instead. This page exists so nobody
has to discover a boundary the hard way.

The short version: **Tarvos is a compiler for statically analyzable,
compute-heavy Python. It is not a CPython replacement.** If your program is
mostly dynamic, Tarvos will tell you so before you rewrite anything, and that is
the correct outcome — not a failure.

Check a project before migrating:

```bash
tarvos scan ./my-project
```


## Performance caveats

The headline benchmark is one kernel, measured on one machine. Read
[BENCHMARKS.md](BENCHMARKS.md) for the method before quoting a number.

- Speedups come from compute-bound loops. **I/O-bound work will not be faster**
  and may be marginally slower, because the win is in the arithmetic.
- Small programs spend their time in process startup and toolchain dispatch, not
  in the loop.
- `tarvos run` compiles before executing; the compile is cached, and the first
  run on a cold cache is the slowest.
- A `tarvos build` artifact avoids the toolchain entirely and is the right choice
  for anything you ship.


## Platform limits

- **Windows x86_64 and Linux x86_64 only.** No macOS, no 32-bit, no aarch64.
  macOS was removed in 1.3.0; the launcher refuses it explicitly rather than
  downloading an asset that would need Rosetta.
- Native compilation needs the managed Rust toolchain. `tarvos toolchain
  --install` fetches and verifies it; it is not a prerequisite you have to set up
  by hand.


## What "standalone" does and does not mean

A `tarvos build` artifact is a real native executable. It needs the operating
system's C runtime and nothing else — no Python, no Rust, no interpreter, and no
administrator rights to run.

It does **not** mean arbitrary Python works. It means the subset above compiles
to native code, and everything outside it is named rather than approximated.


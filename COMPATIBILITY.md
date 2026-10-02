# Python compatibility

What Tarvos compiles to native code, what it compiles *partially*, and what it
refuses. This is the document to read before you port something.

The numbers below are not aspirational. They come from a generated capability
matrix that CI checks on every build: **95 features — 52 supported, 18 partial,
24 unsupported, 1 planned.** "Supported" means a differential case compiles the
construct to a native executable and compares its output against CPython.

Nothing here is a silent fallback. If a construct is not in the subset, the
compiler names it and stops, rather than quietly producing a program that
behaves differently.

## Third-party packages

The same rule applies one level up, to whole packages. Every import is
classified *before* the compiler starts, and a build that cannot lower one stops
and names it rather than emitting an executable that quietly needs it installed:

| Class | Meaning | Example |
|---|---|---|
| `NATIVE_SUPPORTED` | Lowered to Rust the compiler writes itself | `math`, `json`, `os`, `os.path`, `statistics`, `time` |
| `NATIVE_PARTIAL` | Compiles only for the shapes the specializer recognizes | `numpy`, `pandas` |
| `EXTERNAL_RUNTIME` | Never lowered; needs Python with it installed | `flask`, `requests`, `scipy` |
| `UNSUPPORTED` | Not something Tarvos has ever claimed | anything else |

`numpy` and `pandas` are **partial**, not supported. Only the loop patterns the
compiler recognizes compile; anything else in those libraries does not, and the
build says so. An unknown name is `UNSUPPORTED` rather than `EXTERNAL_RUNTIME`,
because the honest answer for `mystery_lib` is that Tarvos has never heard of it,
not that you should go and install it.

The classification never inspects `site-packages`. It is a property of the
compiler, not of one machine, so a program is classified the same way on a clean
build machine as on a developer laptop.

To run a program that imports a third-party package, use `tarvos run` on a machine
where it is installed, or `tarvos build --compat-launcher` to get a single file
that carries its own source — with the manifest recording that it is not a native
binary and listing what the target machine needs. See the README section
"What standalone means, precisely".

## How to check your own project

```bash
tarvos scan ./my-project
```

`scan` reports which loops and library calls are inside the native subset before
you invest in a migration. `tarvos doctor` reports the environment.

## Fully supported

These compile to native code and are covered by differential tests against
CPython.

### Syntax and control flow

| Feature | Notes |
|---|---|
| Variables and assignment | Including tuple assignment (`a, b = 1, 2`) |
| Arithmetic `+ - * / // % **` | Python semantics, including floor division toward negative infinity |
| Floats | |
| Comparisons and boolean operators | `and` / `or` are short-circuiting |
| `if` / `elif` / `else` | |
| `while` / `for` / `break` / `continue` | |
| `def` functions, typed parameters, typed returns | |
| `return` | Including from inside a `try` and inside a handler |
| `import` of supported local modules | |
| `print` with f-strings and formatting | |

### Collections

| Feature |
|---|
| Lists: creation, indexing, slicing, iteration, `append`, `len` |
| Dictionaries: creation, indexing, assignment, `in`, `keys`/`values`/`items` |
| Strings: indexing, slicing, concatenation, comparison, methods, formatting |
| Tuples, including as swap targets |
| Sets, in their supported operations |

### Exceptions

| Feature | Notes |
|---|---|
| `try` / `except` / `else` / `finally` | |
| `raise` | With the Python class hierarchy for handler matching |
| `except ValueError` catching a `StatisticsError` | `StatisticsError` is a `ValueError` subclass in CPython, and matching follows that |
| `except X as e` | `e` carries the message |
| `ZeroDivisionError`, `IndexError`, `KeyError`, `OverflowError` | Raised from the operations that produce them, and catchable |

Exceptions are real `Result` values, not panics, so `finally` runs on a
non-local exit and the error travels to the caller's `try`.

### Standard library

| Module | Supported |
|---|---|
| `math` | `sqrt`, `floor`, `ceil`, `sin`, `cos`, `tan`, `log`, `exp`, `pow`, `fabs`, and the constants |
| `time` | `time`, `sleep`, monotonic and wall-clock helpers |
| `os.path` | `join`, `basename`, `dirname`, `exists`, `isfile`, `isdir`, `abspath`, `splitext` |
| `statistics` | `mean`, `fmean`, `geometric_mean`, `harmonic_mean`, `median`, `median_low`, `median_high`, `mode`, `multimode`, `pvariance`, `pstdev`, `variance`, `stdev` |
| `json` | `dumps` on a compile-time literal |

## Partially supported

These work for common cases and are wrong or rejected outside them. Read the
limit before relying on one.

| Feature | What works | What does not |
|---|---|---|
| **f-strings** | Interpolation, format specs, conversions | The full grammar of nested expressions and format spec mini-language |
| **List comprehensions** | Simple ones over a range or a list | Nested comprehensions, multiple `for`/`if` clauses |
| **Classes** | Simple attribute-holding classes, methods, `__init__` | Inheritance, metaclasses, `__slots__` tricks, properties, operators |
| **Boolean `and` / `or`** | When operands are simple | Returning non-boolean operands, as Python does |
| **Default and annotated parameters** | Type annotations, simple defaults | Keyword arguments at call sites are reported, not silently dropped |
| **Recursion** | Direct and simple mutual recursion | Deep recursion, which exhausts the native stack where CPython raises `RecursionError` |
| **Empty list `[]`** | Assigned to a local, used in loops | In every position; prefer explicit `list()` in new code |
| **`list(...)` conversion** | From a range or a list | From an arbitrary iterable |
| **Dictionaries** | String keys and values created by indexing | Literal `{}` assigned to a local; build with indexing instead |
| **Slicing** | Lists and strings with constant bounds | Computed and stepped slices in some positions |
| **Relative imports** | Simple cases | Deeply nested and circular module graphs |
| **Bare `import module`** | Supported local modules | Arbitrary third-party packages |
| **`json.dumps`** | On a value known at compile time | On a value built at run time |
| **`os` / `os.path`** | The listed `os.path` functions | Environment variables, process control, file contents |
| **`statistics.median_grouped`, `quantiles`, `correlation`, `covariance`, `linear_regression`** | The default arguments | Keyword-only arguments such as `n=` and `method=`, which are not lowered natively |
| **`statistics.linear_regression` result** | Unpacking `(slope, intercept)` | `result.slope`, because it returns a tuple rather than a named tuple |
| **Bare `raise` / re-raise** | Reported | Not lowered |
| **`str(KeyError)` quoting** | The key text | CPython's exact repr quoting of the key |

## Not supported

These are refused with a named diagnostic.

| Area | Why |
|---|---|
| **Generators and `yield`** | Needs a coroutine runtime |
| **`async` / `await`** | Needs an event loop |
| **Metaprogramming** | `eval`, `exec`, runtime `setattr` |
| **Reflection** | `getattr` on unknown names, `__dict__` |
| **Runtime monkey-patching** | Defeats static typing |
| **GUI toolkits** | Tkinter, Qt, wx |
| **Networking** | `socket`, `http`, `asyncio` |
| **Scientific stack** | NumPy, Pandas, TensorFlow, PyTorch |
| **Third-party packages** | Anything not on the supported list |
| **Big integers** | Beyond the native 64-bit and 128-bit widths; reported with a range diagnostic |
| **Multithreading** | No scheduler yet |
| **Context managers** | `with` lowers structurally but the runtime is incomplete |

## Scope note

Tarvos is a **compiler for statically analyzable, compute-heavy Python**. It is
not a CPython replacement, and the honest framing matters more than a large
feature count: a tool that says "no" clearly is more useful than one that
compiles a subtly different program.

Run `tarvos scan` on your code. If most of it is inside the subset, the port is
worth it. If it is mostly dynamic, it is not, and the tool will tell you so
before you have rewritten anything.

Detailed per-feature status is published with each release and is machine
readable. See [BENCHMARKS.md](BENCHMARKS.md) for the performance picture and
[EXAMPLES.md](EXAMPLES.md) for worked code.

# Tarvos examples

Every example on this page was **run on the current build and its output
compared against CPython**. Where an example does not work, that is stated
rather than omitted. If you are following along and something here contradicts
your own run, trust your run and please open an issue.

## Before you start

```bash
tarvos doctor
tarvos toolchain install     # once; fetches and verifies the compiler
tarvos --version
```

`tarvos doctor` reports the toolchain, the transpiler architecture, and whether
your project is inside the native subset. Run it first.

## 1. Hello, native binary

```python
print("Hello from Tarvos!")
```

```bash
tarvos run hello.py
```

Verified output: `Hello from Tarvos!`

The second run reuses a cached translation and a cached executable, so it is
close to instant. The first run compiles.

## 2. A compute loop

The shape Tarvos is built for: a tight loop over integers, no allocation, no
I/O inside the body.

```python
def total(limit: int) -> int:
    acc = 0
    for i in range(limit):
        acc = acc + i
    return acc

print(total(10))
```

```bash
tarvos run loop.py
```

Verified: `45`, identical to CPython. (`total(10)` sums `0` through `9`, so
`45` is the right answer — check your own arithmetic against CPython rather
than trusting this page.)

This is the workload class where the speedup is real. See
[BENCHMARKS.md](BENCHMARKS.md) before quoting a number.

## 3. Tuples and swapping

```python
def swap(a: int, b: int) -> int:
    a, b = b, a
    return a * 10 + b

print(swap(3, 7))
```

Verified: `73` — CPython agrees.

Tuple assignment is a good early smoke test. It is also the construct that had
a correctness bug in an earlier build; the shape is now covered by the
differential suite.

## 4. Functions and recursion

```python
def factorial(n: int) -> int:
    if n <= 1:
        return 1
    return n * factorial(n - 1)

print(factorial(10))
```

Verified: `3628800`, identical to CPython.

## 5. Floating point and `math`

```python
import math

def hypotenuse(a: float, b: float) -> float:
    return math.sqrt(a * a + b * b)

print(hypotenuse(3.0, 4.0))
```

Verified: `5.0`, identical to CPython.

Note that `round()` is **not** in the native subset. `math.sqrt` is. If you
reach for `round`, expect a fallback or an explicit diagnostic.

## 6. Lists

```python
def total(values: list) -> int:
    acc = 0
    for v in values:
        acc = acc + v
    return acc

print(total([1, 2, 3, 4, 5]))
```

Verified: `15`, identical to CPython.

## 7. Dictionaries and strings

```python
def distinct(text: str) -> int:
    seen = {}
    count = 0
    for ch in text:
        if ch not in seen:
            seen[ch] = True
            count = count + 1
    return count

print(distinct("abracadabra"))
```

Verified: `5` — the five distinct letters, identical to CPython.

A literal `{}` assigned to a local does not currently lower. Building the dict
with explicit indexing, as above, does.

## 8. Emitting Rust instead of a binary

Useful when you want to read or review what Tarvos produced, and the one mode
that needs no compiler at all.

```bash
tarvos compile loop.py --output loop.rs --source-only
```

## 9. Checking a project before you commit to it

```bash
tarvos scan ./my-project
```

Reports which loops and library calls are inside the native subset. This is the
cheapest way to find out whether a migration is worth starting.

## 10. `try` / `except` — read this one

Native `try`/`except` **lowers correctly but does not yet catch every exception
type at run time.** A `try` whose body returns without raising works:

```python
def pick(n: int) -> int:
    try:
        return 100
    except ValueError:
        return -1

print(pick(5))
```

Verified: `100`, identical to CPython.

But an exception actually raised inside the `try` does not reliably reach its
handler:

```python
def safe_div(a: int, b: int) -> int:
    try:
        return a // b
    except ZeroDivisionError:
        return -1

print(safe_div(10, 2))
print(safe_div(1, 0))
```

CPython prints `5` then `-1`. The native build prints `5` and then panics with
`ZeroDivisionError`.

**If your code depends on catching an error to continue, do not put it on the
native path yet.** Use CPython, or:

```bash
tarvos run script.py --python-fallback
```

This is a known, open bug, tracked in the compiler repository. It is written
here rather than hidden because a crashing binary is a worse outcome than a
documented limit.

## 11. Packaging a project

```bash
tarvos package ./my-project --entry main.py --output-dir ./dist
```

Produces a Cargo project and a release binary under `dist/`, for the case where
you want to own the build and the release profile.

## Patterns that will not go native

These are reported explicitly rather than silently falling back, so you find out
at build time:

- arbitrary third-party imports
- runtime monkey-patching and `setattr`
- metaprogramming and `eval`/`exec`
- reflection, `getattr` on unknown names
- generators and `yield` in unsupported positions
- classes with metaclasses or `__slots__` tricks

Run `tarvos scan` to see where a project stands before you invest in porting it.

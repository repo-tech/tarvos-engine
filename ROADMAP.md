# Roadmap

Where Tarvos is going, and what "going there" means for a tool that compiles
Python to native code.

This is a statement of direction, not a schedule. Dates are deliberately
absent: a compiler that promises a date for a feature it cannot yet type-check
is the same failure mode as a compiler that silently produces a wrong answer.

## The rule that shapes everything

Every feature below has to pass the same bar: **a differential test that compares
the compiled native binary's output against CPython.** A feature is not
"supported" because it compiles; it is supported because it produces the same
output as Python on a corpus that someone actually runs.

This bar is the reason some obvious features are not in the product yet. It is
also the reason two real bugs were caught and fixed around the 1.0.0 release
rather than shipped: a stale constant that made a Fibonacci return `0`, and a
zero divisor that crashed instead of reaching its handler. Both produced working,
runnable, wrong programs. Only a parity check finds that class of bug.

## Next

### Exceptions, completed

`try` / `except` / `else` / `finally` and `raise` are native. Division, indexing,
and key lookup raise catchable errors. The remaining work:

- **Bare `raise` and re-raise** inside a handler, which re-raises the active
  exception.
- **Exception chaining**: `raise X from Y` and the `__cause__` attribute.
- **`str(KeyError)` repr quoting**, matching CPython's quoting of the key.
- **Custom exception classes** declared in the program and raised by the user.
- **Traceback information** on an uncaught exception. Today it prints
  `Class: message` and exits 1, because a native binary does not carry the
  source-level frames a Python traceback is made of. Emitting a faithful
  traceback means carrying line metadata into the binary.

### Classes

Simple classes work. The gap is the parts of the object model that carry
meaning:

- **Inheritance**, including multiple inheritance and `super()`.
- **Properties**, descriptors, and `__slots__`.
- **Operator overloading**: `__add__`, `__getitem__`, `__len__`, and friends.
- **Dunder protocol** methods that map onto real Rust traits rather than
  dispatch tables.
- **`dataclasses`**, which is the single most requested missing feature for
  anyone porting real code.

### Iterators and generators

`for` over a list, a range, a string, and a dictionary works. Missing:

- **Generator expressions** and `yield` in a function body.
- **Custom `__iter__` / `__next__`**, lowering to a Rust iterator.
- **`itertools`** and **`collections`**, which are pure-Python and would need a
  native runtime rather than a lowering.

### The standard library

- **`os` beyond `os.path`**: environment variables, directory listing, process
  control.
- **`csv`, `datetime`, `re`** as native modules. `re` in particular is a large
  piece of work and a common reason a port stops.
- **`collections`**: `defaultdict`, `Counter`, `deque`, `namedtuple`.
- **`json.loads`** and `json.dumps` on values built at run time.
- **`typing`** enforced at compile time rather than only read.

### Bigger integers

Native integers are 64-bit, with 128-bit used where it helps. CPython integers
are arbitrary precision. Bridging that means a bignum runtime, which costs
performance in the common case to serve a rare one. The likely answer is a
compile-time switch rather than a single behaviour, so a program that stays in
64 bits keeps the fast path.

### Concurrency

Not started. `threading`, `multiprocessing`, and `asyncio` are all out of scope
today, and the honest position is that a compute kernel that is already
parallelised across processes gains nothing from a compiler that cannot
describe concurrency yet.

## Not planned

These are not on the roadmap, and pretending otherwise would waste your time:

- **A CPython-compatible runtime.** Tarvos is a compiler for statically
  analyzable code, not an embeddable CPython. If you need the whole language,
  use CPython.
- **NumPy, Pandas, TensorFlow, or PyTorch compatibility.** The scientific
  stack is built on dynamic dispatch and C extensions. A compiler that
  supported it would be a different product with a different claim, and the
  result would be a slower version of the libraries you already have.
- **GUI or networking toolkits.** These are I/O-bound; the interpreter was never
  the bottleneck, so compiling them buys nothing.
- **Runtime introspection.** `eval`, `exec`, and `getattr` on unknown names are
  fundamentally at odds with static typing. They will stay unsupported.

## How to influence this

The most useful thing you can do is report a real program that does not
compile, with the diagnostic you got and the subset you expected. The capability
matrix is generated from the differential corpus, so a reported gap becomes a
workload, and a workload becomes a test. That is how the two bugs in 1.0.0 were
found, and it is the path by which most of the table above will change.

See [COMPATIBILITY.md](COMPATIBILITY.md) for the current state.

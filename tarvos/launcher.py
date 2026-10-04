from __future__ import annotations

import ast
import hashlib
import json
import os
import platform
import subprocess
import sys
import urllib.request
from urllib.error import HTTPError, URLError
from pathlib import Path

# The distribution version this package installs by default.
VERSION = "v1.3.1"
REPOSITORY = "repo-tech/tarvos-engine"


def _asset() -> str:
    system = platform.system().lower()
    machine = platform.machine().lower()
    if system == "windows" and machine in {"amd64", "x86_64", "x64"}:
        return "tarvos.exe"
    if system == "linux" and machine in {"amd64", "x86_64", "x64"}:
        return "tarvos"
    raise RuntimeError(
        f"Tarvos has no published binary for {system}/{machine}. "
        "This release ships Windows and Linux binaries only."
    )


def _bin_dir() -> Path:
    home = Path.home()
    return home / ".tarvos" / "bin"


def _download_binary() -> Path:
    asset = _asset()
    directory = _bin_dir()
    directory.mkdir(parents=True, exist_ok=True)
    binary = directory / asset
    if os.name == "nt":
        binary = binary.with_suffix(".exe")
    if binary.exists():
        return binary

    release_path = "latest" if VERSION == "latest" else f"tags/{VERSION}"
    api_base = f"https://api.github.com/repos/{REPOSITORY}/releases"
    
    headers = {
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "tarvos-python-launcher",
    }
    
    request = urllib.request.Request(f"{api_base}/{release_path}", headers=headers)
    with urllib.request.urlopen(request, timeout=60) as response:
        release = json.loads(response.read().decode("utf-8"))
    
    assets = {entry["name"]: entry for entry in release.get("assets", [])}
    if asset not in assets or f"{asset}.sha256" not in assets:
        raise RuntimeError(
            f"release {release.get('tag_name', VERSION)} is missing {asset} or {asset}.sha256"
        )

    def read_asset(name: str) -> bytes:
        request = urllib.request.Request(
            assets[name]["url"],
            headers={
                "User-Agent": "tarvos-python-launcher",
                "Accept": "application/octet-stream",
            },
        )
        with urllib.request.urlopen(request, timeout=60) as response:
            return response.read()

    temporary = binary.with_suffix(binary.suffix + ".tmp")
    temporary.write_bytes(read_asset(asset))
    
    expected = read_asset(f"{asset}.sha256").decode("ascii").split()[0].lower()
    actual = hashlib.sha256(temporary.read_bytes()).hexdigest()
    if actual != expected:
        temporary.unlink(missing_ok=True)
        raise RuntimeError("Tarvos binary checksum verification failed")
    
    temporary.replace(binary)
    if os.name != "nt":
        binary.chmod(0o755)
    return binary


def _scan_dependencies_via_ast(args: list[str]) -> set[str]:
    """Scans the targeted input Python script using AST to safely discover imports."""
    detected = set()
    python_file = None
    for arg in args:
        if arg.endswith(".py"):
            path = Path(arg)
            if path.exists() and path.is_file():
                python_file = path
                break

    if not python_file:
        return detected

    try:
        source_code = python_file.read_text(encoding="utf-8", errors="ignore")
        tree = ast.parse(source_code, filename=str(python_file))
        
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                for alias in node.names:
                    root_mod = alias.name.split('.')[0]
                    detected.add(root_mod)
            elif isinstance(node, ast.ImportFrom):
                if node.module:
                    root_mod = node.module.split('.')[0]
                    detected.add(root_mod)
    except Exception:
        pass

        # Filter out common standard library modules or builtins to avoid clutter
    stdlib_builtins = {
        # --- Core System & OS Utilities ---
        "sys", "os", "pathlib", "shutil", "io", "abc", "builtins", "contextlib",
        "platform", "subprocess", "sysconfig", "gc", "argparse", "getopt",

        # --- Data Types, Collections & Mathematics ---
        "math", "cmath", "decimal", "fractions", "random", "statistics",
        "collections", "collections.abc", "enum", "functools", "itertools",
        "operator", "dataclasses", "types", "copy", "pprint", "weakref",

        # --- String Processing & Text Handling ---
        "string", "re", "difflib", "textwrap", "unicodedata", "stringprep",

        # --- Data Serialization & File Formats ---
        "json", "pickle", "marshal", "csv", "configparser", "sqlite3",
        "xml", "xml.etree.ElementTree", "plistlib",

        # --- Networking, Web & Internet Protocols ---
        "socket", "ssl", "select", "selectors", "asyncio", "http", "http.client",
        "http.server", "urllib", "urllib.request", "urllib.parse", "urllib.error",
        "ftplib", "smtplib", "imaplib", "poplib", "webbrowser", "xmlrpc",

        # --- Cryptography, Hashing & Compression ---
        "hashlib", "hmac", "secrets", "zipfile", "tarfile", "gzip", "bz2", "lzma",

        # --- Date, Time & Internationalization ---
        "time", "datetime", "calendar", "zoneinfo", "locale", gettext,

        # --- Concurrent Programming & Threading ---
        "threading", "multiprocessing", "concurrent", "concurrent.futures", "queue",

        # --- Debugging, Testing & Runtime Diagnostics ---
        "unittest", "mock", "logging", "traceback", "warnings", "inspect",
        "pydoc", "timeit", "trace", "cProfile", "profile"
    }

    return detected - stdlib_builtins


def main() -> int:
    try:
        binary = _download_binary()
    except (HTTPError, URLError, OSError, RuntimeError, KeyError, ValueError) as error:
        print(f"Tarvos installation failed: {error}", file=sys.stderr)
        return 1

    detected_packages = _scan_dependencies_via_ast(sys.argv[1:])
    if detected_packages:
        packages_str = ",".join(sorted(detected_packages))
        os.environ["TARVOS_DETECTED_PACKAGES"] = packages_str

    completed = subprocess.run([str(binary), *sys.argv[1:]], check=False)
    return completed.returncode

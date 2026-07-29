#!/usr/bin/env python3
"""Patch dashboard/__init__.py to always use run_build instead of run_dev when DEBUG=true"""
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "dashboard/__init__.py"
with open(path, "r") as f:
    content = f.read()

old = "        if runtime_settings.debug:\n            run_dev()\n        else:\n            run_build(app)"
new = "        run_build(app)"

if old in content:
    content = content.replace(old, new)
    with open(path, "w") as f:
        f.write(content)
    print(f"PATCHED: {path}")
else:
    print(f"WARNING: pattern not found in {path}")
    # Try to find what's there
    for i, line in enumerate(content.split("\n")):
        if "debug" in line.lower() and "runtime" in line.lower():
            print(f"  Line {i+1}: {line!r}")

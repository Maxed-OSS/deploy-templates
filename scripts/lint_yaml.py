#!/usr/bin/env python3
"""Lint one or more YAML files by parsing them with PyYAML.

Fallback validator used by validate.sh when Docker is unavailable. Exits
non-zero on the first parse error.
"""
from __future__ import annotations

import sys

try:
    import yaml
except ImportError:
    sys.stderr.write("PyYAML not installed: pip install pyyaml\n")
    sys.exit(2)


def main(paths: list[str]) -> int:
    if not paths:
        sys.stderr.write("usage: lint_yaml.py <file.yml> [more.yml ...]\n")
        return 2
    failed = False
    for path in paths:
        try:
            with open(path, "r", encoding="utf-8") as fh:
                list(yaml.safe_load_all(fh))
            print(f"OK   {path}")
        except (yaml.YAMLError, OSError) as exc:
            failed = True
            print(f"FAIL {path}: {exc}", file=sys.stderr)
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

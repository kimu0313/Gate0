"""Extract Korean string literals from GDScript files (skips comments and debug scripts).

usage: python -I extract.py <project_root> <out.json>
"""
import json
import os
import re
import sys

HANGUL = re.compile(r"[가-힣]")
ESC = {"n": "\n", "t": "\t", '"': '"', "\\": "\\", "'": "'", "r": "\r"}


def literals(src: str):
    """Yield (line_no, value, raw, after) for every double-quoted literal outside comments."""
    i, n, line = 0, len(src), 1
    while i < n:
        c = src[i]
        if c == "\n":
            line += 1
            i += 1
            continue
        if c == "#":
            while i < n and src[i] != "\n":
                i += 1
            continue
        if c == '"':
            if src.startswith('"""', i):
                end = src.find('"""', i + 3)
                i = end + 3 if end >= 0 else n
                continue
            j, val, start_line = i + 1, [], line
            while j < n and src[j] != '"':
                if src[j] == "\\" and j + 1 < n:
                    val.append(ESC.get(src[j + 1], "\\" + src[j + 1]))
                    j += 2
                    continue
                if src[j] == "\n":
                    line += 1
                val.append(src[j])
                j += 1
            after = src[j + 1 : j + 4]
            yield start_line, "".join(val), after
            i = j + 1
            continue
        if c == "'":
            j = i + 1
            while j < n and src[j] not in "'\n":
                j += 2 if src[j] == "\\" else 1
            i = j + 1
            continue
        i += 1


def main() -> None:
    root, out = sys.argv[1], sys.argv[2]
    found: dict = {}
    for dirpath, _, files in os.walk(os.path.join(root, "scripts")):
        if os.sep + "debug" in dirpath:
            continue
        for fn in sorted(files):
            if not fn.endswith(".gd"):
                continue
            path = os.path.join(dirpath, fn)
            rel = os.path.relpath(path, root).replace("\\", "/")
            with open(path, encoding="utf-8") as f:
                src = f.read()
            for line, val, after in literals(src):
                if not HANGUL.search(val):
                    continue
                e = found.setdefault(val, {"src": val, "refs": [], "format": False})
                e["refs"].append(f"{rel}:{line}")
                if after.strip().startswith("%"):
                    e["format"] = True
    items = list(found.values())
    with open(out, "w", encoding="utf-8") as f:
        json.dump(items, f, ensure_ascii=False, indent=1)
    print(f"{len(items)} unique strings, {sum(len(e['refs']) for e in items)} refs, "
          f"{sum(1 for e in items if e['format'])} used with %")


if __name__ == "__main__":
    main()

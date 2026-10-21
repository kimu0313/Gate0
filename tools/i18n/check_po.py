"""Check assets/i18n/en.po against the Korean strings in the scripts.

usage: python -I tools/i18n/check_po.py [project_root]
Lists source strings with no translation (add them to en.po, msgid = the Korean text)
and translations whose %s/%d/[b]/| tokens differ from the source.
"""
import json
import os
import re
import subprocess
import sys
import tempfile

root = sys.argv[1] if len(sys.argv) > 1 else os.getcwd()
here = os.path.dirname(os.path.abspath(__file__))


def unquote(s: str) -> str:
    out, i = [], 0
    while i < len(s):
        if s[i] == "\\" and i + 1 < len(s):
            out.append({"n": "\n", "t": "\t"}.get(s[i + 1], s[i + 1]))
            i += 2
            continue
        out.append(s[i])
        i += 1
    return "".join(out)


def read_po(path: str) -> dict:
    """{(msgctxt, msgid): msgstr}"""
    entries, cur, field = {}, {}, None
    with open(path, encoding="utf-8") as f:
        lines = f.read().split("\n") + [""]
    for line in lines:
        m = re.match(r'^(msgctxt|msgid|msgstr) "(.*)"$', line)
        if m:
            if m.group(1) == "msgctxt" or (m.group(1) == "msgid" and "msgstr" in cur):
                if "msgstr" in cur:
                    entries[(cur.get("msgctxt", ""), cur["msgid"])] = cur["msgstr"]
                cur = {}
            field = m.group(1)
            cur[field] = unquote(m.group(2))
        elif line.startswith('"') and field:
            cur[field] += unquote(line[1:-1])
        elif line.strip() == "" and "msgstr" in cur:
            entries[(cur.get("msgctxt", ""), cur["msgid"])] = cur["msgstr"]
            cur, field = {}, None
    entries.pop(("", ""), None)
    return entries


po = read_po(os.path.join(root, "assets", "i18n", "en.po"))
with tempfile.TemporaryDirectory() as tmp:
    out = os.path.join(tmp, "strings.json")
    subprocess.run([sys.executable, "-I", os.path.join(here, "extract.py"), root, out], check=True)
    now = json.load(open(out, encoding="utf-8"))

plain = {k[1] for k in po if k[0] == ""}
missing = [e for e in now if e["src"] not in plain]
problems = []
for (ctx, k), v in po.items():
    for tok in ["%s", "%d", "%%", "[b]", "[/b]", "|"]:
        if k.count(tok) != v.count(tok):
            problems.append(f"{tok!r} count differs: {k[:50]!r}")
    if v == "":
        problems.append(f"empty msgstr: {k[:50]!r}")

print(f"en.po: {len(po)} entries; scripts: {len(now)} strings; untranslated: {len(missing)}; problems: {len(problems)}")
for e in missing:
    print(f"  missing  {e['src'][:60]!r}  ({e['refs'][0]})")
for p in problems:
    print("  problem ", p)
sys.exit(1 if missing or problems else 0)

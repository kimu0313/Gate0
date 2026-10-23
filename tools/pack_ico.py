"""Packs PNG files into a Windows .ico (PNG-compressed entries, Vista+).

usage: python -I tools/pack_ico.py <out.ico> <icon_16.png> <icon_24.png> ...
Each PNG must be square, 256 px or smaller (tools/recolor_ui_art.gd writes them).
"""
import struct
import sys

out, pngs = sys.argv[1], sys.argv[2:]
blobs = [open(p, "rb").read() for p in pngs]
header = struct.pack("<HHH", 0, 1, len(blobs))
entries, offset = b"", 6 + 16 * len(blobs)
for b in blobs:
    w, h = struct.unpack(">II", b[16:24])   # IHDR width/height
    entries += struct.pack("<BBBBHHII", w % 256, h % 256, 0, 0, 1, 32, len(b), offset)
    offset += len(b)
with open(out, "wb") as f:
    f.write(header + entries + b"".join(blobs))
print("wrote", out, "with", len(blobs), "images")

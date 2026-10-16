#!/usr/bin/env python3
"""
elf2mem.py -- Convert raw binary firmware to Verilog $readmemh hex memory file.

Format:
  - Exactly one 32-bit hexadecimal word per line (8 hex characters, little-endian).
  - Padded with 00000000 up to target ROM word depth (default: 1024 words = 4096 bytes).

Usage:
  python elf2mem.py input.bin 1024 output.mem
  python elf2mem.py input.bin 1024 > output.mem
"""

import sys
import os

def bin_to_mem(bin_path, words=1024, out_path=None):
    with open(bin_path, "rb") as f:
        data = f.read()

    lines = []
    for i in range(words):
        off = i * 4
        chunk = data[off:off + 4]
        # Pad chunk to 4 bytes if at EOF
        chunk = chunk + b"\x00" * (4 - len(chunk))
        # Little-endian 32-bit word
        val = chunk[0] | (chunk[1] << 8) | (chunk[2] << 16) | (chunk[3] << 24)
        lines.append(f"{val:08x}\n")

    content = "".join(lines)
    if out_path:
        with open(out_path, "w") as f:
            f.write(content)
        print(f"[elf2mem] Wrote {words} 32-bit words ({words*4} bytes) to {out_path}")
    else:
        sys.stdout.write(content)

def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    bin_path = sys.argv[1]
    words = int(sys.argv[2]) if len(sys.argv) > 2 else 1024
    out_path = sys.argv[3] if len(sys.argv) > 3 else None

    bin_to_mem(bin_path, words, out_path)

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
upload_uart.py -- Upload application binary over UART to resident bootloader.

Usage:
  python upload_uart.py COM14 app.bin [baud_rate]
"""

import sys
import os
import struct
import time

try:
    import serial
except ImportError:
    serial = None

def upload(port, bin_path, baud=115200):
    if serial is None:
        print("Error: pyserial is required. Install via: pip install pyserial")
        sys.exit(1)

    if not os.path.exists(bin_path):
        print(f"Error: file not found: {bin_path}")
        sys.exit(1)

    with open(bin_path, "rb") as f:
        data = f.read()

    print(f"Target port: {port} @ {baud} baud")
    print(f"Uploading image: {bin_path} ({len(data)} bytes)...")

    s = serial.Serial(port, baud, timeout=3, rtscts=False, dsrdtr=False)
    s.dtr = False
    s.rts = False
    time.sleep(0.2)

    # 4-byte little endian length header
    header = struct.pack("<I", len(data))
    s.write(header)
    s.flush()

    # Raw bytes
    s.write(data)
    s.flush()

    # Wait for ack byte 'K'
    ack = s.read(1)
    if ack == b"K":
        print("SUCCESS: Acknowledgement received ('K'). Application running!")
    else:
        print(f"Response: {ack!r}")
        print("Note: If the board is running pure ROM firmware without bootloader, upload ack will not return.")

    s.close()

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python upload_uart.py <COM_PORT> <path_to_app.bin> [baud_rate]")
        sys.exit(1)
    baud = int(sys.argv[3]) if len(sys.argv) > 3 else 115200
    upload(sys.argv[1], sys.argv[2], baud)

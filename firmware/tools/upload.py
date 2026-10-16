#!/usr/bin/env python3
# ============================================================================
# upload.py -- Upload application binary over UART to resident bootloader
# (Matches PicoRV32 upload workflow for Boolean FPGA)
#
# Usage:
#   python upload.py COM16 boot_app/boot_app.bin
#   python upload.py COM16 boot_app/boot_app.bin --monitor
# ============================================================================

import sys
import os
import struct
import time

try:
    import serial
except ImportError:
    print("[Error] pyserial is required. Install via: pip install pyserial")
    sys.exit(1)

def main():
    if len(sys.argv) < 3:
        print("Usage: python upload.py <COM_PORT> <path_to_app.bin> [--monitor]")
        print("Example: python upload.py COM16 boot_app/boot_app.bin")
        print("         python upload.py COM16 boot_app/boot_app.bin --monitor")
        sys.exit(1)

    port = sys.argv[1]
    bin_path = sys.argv[2]
    open_monitor = ("--monitor" in sys.argv) or ("-m" in sys.argv)
    baud = 115200

    if not os.path.exists(bin_path):
        print(f"Error: application binary '{bin_path}' not found.")
        sys.exit(1)

    with open(bin_path, "rb") as f:
        data = f.read()

    print("==================================================")
    print("      RV32I SoC UART Bootloader Uploader          ")
    print("==================================================")
    print(f"Target Port : {port} @ {baud} baud")
    print(f"App Binary  : {bin_path} ({len(data)} bytes)")
    print("--------------------------------------------------")

    try:
        s = serial.Serial(port, baud, timeout=3, rtscts=False, dsrdtr=False)
    except Exception as e:
        print(f"Failed to open {port}: {e}")
        sys.exit(1)

    s.dtr = False
    s.rts = False
    time.sleep(0.2) # Allow port to settle
    s.reset_input_buffer()

    # Step 1: Send 'p' command to put Bootloader into Program/Upload mode
    print("[1/3] Initiating upload command ('p')...")
    s.write(b'p')
    s.flush()
    time.sleep(0.05)

    # Step 2: Send 4-byte little-endian length header + raw binary payload
    header = struct.pack("<I", len(data))
    print(f"[2/3] Transmitting length ({len(data)} B) and payload to 0x00000200...")
    s.write(header)
    s.write(data)
    s.flush()

    # Step 3: Wait for 'K' acknowledgement
    print("[3/3] Waiting for confirmation from bootloader...")
    ack = s.read(1)
    if ack == b"K":
        print("--------------------------------------------------")
        print("SUCCESS: Upload confirmed ('K' received)!")
        print("==================================================")

        if open_monitor:
            print("[Launching application and entering interactive monitor...]")
            s.write(b'e') # Automatically send 'e' to execute
            s.flush()
            from serial.tools.miniterm import Miniterm
            miniterm = Miniterm(s, echo=False)
            miniterm.exit_character = '\x1d' # Ctrl+]
            miniterm.start()
            try:
                miniterm.join()
            except KeyboardInterrupt:
                pass
            miniterm.close()
            return
        else:
            print("Instruction Memory programmed successfully!")
            print("Next step: Open PuTTY or miniterm on", port, "and press 'e' to run.")
            print("==================================================")

    else:
        print(f"WARNING: Unexpected response: {ack!r}")
        print("Tip: Make sure the FPGA has the bootloader active (LED0 ON).")

    s.close()

if __name__ == "__main__":
    main()

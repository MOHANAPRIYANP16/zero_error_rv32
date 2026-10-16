# Custom RV32I SoC Memory Map & Register Reference

## 1. System Memory Map Summary

All address ranges are non-overlapping and fully decoded. The top 4 address bits `mem_addr[31:28]` uniquely partition the address space into 16 separate 256 MB regions:

| Address Range | Size | Region | Access | Function |
| :--- | :--- | :--- | :--- | :--- |
| `0x0000_0000 - 0x0000_0FFF` | 4 KB (1024 words) | Code Memory / RAM | R / W / X | Reset vector (0x00), preloaded via `$readmemh("instruction.mem")` |
| `0x1000_0000 - 0x1000_1FFF` | 8 KB (2048 words) | Data RAM | R / W | Data scratchpad, stack, and heap with byte write strobes |
| `0x2000_0000 - 0x2000_00FF` | 256 Bytes | UART Controller | R / W | Serial transmit, receive, status, and configurable baud rate |
| `0x3000_0000 - 0x3000_00FF` | 256 Bytes | 32-bit GPIO | R / W | 16 on-board LEDs and input status |
| `0x4000_0000 - 0x4000_00FF` | 256 Bytes | I2C Controller | R / W | I2C master for sensor reading/writing (100k / 400k) |
| *All Other Addresses* | - | Unmapped Space | R / W | Returns `0xDEADBEEF` with 1-wait-state termination |

---

## 2. Peripheral Register Definitions

### 2.1 UART Peripheral (Base: `0x2000_0000`)

| Offset | Register Name | Access | Bit Fields | Description |
| :--- | :--- | :--- | :--- | :--- |
| `0x00` | `UART_DATA` | R/W | `[7:0]` | **Write**: Transmit byte (kicks off TX if not busy).<br>**Read**: Received byte (automatically clears `rx_valid`). |
| `0x04` | `UART_STATUS` | R | `[0]`<br>`[1]`<br>`[2]`<br>`[31:3]` | **tx_busy**: `1` when transmitter is actively sending.<br>**rx_valid**: `1` when a newly received byte is available.<br>**rx_overflow**: `1` if a byte arrived before previous was read.<br>Reserved (zeros). |
| `0x08` | `UART_BAUD` | R/W | `[2:0]` | **Baud Rate Selector**:<br>- `3'd0`: 9600 baud (Default at reset)<br>- `3'd1`: 19200 baud<br>- `3'd2`: 38400 baud<br>- `3'd3`: 57600 baud<br>- `3'd4`: 115200 baud |
| `0x0C` | `UART_STATUS_CLEAR` | W | `[0]` | Write any non-zero value to clear `rx_overflow` and `rx_valid`. |

#### Software Driver Usage Example (Polling):
```c
// Transmit byte
while (*(volatile uint32_t*)0x20000004 & 0x01); // Wait while tx_busy
*(volatile uint32_t*)0x20000000 = 'A';

// Receive byte
while (!(*(volatile uint32_t*)0x20000004 & 0x02)); // Wait for rx_valid
char c = *(volatile uint32_t*)0x20000000;
```

---

### 2.2 32-bit GPIO Peripheral (Base: `0x3000_0000`)

| Offset | Register Name | Access | Bit Fields | Description |
| :--- | :--- | :--- | :--- | :--- |
| `0x00` | `GPIO_DATA_OUT` | R/W | `[15:0]`<br>`[31:16]` | **LED Outputs**: Directly drives the 16 on-board LEDs.<br>Tied to zeros. Supports byte strobes (`SB`, `SH`, `SW`). |
| `0x04` | `GPIO_DATA_IN` | R | `[15:0]`<br>`[31:16]` | **Inputs**: Reads 16 board inputs (switches/buttons).<br>Tied to zeros. |
| `0x08` | `GPIO_DIR` | R/W | `[15:0]` | GPIO Direction configuration (reserved for expansion). |

---

### 2.3 I2C Controller Peripheral (Base: `0x4000_0000`)

| Offset | Register Name | Access | Bit Fields | Description |
| :--- | :--- | :--- | :--- | :--- |
| `0x00` | `I2C_CTRL_STATUS` | R/W | `[0]` (W)<br>`[0]` (R)<br>`[1]` (R)<br>`[2]` (R) | **Write `1`**: Triggers execution of I2C transaction.<br>**done**: `1` when transaction finished.<br>**busy**: `1` while transaction in progress.<br>**err**: `1` if NACK received or bus error occurred. |
| `0x04` | `I2C_SLV_ADDR` | R/W | `[7:1]`<br>`[0]` | **7-bit Slave Address** (e.g., `0x53` for ADXL345).<br>**RWbar**: `0` = Write operation, `1` = Read operation. |
| `0x08` | `I2C_REG_ADDR` | R/W | `[7:0]` | **Device Register Address** to write or read from. |
| `0x0C` | `I2C_WR_DATA` | R/W | `[7:0]` | **Data Byte** to write to device (during Write operation). |
| `0x10` | `I2C_BYTE_CNT` | R/W | `[2:0]` | **Read Byte Count**: Number of bytes to read sequentially (1 to 8). |
| `0x14` | `I2C_CONFIG` | R/W | `[0]` | **Speed Selector**:<br>- `0`: 400 kHz Fast Mode (Default)<br>- `1`: 100 kHz Standard Mode |
| `0x20` | `I2C_RD_DATA0` | R | `[7:0]` | First received data byte from sensor. |
| `0x24` | `I2C_RD_DATA1` | R | `[7:0]` | Second received data byte. |
| `0x28` | `I2C_RD_DATA2` | R | `[7:0]` | Third received data byte. |
| `0x2C` | `I2C_RD_DATA3` | R | `[7:0]` | Fourth received data byte. |

#### I2C Transaction Sequences:
1. **Write Transaction (`RWbar = 0`)**:
   - `START` -> `Slave Address + W` -> `Slave ACK` -> `Register Address` -> `Slave ACK` -> `Write Data` -> `Slave ACK` -> `STOP`.
2. **Read Transaction (`RWbar = 1`) with Repeated START**:
   - `START` -> `Slave Address + W` -> `Slave ACK` -> `Register Address` -> `Slave ACK` -> `RESTART` -> `Slave Address + R` -> `Slave ACK` -> `Read Byte 0` -> `Master ACK` -> ... -> `Read Byte N` -> `Master NACK` -> `STOP`.

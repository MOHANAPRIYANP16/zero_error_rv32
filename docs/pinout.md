# Digital Boolean Board FPGA Pinout & Constraints Reference

## 1. Board Information
- **Target Board**: Real Digital Boolean FPGA Board
- **FPGA Device**: AMD / Xilinx Spartan-7 XC7S50-CSGA324-1
- **I/O Standard**: `LVCMOS33` (3.3V I/O Bank Voltage)
- **Configuration Voltage**: `CONFIG_VOLTAGE 3.3`, `CFGBVS VCCO`

---

## 2. Complete Pin Assignment Table

| Signal Name | Port Type | Package Pin | I/O Standard | Features / Pull-up | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `clk` | Input | `F14` | LVCMOS33 | Period: 10.000 ns (100 MHz) | Primary on-board oscillator |
| `btn_rst` | Input | `J2` | LVCMOS33 | Active-High button (BTN0) | Hardware reset push button |
| `led[0]` | Output | `G1` | LVCMOS33 | - | User LED LD0 |
| `led[1]` | Output | `G2` | LVCMOS33 | - | User LED LD1 |
| `led[2]` | Output | `F1` | LVCMOS33 | - | User LED LD2 |
| `led[3]` | Output | `F2` | LVCMOS33 | - | User LED LD3 |
| `led[4]` | Output | `E1` | LVCMOS33 | - | User LED LD4 |
| `led[5]` | Output | `E2` | LVCMOS33 | - | User LED LD5 |
| `led[6]` | Output | `E3` | LVCMOS33 | - | User LED LD6 |
| `led[7]` | Output | `E5` | LVCMOS33 | - | User LED LD7 |
| `led[8]` | Output | `E6` | LVCMOS33 | - | User LED LD8 |
| `led[9]` | Output | `C3` | LVCMOS33 | - | User LED LD9 |
| `led[10]` | Output | `B2` | LVCMOS33 | - | User LED LD10 |
| `led[11]` | Output | `A2` | LVCMOS33 | - | User LED LD11 |
| `led[12]` | Output | `B3` | LVCMOS33 | - | User LED LD12 |
| `led[13]` | Output | `A3` | LVCMOS33 | - | User LED LD13 |
| `led[14]` | Output | `B4` | LVCMOS33 | - | User LED LD14 |
| `led[15]` | Output | `A4` | LVCMOS33 | - | User LED LD15 |
| `UART_txd` | Output | `U11` | LVCMOS33 | High idle (Mark) | USB-UART TX (FPGA to Host PC) |
| `UART_rxd` | Input | `V12` | LVCMOS33 | Synchronized internally | USB-UART RX (Host PC to FPGA) |
| `i2c_scl` | Inout | `T5` | LVCMOS33 | PULLUP true, Open-drain | I2C Serial Clock line |
| `i2c_sda` | Inout | `T6` | LVCMOS33 | PULLUP true, Open-drain | I2C Serial Data line |

---

## 3. Physical Considerations

1. **I2C Open-Drain Bus**:
   - Both `i2c_scl` and `i2c_sda` are declared as bidirectional `inout` pins and driven with high-impedance (`1'bz`) when high, pulling to `1'b0` when low.
   - Internal pull-up resistors (`PULLUP true`) are enabled in `boolean_board.xdc` to ensure reliable rising edges without external pull-up resistors, though external 2.2 kΩ–4.7 kΩ pull-ups are also supported.

2. **Clocking & Timing Closure**:
   - Primary clock constraint:
     ```tcl
     create_clock -period 10.000 -name sys_clk [get_ports clk]
     ```
   - Clock enable `soc_clk_en` runs the CPU pipeline effectively at 25 MHz while keeping all registers synchronously constrained to the 100 MHz clock tree, guaranteeing setup and hold timing margins.

# Custom RV32I System-on-Chip (SoC) for Digital Boolean Board

A complete, fully verified, and synthesizable System-on-Chip (SoC) built around a custom **RV32I RISC-V processor core**, targeted for the **Real Digital Boolean Board** featuring the **AMD/Xilinx Spartan-7 XC7S50-CSGA324-1 FPGA**.

---

## Architecture Overview

```text
riscv_soc/
├── rtl/
│   ├── core/                        # RV32I CPU Core Submodules
│   │   ├── alu.v                    # 32-bit ALU (10 standard arithmetic/logic ops)
│   │   ├── alu_control.v            # ALU operation decoder (R-type & I-type)
│   │   ├── alu_src_mux.v            # Operand B mux (Register rs2 vs Immediate)
│   │   ├── branch_comparator.v      # Branch conditions (BEQ, BNE, BLT, BGE, BLTU, BGEU)
│   │   ├── control_unit.v           # Main instruction decoder (R, I, S, B, U, J)
│   │   ├── immediate_generator.v    # 32-bit immediate sign-extension
│   │   ├── load_store_unit.v        # Load alignment (LB,LH,LW,LBU,LHU) & store strobes (SB,SH,SW)
│   │   ├── pc.v                     # Program counter with stall and clk_en
│   │   ├── pc_offset_adder.v        # Target address adder for branches & JAL
│   │   ├── pc_plus_4.v              # PC+4 adder & JALR target generator (bit 0 cleared)
│   │   ├── register_file.v          # 32x32 general registers (x0 hardwired to zero)
│   │   ├── write_back_mux.v         # Writeback mux (ALU, Memory load, PC+4, LUI, AUIPC)
│   │   └── risc_core.v              # Top CPU core with PicoRV32 native bus master
│   ├── peripheral/                  # SoC Interconnect & Peripherals
│   │   ├── baud_rate_tx.v           # TX baud rate pulse generator (9600-115200)
│   │   ├── baud_rate_rx.v           # RX 16x oversampling tick generator
│   │   ├── uart_tx.v                # UART transmitter FSM (start, 8 data, stop)
│   │   ├── uart_rx.v                # UART receiver FSM with input synchronizer
│   │   ├── uart_peripheral.v        # Complete UART MMIO with status/baud registers
│   │   ├── scl_gen.v                # I2C SCL generator (100k/400k) with clock stretching
│   │   ├── i2c_master.v             # I2C master FSM (repeated start & multi-byte read)
│   │   ├── i2c_peripheral.v         # I2C MMIO with open-drain SDA/SCL
│   │   ├── gpio_peripheral.v        # 32-bit GPIO (16 LEDs out, 16 inputs)
│   │   ├── ram_sync.v               # 4 KB Code RAM + 8 KB Data RAM with byte strobes
│   │   └── soc_bus_interconnect.v   # Non-overlapping address decoder & bus mux
│   └── top/
│       └── riscv_soc_top.v          # Top-level SoC module
├── fpga/
│   └── fpga_top.v                   # FPGA board top (100 MHz oscillator, 25 MHz enable)
├── sim/                             # Self-Checking Simulation Testbenches
│   ├── i2c_slave_model.v            # Behavioral I2C sensor slave model (ADXL345 simulation)
│   ├── tb_core_instructions.v       # Self-checking RV32I core instruction testbench
│   ├── tb_system_bus.v              # Self-checking bus interconnect & address decoder testbench
│   ├── tb_gpio.v                    # Self-checking 32-bit GPIO testbench
│   ├── tb_uart.v                    # Self-checking UART transmission & loopback testbench
│   ├── tb_i2c.v                     # Self-checking I2C write & multi-byte read testbench
│   └── tb_soc_top.v                 # Full SoC integrated system testbench
├── constraints/
│   └── boolean_board.xdc            # Pin and timing constraints for Boolean FPGA
├── scripts/
│   ├── build.tcl                    # Vivado batch build script (Elab, Synth, Impl, Bitstream)
│   ├── gen_mem.py                   # Bit-exact Python assembler for test programs
│   └── run_all_sim.bat              # Batch script running all 6 testbenches
├── memory/
│   ├── instruction.mem              # Initial preloaded program (RV32I test suite)
│   └── test_all_instructions.mem    # Backup reference test memory image
├── docs/
│   ├── architecture.md              # Detailed SoC architecture & timing specification
│   ├── memory_map.md                # Complete memory map & peripheral register reference
│   └── pinout.md                    # Boolean FPGA pinout table & electrical notes
└── README.md                        # Project documentation and build guide
```

---

## Memory Map

All peripheral and memory address spaces are strictly non-overlapping, decoded using the upper 4 address bits `mem_addr[31:28]`:

| Address Range | Size | Component | Function |
| :--- | :--- | :--- | :--- |
| `0x0000_0000 - 0x0000_0FFF` | 4 KB (1024 words) | Code Memory / RAM | Reset vector (`0x00`), preloaded via `$readmemh("instruction.mem")` |
| `0x1000_0000 - 0x1000_1FFF` | 8 KB (2048 words) | Data RAM | Scratchpad / stack with byte write enables (`mem_wstrb`) |
| `0x2000_0000 - 0x2000_00FF` | 256 B | UART Controller | TX data, RX data, status flags, configurable baud rate (9600-115200) |
| `0x3000_0000 - 0x3000_00FF` | 256 B | 32-bit GPIO | 16 on-board LEDs (`[15:0]`) and inputs |
| `0x4000_0000 - 0x4000_00FF` | 256 B | I2C Controller | 7-bit addressing, repeated start, 100k/400k selection, multi-byte read |
| *All Other Addresses* | - | Unmapped Space | Returns `0xDEADBEEF` with 1-wait-state termination |

For individual register offsets and bit fields, refer to [`docs/memory_map.md`](file:///c:/Users/MOHAN/Downloads/Documents/projects/risc%20v%20soc/S5_mini_project/only_core_uart/riscv_soc/docs/memory_map.md).

---

## RV32I Instruction Set Verification

All required instructions have been implemented and verified with zero errors in self-checking testbenches:

| Group | Instructions Verified | Verification Method | Result |
| :--- | :--- | :--- | :--- |
| **A. R-type Arithmetic & Logic** | `ADD`, `SUB`, `AND`, `OR`, `XOR`, `SLL`, `SRL`, `SRA`, `SLT`, `SLTU` | Executed against signed & unsigned vectors; checked against expected values | **PASS** |
| **B. I-type Immediate Arithmetic & Logic** | `ADDI`, `SLTI`, `SLTIU`, `XORI`, `ORI`, `ANDI`, `SLLI`, `SRLI`, `SRAI` | Tested with positive and negative immediates, 5-bit shift amounts | **PASS** |
| **C. Loads** | `LB`, `LH`, `LW`, `LBU`, `LHU` | Tested byte selection (`addr[1:0]`), sign extension vs zero extension | **PASS** |
| **D. Stores** | `SB`, `SH`, `SW` | Verified byte write strobes (`mem_wstrb`), partial write preservation | **PASS** |
| **E. Conditional Branches** | `BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU` | Signed & unsigned comparisons; skipped branch trap verified | **PASS** |
| **F. Control Transfers (Jumps)** | `JAL`, `JALR` | Return address written to `rd` (`PC + 4`); JALR target bit 0 cleared | **PASS** |
| **G. Upper Immediates** | `LUI`, `AUIPC` | Verified upper 20 bits loaded to register and added to current PC | **PASS** |
| **H. Memory-Mapped I/O** | `SW` to GPIO (0x3000_0000) | Actuates on-board LEDs (`0x0055`) | **PASS** |

---

## Simulation Test Results

To run the complete automated regression suite:
```cmd
cmd.exe /c riscv_soc\scripts\run_all_sim.bat
```

### Actual Execution Results:
| # | Testbench File | Target Component | Status | Details |
| :---: | :--- | :--- | :---: | :--- |
| 1 | `sim/tb_core_instructions.v` | RV32I CPU Core Instruction Set | **PASS** | All 27 instruction operations + GPIO MMIO verified with 0 errors |
| 2 | `sim/tb_system_bus.v` | Native Bus Interconnect & Address Decoder | **PASS** | Code RAM, Data RAM, UART, GPIO, I2C, and unmapped spaces verified |
| 3 | `sim/tb_gpio.v` | 32-bit GPIO Peripheral | **PASS** | 16-bit LED write, byte strobes, and input pin reads verified |
| 4 | `sim/tb_uart.v` | UART Controller | **PASS** | Default 9600 baud, 115200 reconfiguration, loopback TX/RX verified |
| 5 | `sim/tb_i2c.v` | I2C Controller with Sensor Model | **PASS** | Register write, single-byte read (0xE5), 4-byte burst read verified |
| 6 | `sim/tb_soc_top.v` | Full Integrated RV32I SoC | **PASS** | Complete program execution from `instruction.mem` verified in 72 cycles |

---

## FPGA Implementation (Real Digital Boolean Board)

- **Target FPGA**: AMD / Xilinx Spartan-7 `xc7s50csga324-1`
- **Clock Scheme**: 100 MHz oscillator input on pin `F14` fed to Spartan-7 hardware MMCM (`MMCME2_BASE`) generating a dedicated, low-jitter 25.0 MHz global clock (`clk_soc`, 40.0 ns period) on a `BUFG` clock network.
- **Timing Closure Results**:
  - **Worst Negative Slack (WNS)**: `+14.717 ns` (Positive Slack / Timing Met)
  - **Total Negative Slack (TNS)**: `0.000 ns`
  - **Worst Hold Slack (WHS)**: `+0.147 ns` (Positive Slack)
  - **Failing Endpoints**: `0`
  - **Critical Warnings**: `0`
  - **Errors**: `0`
- **Pin Assignments**:
  - `UART_txd` = `U11`
  - `UART_rxd` = `V12`
  - `i2c_scl`  = `T5` (PULLUP enabled)
  - `i2c_sda`  = `T6` (PULLUP enabled)
  - `led[15:0]` = `{A4, B4, A3, B3, A2, B2, C3, E6, E5, E3, E2, E1, F2, F1, G2, G1}`
  - `btn_rst`  = `J2` (Active-high button synchronized to active-low internal reset with MMCM lock qualification)

### Default Application:
The instruction memory ([`memory/instruction.mem`](file:///c:/Users/MOHAN/Downloads/Documents/projects/risc%20v%20soc/S5_mini_project/only_core_uart/riscv_soc/memory/instruction.mem)) is preloaded with an exact **1.000-second GPIO LED0 blinking program**:
- At 25.0 MHz, 1 delay loop = 2 cycles = 80 ns.
- 12,500,000 iterations = exactly 1.000000000 second delay.
- Toggles LED0 (`LD0` on pin `G1`) ON for 1.0s and OFF for 1.0s continuously.

### Vivado Build Flow:
Run from Vivado Tcl console or batch mode:
```cmd
C:\vivado\2025.2\Vivado\bin\vivado.bat -mode batch -source riscv_soc\scripts\build.tcl
```
Or in the open Vivado GUI Tcl Console:
```tcl
reset_run synth_1
set_property STEPS.OPT_DESIGN.ARGS.DIRECTIVE NoBramPowerOpt [get_runs impl_1]
set_property STEPS.POWER_OPT_DESIGN.IS_ENABLED false [get_runs impl_1]
launch_runs impl_1 -to_step write_bitstream -jobs 2
```

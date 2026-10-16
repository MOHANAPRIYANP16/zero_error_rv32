#!/usr/bin/env python3
# ============================================================================
# gen_mem.py -- Bit-Exact RISC-V Assembler for SoC Verification Suite
# ============================================================================

def r_type(funct7, rs2, rs1, funct3, rd, opcode=0x33):
    return (funct7 << 25) | ((rs2 & 0x1F) << 20) | ((rs1 & 0x1F) << 15) | ((funct3 & 7) << 12) | ((rd & 0x1F) << 7) | (opcode & 0x7F)

def i_type(imm, rs1, funct3, rd, opcode=0x13):
    return ((imm & 0xFFF) << 20) | ((rs1 & 0x1F) << 15) | ((funct3 & 7) << 12) | ((rd & 0x1F) << 7) | (opcode & 0x7F)

def s_type(imm, rs2, rs1, funct3, opcode=0x23):
    imm11_5 = (imm >> 5) & 0x7F
    imm4_0 = imm & 0x1F
    return (imm11_5 << 25) | ((rs2 & 0x1F) << 20) | ((rs1 & 0x1F) << 15) | ((funct3 & 7) << 12) | (imm4_0 << 7) | (opcode & 0x7F)

def b_type(imm, rs2, rs1, funct3, opcode=0x63):
    b12 = (imm >> 12) & 1
    b10_5 = (imm >> 5) & 0x3F
    b4_1 = (imm >> 1) & 0xF
    b11 = (imm >> 11) & 1
    return (b12 << 31) | (b10_5 << 25) | ((rs2 & 0x1F) << 20) | ((rs1 & 0x1F) << 15) | ((funct3 & 7) << 12) | (b4_1 << 8) | (b11 << 7) | (opcode & 0x7F)

def u_type(imm, rd, opcode):
    return (imm & 0xFFFFF000) | ((rd & 0x1F) << 7) | (opcode & 0x7F)

def j_type(imm, rd, opcode=0x6F):
    j20 = (imm >> 20) & 1
    j10_1 = (imm >> 1) & 0x3FF
    j11 = (imm >> 11) & 1
    j19_12 = (imm >> 12) & 0xFF
    return (j20 << 31) | (j10_1 << 21) | (j11 << 20) | (j19_12 << 12) | ((rd & 0x1F) << 7) | (opcode & 0x7F)

instructions = [
    # PC = 0x00: LUI x2, 0x12345
    (u_type(0x12345000, 2, 0x37), "LUI x2, 0x12345"),
    # PC = 0x04: AUIPC x3, 0x00001 (PC=4 + 0x1000 = 0x1004)
    (u_type(0x00001000, 3, 0x17), "AUIPC x3, 0x00001"),

    # I-type Immediate Arithmetic & Logic
    # PC = 0x08: ADDI x4, x0, 10
    (i_type(10, 0, 0b000, 4, 0x13), "ADDI x4, 10"),
    # PC = 0x0C: ADDI x5, x0, -5
    (i_type(-5, 0, 0b000, 5, 0x13), "ADDI x5, -5"),
    # PC = 0x10: SLTI x6, x5, 0 (-5 < 0 signed -> 1)
    (i_type(0, 5, 0b010, 6, 0x13), "SLTI x6, x5, 0"),
    # PC = 0x14: SLTIU x7, x4, 20 (10 < 20 unsigned -> 1)
    (i_type(20, 4, 0b011, 7, 0x13), "SLTIU x7, x4, 20"),
    # PC = 0x18: XORI x8, x4, 15 (10 ^ 15 = 5)
    (i_type(15, 4, 0b100, 8, 0x13), "XORI x8, x4, 15"),
    # PC = 0x1C: ORI x9, x4, 5 (10 | 5 = 15)
    (i_type(5, 4, 0b110, 9, 0x13), "ORI x9, x4, 5"),
    # PC = 0x20: ANDI x10, x4, 8 (10 & 8 = 8)
    (i_type(8, 4, 0b111, 10, 0x13), "ANDI x10, x4, 8"),
    # PC = 0x24: SLLI x11, x4, 2 (10 << 2 = 40)
    (r_type(0b0000000, 2, 4, 0b001, 11, 0x13), "SLLI x11, x4, 2"),
    # PC = 0x28: SRLI x12, x11, 1 (40 >> 1 = 20)
    (r_type(0b0000000, 1, 11, 0b101, 12, 0x13), "SRLI x12, x11, 1"),
    # PC = 0x2C: SRAI x13, x5, 1 (-5 >>> 1 = -3)
    (r_type(0b0100000, 1, 5, 0b101, 13, 0x13), "SRAI x13, x5, 1"),

    # R-type Arithmetic & Logic
    # PC = 0x30: ADD x14, x4, x11 (10 + 40 = 50)
    (r_type(0b0000000, 11, 4, 0b000, 14, 0x33), "ADD x14, x4, x11"),
    # PC = 0x34: SUB x15, x11, x4 (40 - 10 = 30)
    (r_type(0b0100000, 4, 11, 0b000, 15, 0x33), "SUB x15, x11, x4"),
    # PC = 0x38: AND x16, x4, x9 (10 & 15 = 10)
    (r_type(0b0000000, 9, 4, 0b111, 16, 0x33), "AND x16, x4, x9"),
    # PC = 0x3C: OR x17, x4, x8 (10 | 5 = 15)
    (r_type(0b0000000, 8, 4, 0b110, 17, 0x33), "OR x17, x4, x8"),
    # PC = 0x40: XOR x18, x4, x8 (10 ^ 5 = 15)
    (r_type(0b0000000, 8, 4, 0b100, 18, 0x33), "XOR x18, x4, x8"),
    # PC = 0x44: SLL x19, x4, x6 (10 << 1 = 20)
    (r_type(0b0000000, 6, 4, 0b001, 19, 0x33), "SLL x19, x4, x6"),
    # PC = 0x48: SRL x20, x19, x6 (20 >> 1 = 10)
    (r_type(0b0000000, 6, 19, 0b101, 20, 0x33), "SRL x20, x19, x6"),
    # PC = 0x4C: SRA x21, x5, x6 (-5 >>> 1 = -3)
    (r_type(0b0100000, 6, 5, 0b101, 21, 0x33), "SRA x21, x5, x6"),
    # PC = 0x50: SLT x22, x5, x4 (-5 < 10 signed -> 1)
    (r_type(0b0000000, 4, 5, 0b010, 22, 0x33), "SLT x22, x5, x4"),
    # PC = 0x54: SLTU x23, x4, x5 (10 < 0xFFFFFFFB unsigned -> 1)
    (r_type(0b0000000, 5, 4, 0b011, 23, 0x33), "SLTU x23, x4, x5"),

    # Stores to Data RAM (Base 0x1000_0000)
    # PC = 0x58: LUI x24, 0x10000 (x24 = 0x1000_0000)
    (u_type(0x10000000, 24, 0x37), "LUI x24, 0x10000"),
    # PC = 0x5C: SW x14, 0(x24) (store word 50 at 0x1000_0000)
    (s_type(0, 14, 24, 0b010, 0x23), "SW x14, 0(x24)"),
    # PC = 0x60: SH x11, 4(x24) (store halfword 40 at 0x1000_0004)
    (s_type(4, 11, 24, 0b001, 0x23), "SH x11, 4(x24)"),
    # PC = 0x64: SB x4, 8(x24) (store byte 10 at 0x1000_0008)
    (s_type(8, 4, 24, 0b000, 0x23), "SB x4, 8(x24)"),

    # Loads from Data RAM
    # PC = 0x68: LW x25, 0(x24) (load word -> 50)
    (i_type(0, 24, 0b010, 25, 0x03), "LW x25, 0(x24)"),
    # PC = 0x6C: LH x26, 4(x24) (load signed halfword -> 40)
    (i_type(4, 24, 0b001, 26, 0x03), "LH x26, 4(x24)"),
    # PC = 0x70: LHU x27, 4(x24) (load unsigned halfword -> 40)
    (i_type(4, 24, 0b101, 27, 0x03), "LHU x27, 4(x24)"),
    # PC = 0x74: LB x28, 8(x24) (load signed byte -> 10)
    (i_type(8, 24, 0b000, 28, 0x03), "LB x28, 8(x24)"),
    # PC = 0x78: LBU x29, 8(x24) (load unsigned byte -> 10)
    (i_type(8, 24, 0b100, 29, 0x03), "LBU x29, 8(x24)"),

    # Conditional Branches
    # PC = 0x7C: BEQ x4, x4, +8 (branch to 0x84)
    (b_type(8, 4, 4, 0b000, 0x63), "BEQ x4, x4, +8"),
    # PC = 0x80: ADDI x30, x0, 99 (SKIPPED)
    (i_type(99, 0, 0b000, 30, 0x13), "ADDI x30, 99 (SKIPPED)"),
    # PC = 0x84: BNE x4, x5, +8 (branch to 0x8C)
    (b_type(8, 5, 4, 0b001, 0x63), "BNE x4, x5, +8"),
    # PC = 0x88: ADDI x30, x0, 99 (SKIPPED)
    (i_type(99, 0, 0b000, 30, 0x13), "ADDI x30, 99 (SKIPPED)"),
    # PC = 0x8C: BLT x5, x4, +8 (branch to 0x94)
    (b_type(8, 4, 5, 0b100, 0x63), "BLT x5, x4, +8"),
    # PC = 0x90: ADDI x30, x0, 99 (SKIPPED)
    (i_type(99, 0, 0b000, 30, 0x13), "ADDI x30, 99 (SKIPPED)"),
    # PC = 0x94: BGE x4, x5, +8 (branch to 0x9C)
    (b_type(8, 5, 4, 0b101, 0x63), "BGE x4, x5, +8"),
    # PC = 0x98: ADDI x30, x0, 99 (SKIPPED)
    (i_type(99, 0, 0b000, 30, 0x13), "ADDI x30, 99 (SKIPPED)"),
    # PC = 0x9C: BLTU x4, x5, +8 (branch to 0xA4)
    (b_type(8, 5, 4, 0b110, 0x63), "BLTU x4, x5, +8"),
    # PC = 0xA0: ADDI x30, x0, 99 (SKIPPED)
    (i_type(99, 0, 0b000, 30, 0x13), "ADDI x30, 99 (SKIPPED)"),
    # PC = 0xA4: BGEU x5, x4, +8 (branch to 0xAC)
    (b_type(8, 4, 5, 0b111, 0x63), "BGEU x5, x4, +8"),
    # PC = 0xA8: ADDI x30, x0, 99 (SKIPPED)
    (i_type(99, 0, 0b000, 30, 0x13), "ADDI x30, 99 (SKIPPED)"),

    # Jumps: JAL and JALR
    # PC = 0xAC: JAL x1, +8 (jump to 0xB4, return addr 0xB0 stored in x1)
    (j_type(8, 1, 0x6F), "JAL x1, +8"),
    # PC = 0xB0: ADDI x30, x0, 99 (SKIPPED)
    (i_type(99, 0, 0b000, 30, 0x13), "ADDI x30, 99 (SKIPPED)"),
    # PC = 0xB4: ADDI x31, x1, 12 (target addr = 0xB0 + 12 = 0xBC)
    (i_type(12, 1, 0b000, 31, 0x13), "ADDI x31, x1, 12"),
    # PC = 0xB8: JALR x1, 0(x31) (jump to 0xBC, return addr 0xBC stored in x1)
    (i_type(0, 31, 0b000, 1, 0x67), "JALR x1, 0(x31)"),

    # MMIO GPIO Write: turn on LEDs
    # PC = 0xBC: LUI x24, 0x30000 (GPIO base address)
    (u_type(0x30000000, 24, 0x37), "LUI x24, 0x30000"),
    # PC = 0xC0: ADDI x31, x0, 0x55
    (i_type(0x55, 0, 0b000, 31, 0x13), "ADDI x31, 0x55"),
    # PC = 0xC4: SW x31, 0(x24) (write 0x0055 to LEDs at 0x3000_0000)
    (s_type(0, 31, 24, 0b010, 0x23), "SW x31, 0(x24)"),

    # PC = 0xC8: End loop (JAL x0, 0)
    (j_type(0, 0, 0x6F), "JAL x0, 0")
]

for filename in ["riscv_soc/memory/instruction.mem", "riscv_soc/memory/test_all_instructions.mem", "instruction.mem"]:
    with open(filename, "w") as f:
        for idx, (code, disasm) in enumerate(instructions):
            pc = idx * 4
            f.write(f"// PC = 0x{pc:02X}: {disasm}\n")
            f.write(f"{code:08x}\n")

print(f"Generated {len(instructions)} instructions successfully!")

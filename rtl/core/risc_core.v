`timescale 1ns / 1ps

module risc_core (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        clk_en,
    input  wire [31:0] instruction,
    output wire [31:0] pc_out,

    // PicoRV32-compatible native memory bus master interface
    output wire        mem_valid,
    output wire        mem_instr,
    input  wire        mem_ready,
    output wire [31:0] mem_addr,
    output wire [31:0] mem_wdata,
    output wire [3:0]  mem_wstrb,
    input  wire [31:0] mem_rdata,

    output wire        illegal_instruction
);

    // Internal wires
    wire [31:0] pc_update, pc_out_int, imm, write_data;
    wire [31:0] read_data_1, read_data_2, ALU_result, Branch_target;
    wire [31:0] ALUSrc_out, pc_plus_four, formatted_load_data, write_data_mem;
    wire [3:0]  ALUControl, byte_en;
    wire [1:0]  ALUOp;
    wire        pc_src, Branch, Zero, reg_write, ALUSrc, MemtoReg;
    wire        MemRead, MemWrite, jump, jalr, lui, auipc;
    wire        branch_taken, stall;

    // Bus handshake and stall generation:
    // Core stalls on a data memory access (load or store) until slave asserts mem_ready
    assign mem_valid = (MemRead | MemWrite);
    assign mem_instr = 1'b0;
    assign mem_addr  = ALU_result;
    assign mem_wdata = write_data_mem;
    assign mem_wstrb = MemWrite ? byte_en : 4'b0000;
    assign stall     = mem_valid & !mem_ready;

    // Program Counter
    pc pc_block (
        .clk(clk),
        .rst_n(rst_n),
        .clk_en(clk_en),
        .stall(stall),
        .next_pc(pc_update),
        .pc_out(pc_out_int)
    );

    // PC + 4 and Branch/Jump Mux (JALR bit 0 cleared)
    pc_plus_4 plus_4 (
        .pc_out(pc_out_int),
        .Branch_target(Branch_target),
        .pc_src(pc_src),
        .jump(jump),
        .jalr(jalr),
        .ALU_result(ALU_result),
        .pc_plus_four(pc_plus_four),
        .next_pc(pc_update)
    );

    // PC Offset Adder
    pc_offset_adder offset_add (
        .PC(pc_out_int),
        .imm(imm),
        .Branch_target(Branch_target)
    );

    // Register File (x0 hardwired to 0)
    register_file rf_block (
        .clk(clk),
        .rst_n(rst_n),
        .clk_en(clk_en),
        .stall(stall),
        .Read_register_1(instruction[19:15]),
        .Read_register_2(instruction[24:20]),
        .write_register(instruction[11:7]),
        .write_data(write_data),
        .reg_write(reg_write),
        .read_data_1(read_data_1),
        .read_data_2(read_data_2)
    );

    // Immediate Generator
    immediate_generator imm_gen (
        .instruction(instruction),
        .imm(imm)
    );

    // Control Unit
    control_unit cu_block (
        .opcode(instruction[6:0]),
        .ALUSrc(ALUSrc),
        .MemtoReg(MemtoReg),
        .MemRead(MemRead),
        .Branch(Branch),
        .MemWrite(MemWrite),
        .RegWrite(reg_write),
        .jump(jump),
        .jalr(jalr),
        .lui(lui),
        .auipc(auipc),
        .ALUOp(ALUOp),
        .illegal_instruction(illegal_instruction)
    );

    // Branch Comparator
    branch_comparator br_comp (
        .funct3(instruction[14:12]),
        .rs1(read_data_1),
        .rs2(read_data_2),
        .branch_taken(branch_taken)
    );

    // ALU Source Multiplexer
    alu_src_mux alusrc_block (
        .imm(imm),
        .read_data_2(read_data_2),
        .ALUSrc(ALUSrc),
        .ALUSrc_out(ALUSrc_out)
    );

    // ALU Control Unit
    alu_control aluctrl_block (
        .ALUOp(ALUOp),
        .funct3(instruction[14:12]),
        .funct7_5(instruction[30]),
        .ALUControl(ALUControl)
    );

    // Arithmetic Logic Unit
    alu alu_block (
        .a(read_data_1),
        .b(ALUSrc_out),
        .ALUControl(ALUControl),
        .ALU_result(ALU_result),
        .Zero(Zero)
    );

    // Load / Store Unit
    load_store_unit lsu_block (
        .funct3(instruction[14:12]),
        .byte_offset(ALU_result[1:0]),
        .rs2_data(read_data_2),
        .raw_rdata(mem_rdata),
        .MemWrite(MemWrite),
        .byte_en(byte_en),
        .write_data_mem(write_data_mem),
        .formatted_load_data(formatted_load_data)
    );

    // Write-Back Multiplexer
    write_back_mux wr_bk_mux (
        .MemtoReg(MemtoReg),
        .jump(jump),
        .jalr(jalr),
        .lui(lui),
        .auipc(auipc),
        .read_data_mem(formatted_load_data),
        .ALU_result(ALU_result),
        .pc_plus_4(pc_plus_four),
        .imm(imm),
        .pc_out(pc_out_int),
        .write_data(write_data)
    );

    assign pc_src = Branch & branch_taken;
    assign pc_out = pc_out_int;

endmodule

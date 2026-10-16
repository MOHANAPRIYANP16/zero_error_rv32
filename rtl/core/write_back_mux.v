`timescale 1ns / 1ps

module write_back_mux (
    input  wire        MemtoReg,
    input  wire        jump,
    input  wire        jalr,
    input  wire        lui,
    input  wire        auipc,
    input  wire [31:0] read_data_mem, // formatted load data from load_store_unit
    input  wire [31:0] ALU_result,
    input  wire [31:0] pc_plus_4,
    input  wire [31:0] imm,
    input  wire [31:0] pc_out,
    output reg  [31:0] write_data
);

    always @(*) begin
        if (lui)
            write_data = imm;
        else if (auipc)
            write_data = pc_out + imm;
        else if (jump || jalr)
            write_data = pc_plus_4;
        else if (MemtoReg)
            write_data = read_data_mem;
        else
            write_data = ALU_result;
    end

endmodule

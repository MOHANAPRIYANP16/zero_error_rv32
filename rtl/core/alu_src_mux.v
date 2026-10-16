`timescale 1ns / 1ps

module alu_src_mux (
    input  wire [31:0] imm,
    input  wire [31:0] read_data_2,
    input  wire        ALUSrc,
    output wire [31:0] ALUSrc_out
);

    assign ALUSrc_out = ALUSrc ? imm : read_data_2;

endmodule

`timescale 1ns / 1ps

module pc_plus_4 (
    input  wire [31:0] pc_out,
    input  wire [31:0] Branch_target,
    input  wire        pc_src,
    input  wire        jump,
    input  wire        jalr,
    input  wire [31:0] ALU_result,
    output wire [31:0] pc_plus_four,
    output wire [31:0] next_pc
);

    assign pc_plus_four = pc_out + 32'd4;
    assign next_pc = (jump || pc_src) ? Branch_target :
                     (jalr)           ? {ALU_result[31:1], 1'b0} :
                                        pc_plus_four;

endmodule

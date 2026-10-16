`timescale 1ns / 1ps

module pc_offset_adder (
    input  wire [31:0] PC,
    input  wire [31:0] imm,
    output wire [31:0] Branch_target
);

    assign Branch_target = PC + imm;

endmodule

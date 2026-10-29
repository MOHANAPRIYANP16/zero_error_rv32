`timescale 1ns / 1ps

module control_unit (
    input  wire [6:0] opcode,
    output reg        ALUSrc,
    output reg        MemtoReg,
    output reg        MemRead,
    output reg        Branch,
    output reg        MemWrite,
    output reg        RegWrite,
    output reg        jump,
    output reg        jalr,
    output reg        lui,
    output reg        auipc,
    output reg  [1:0] ALUOp,
    output reg        illegal_instruction
);

    always @(*) begin
        // Default values to be assigned 
        ALUSrc              = 1'b0;
        MemtoReg            = 1'b0;
        MemRead             = 1'b0;
        Branch              = 1'b0;
        MemWrite            = 1'b0;
        RegWrite            = 1'b0;
        jump                = 1'b0;
        jalr                = 1'b0;
        lui                 = 1'b0;
        auipc               = 1'b0;
        ALUOp               = 2'b00;
        illegal_instruction = 1'b0;

        case (opcode)
            7'b0110011: begin // R-type
                RegWrite = 1'b1;
                ALUOp    = 2'b10;
            end

            7'b0010011: begin // I-type arithmetic & logic
                RegWrite = 1'b1;
                ALUSrc   = 1'b1;
                ALUOp    = 2'b11;
            end

            7'b0000011: begin // Loads (LB, LH, LW, LBU, LHU)
                RegWrite = 1'b1;
                ALUSrc   = 1'b1;
                MemRead  = 1'b1;
                MemtoReg = 1'b1;
                ALUOp    = 2'b00; // ADD base + offset
            end

            7'b0100011: begin // Stores (SB, SH, SW)
                ALUSrc   = 1'b1;
                MemWrite = 1'b1;
                ALUOp    = 2'b00; // ADD base + offset
            end

            7'b1100011: begin // Branches
                Branch   = 1'b1;
                ALUOp    = 2'b01;
            end

            7'b1101111: begin // JAL
                RegWrite = 1'b1;
                jump     = 1'b1;
            end

            7'b1100111: begin // JALR
                RegWrite = 1'b1;
                jalr     = 1'b1;
                ALUSrc   = 1'b1;
                ALUOp    = 2'b00; // ADD rs1 + imm
            end

            7'b0110111: begin // LUI
                RegWrite = 1'b1;
                lui      = 1'b1;
            end

            7'b0010111: begin // AUIPC
                RegWrite = 1'b1;
                auipc    = 1'b1;
            end

            default: begin
                illegal_instruction = 1'b1;
            end
        endcase
    end

endmodule

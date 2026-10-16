`timescale 1ns / 1ps

module alu_control (
    input  wire [1:0] ALUOp,
    input  wire [2:0] funct3,
    input  wire       funct7_5, // instruction[30]
    output reg  [3:0] ALUControl
);

    localparam ADD  = 4'b0000,
               SUB  = 4'b0001,
               AND  = 4'b0010,
               OR   = 4'b0011,
               XOR  = 4'b0100,
               SLL  = 4'b0101,
               SRL  = 4'b0110,
               SRA  = 4'b0111,
               SLT  = 4'b1000,
               SLTU = 4'b1001;

    always @(*) begin
        case (ALUOp)
            2'b00: ALUControl = ADD; // Loads, Stores, JALR
            2'b01: ALUControl = SUB; // Branch

            2'b10: begin // R-type
                case (funct3)
                    3'b000:  ALUControl = funct7_5 ? SUB : ADD;
                    3'b001:  ALUControl = SLL;
                    3'b010:  ALUControl = SLT;
                    3'b011:  ALUControl = SLTU;
                    3'b100:  ALUControl = XOR;
                    3'b101:  ALUControl = funct7_5 ? SRA : SRL;
                    3'b110:  ALUControl = OR;
                    3'b111:  ALUControl = AND;
                    default: ALUControl = ADD;
                endcase
            end

            2'b11: begin // I-type arithmetic & logic
                case (funct3)
                    3'b000:  ALUControl = ADD; // ADDI
                    3'b001:  ALUControl = SLL; // SLLI
                    3'b010:  ALUControl = SLT; // SLTI
                    3'b011:  ALUControl = SLTU; // SLTIU
                    3'b100:  ALUControl = XOR; // XORI
                    3'b101:  ALUControl = funct7_5 ? SRA : SRL; // SRAI / SRLI
                    3'b110:  ALUControl = OR;  // ORI
                    3'b111:  ALUControl = AND; // ANDI
                    default: ALUControl = ADD;
                endcase
            end

            default: ALUControl = ADD;
        endcase
    end

endmodule

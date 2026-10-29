`timescale 1ns / 1ps

module immediate_generator (
    input  wire [31:0] instruction,
    output reg  [31:0] imm
);

    wire [6:0] opcode = instruction[6:0];

    always @(*) begin
        case (opcode)
            // I-type, Loads, JALR
            7'b0010011,
            7'b0000011,
            7'b1100111: begin
                imm = {{20{instruction[31]}}, instruction[31:20]};
            end

            // S-type
            7'b0100011: begin
                imm = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
            end

            // B-type
            7'b1100011: begin
                imm = {{20{instruction[31]}}, instruction[7], instruction[30:25], instruction[11:8], 1'b0};
            end

            // U-type
            7'b0110111,
            7'b0010111: begin
                imm = {instruction[31:12], 12'd0};
            end

            // J-type 
            7'b1101111: begin
                imm = {{12{instruction[31]}}, instruction[19:12], instruction[20], instruction[30:21], 1'b0};
            end

            default: begin
                imm = 32'd0;
            end
        endcase
    end

endmodule

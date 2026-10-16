`timescale 1ns / 1ps

module alu (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [3:0]  ALUControl,
    output reg  [31:0] ALU_result,
    output wire        Zero
);

    always @(*) begin
        case (ALUControl)
            4'd0:    ALU_result = a + b;
            4'd1:    ALU_result = a - b;
            4'd2:    ALU_result = a & b;
            4'd3:    ALU_result = a | b;
            4'd4:    ALU_result = a ^ b;
            4'd5:    ALU_result = a << b[4:0];
            4'd6:    ALU_result = a >> b[4:0];
            4'd7:    ALU_result = $signed(a) >>> b[4:0];
            4'd8:    ALU_result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            4'd9:    ALU_result = (a < b) ? 32'd1 : 32'd0;
            default: ALU_result = 32'd0;
        endcase
    end

    assign Zero = (ALU_result == 32'd0);

endmodule

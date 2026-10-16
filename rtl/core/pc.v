`timescale 1ns / 1ps

module pc (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        clk_en,
    input  wire        stall,
    input  wire [31:0] next_pc,
    output reg  [31:0] pc_out
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_out <= 32'h0000_0000;
        end else if (clk_en && !stall) begin
            pc_out <= next_pc;
        end
    end

endmodule

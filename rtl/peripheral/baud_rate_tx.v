`timescale 1ns / 1ps

module baud_rate_tx #(
    parameter CLK_FREQ = 100_000_000
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire [2:0] baud_rate,
    output reg        clk_out1
);

    parameter baud_9600   = 3'd0;
    parameter baud_19200  = 3'd1;
    parameter baud_38400  = 3'd2;
    parameter baud_57600  = 3'd3;
    parameter baud_115200 = 3'd4;

    reg [31:0] max_val_tx;
    reg [31:0] count;

    always @(*) begin
        case (baud_rate)
            baud_9600:   max_val_tx = (CLK_FREQ / 9600)   - 1;
            baud_19200:  max_val_tx = (CLK_FREQ / 19200)  - 1;
            baud_38400:  max_val_tx = (CLK_FREQ / 38400)  - 1;
            baud_57600:  max_val_tx = (CLK_FREQ / 57600)  - 1;
            baud_115200: max_val_tx = (CLK_FREQ / 115200) - 1;
            default:     max_val_tx = (CLK_FREQ / 9600)   - 1;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count    <= 32'd0;
            clk_out1 <= 1'b0;
        end else begin
            if (count >= max_val_tx) begin
                count    <= 32'd0;
                clk_out1 <= 1'b1;
            end else begin
                count    <= count + 1'b1;
                clk_out1 <= 1'b0;
            end
        end
    end

endmodule

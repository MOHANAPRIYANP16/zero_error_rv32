`timescale 1ns / 1ps

module baud_rate_rx #(
    parameter CLK_FREQ = 100_000_000
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire [2:0] baud_rate_rx,
    output reg        clk_out2
);

    parameter baud_9600   = 3'd0;
    parameter baud_19200  = 3'd1;
    parameter baud_38400  = 3'd2;
    parameter baud_57600  = 3'd3;
    parameter baud_115200 = 3'd4;

    reg [31:0] max_val_rx;
    reg [31:0] count;

    always @(*) begin
        case (baud_rate_rx)
            baud_9600:   max_val_rx = (CLK_FREQ / (9600   * 16)) - 1;
            baud_19200:  max_val_rx = (CLK_FREQ / (19200  * 16)) - 1;
            baud_38400:  max_val_rx = (CLK_FREQ / (38400  * 16)) - 1;
            baud_57600:  max_val_rx = (CLK_FREQ / (57600  * 16)) - 1;
            baud_115200: max_val_rx = (CLK_FREQ / (115200 * 16)) - 1;
            default:     max_val_rx = (CLK_FREQ / (9600   * 16)) - 1;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count    <= 32'd0;
            clk_out2 <= 1'b0;
        end else begin
            if (count >= max_val_rx) begin
                count    <= 32'd0;
                clk_out2 <= 1'b1;
            end else begin
                count    <= count + 1'b1;
                clk_out2 <= 1'b0;
            end
        end
    end

endmodule

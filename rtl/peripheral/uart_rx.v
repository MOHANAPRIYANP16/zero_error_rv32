`timescale 1ns / 1ps

module uart_rx (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       clk_out2, // 16x baud pulse
    input  wire       rx,
    output reg        rx_done,
    output reg  [7:0] data_out
);

    localparam RX_IDLE  = 2'b00;
    localparam RX_START = 2'b01;
    localparam RX_DATA  = 2'b10;
    localparam RX_STOP  = 2'b11;

    // 2-stage input synchronizer to eliminate metastability
    reg [1:0] rx_sync;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rx_sync <= 2'b11;
        else
            rx_sync <= {rx_sync[0], rx};
    end
    wire rx_in = rx_sync[1];

    reg [2:0] bit_pos;
    reg [3:0] samp_cnt;
    reg [1:0] state;
    reg [7:0] shift;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_done  <= 1'b0;
            data_out <= 8'd0;
            bit_pos  <= 3'd0;
            samp_cnt <= 4'd0;
            state    <= RX_IDLE;
            shift    <= 8'd0;
        end else begin
            rx_done <= 1'b0;

            case (state)
                RX_IDLE: begin
                    if (!rx_in) begin // Falling edge detection
                        state    <= RX_START;
                        samp_cnt <= 4'd0;
                    end
                end

                RX_START: begin
                    if (clk_out2) begin
                        if (samp_cnt == 4'd7) begin // Midpoint of start bit
                            if (!rx_in) begin
                                samp_cnt <= 4'd0;
                                state    <= RX_DATA;
                                bit_pos  <= 3'd0;
                            end else begin
                                state    <= RX_IDLE;
                                samp_cnt <= 4'd0;
                            end
                        end else begin
                            samp_cnt <= samp_cnt + 1'b1;
                        end
                    end
                end

                RX_DATA: begin
                    if (clk_out2) begin
                        if (samp_cnt == 4'd15) begin // Midpoint of each data bit
                            samp_cnt       <= 4'd0;
                            shift[bit_pos] <= rx_in;
                            if (bit_pos == 3'd7) begin
                                state   <= RX_STOP;
                                bit_pos <= 3'd0;
                            end else begin
                                bit_pos <= bit_pos + 1'b1;
                            end
                        end else begin
                            samp_cnt <= samp_cnt + 1'b1;
                        end
                    end
                end

                RX_STOP: begin
                    if (clk_out2) begin
                        if (samp_cnt == 4'd15) begin // Midpoint of stop bit
                            if (rx_in) begin
                                data_out <= shift;
                                rx_done  <= 1'b1;
                            end
                            state    <= RX_IDLE;
                            samp_cnt <= 4'd0;
                        end else begin
                            samp_cnt <= samp_cnt + 1'b1;
                        end
                    end
                end

                default: begin
                    state <= RX_IDLE;
                end
            endcase
        end
    end

endmodule

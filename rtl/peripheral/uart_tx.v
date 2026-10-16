`timescale 1ns / 1ps

module uart_tx (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       clk_out1,
    input  wire       data_available,
    input  wire [7:0] data_in,
    output reg        fifo_read,
    output reg        tx,
    output reg        tx_busy
);

    localparam IDLE  = 2'b00;
    localparam START = 2'b01;
    localparam DATA  = 2'b10;
    localparam STOP  = 2'b11;

    reg [2:0] bitpos;
    reg [7:0] shift_reg;
    reg [1:0] state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx        <= 1'b1;
            state     <= IDLE;
            tx_busy   <= 1'b0;
            shift_reg <= 8'b0;
            bitpos    <= 3'b0;
            fifo_read <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    tx        <= 1'b1;
                    tx_busy   <= 1'b0;
                    fifo_read <= 1'b0;
                    if (data_available) begin
                        shift_reg <= data_in;
                        fifo_read <= 1'b1;
                        tx_busy   <= 1'b1;
                        state     <= START;
                    end
                end

                START: begin
                    fifo_read <= 1'b0;
                    if (clk_out1) begin
                        state  <= DATA;
                        tx     <= 1'b0; // Start bit
                        bitpos <= 3'b0;
                    end else begin
                        tx     <= 1'b1;
                    end
                end

                DATA: begin
                    if (clk_out1) begin
                        tx <= shift_reg[bitpos];
                        if (bitpos == 3'd7) begin
                            state <= STOP;
                        end else begin
                            bitpos <= bitpos + 1'b1;
                        end
                    end
                end

                STOP: begin
                    if (clk_out1) begin
                        state   <= IDLE;
                        tx      <= 1'b1; // Stop bit
                        tx_busy <= 1'b0;
                    end
                end

                default: begin
                    tx      <= 1'b1;
                    state   <= IDLE;
                    tx_busy <= 1'b0;
                end
            endcase
        end
    end

endmodule

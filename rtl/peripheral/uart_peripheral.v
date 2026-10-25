`timescale 1ns / 1ps

// ============================================================================
// uart_peripheral.v -- UART MMIO Peripheral with Hardware TX and RX FIFOs
//
// Base Address: 0x2000_0000
// Registers:
//   Offset 0x00: UART_DATA   [31:0]
//                - Write: pushes byte [7:0] into TX FIFO
//                - Read : pops and reads byte [7:0] from RX FIFO
//   Offset 0x04: UART_STATUS [31:0]
//                - bit 0    : tx_busy (1 = PHY active or TX FIFO not empty)
//                - bit 1    : rx_valid (1 = at least one byte available in RX FIFO)
//                - bit 2    : rx_overflow (1 = byte received when RX FIFO was full)
//                - bit 3    : tx_full (1 = TX FIFO is full, CPU should wait)
//                - bit 4    : tx_empty (1 = TX FIFO is completely empty)
//                - bit 5    : rx_empty (1 = RX FIFO is empty)
//                - bit 6    : rx_full (1 = RX FIFO is full)
//                - bits [15:8]  : rx_count (current fill level of RX FIFO)
//                - bits [23:16] : tx_count (current fill level of TX FIFO)
//   Offset 0x08: UART_BAUD   [31:0]
//                - bits [2:0]: 0=9600 (default), 1=19200, 2=38400, 3=57600, 4=115200
//   Offset 0x0C: UART_STATUS_CLEAR [31:0]
//                - Write bit 0: clears rx_overflow flag
//                - Write bit 1: flushes both TX and RX FIFOs
// ============================================================================

module uart_peripheral #(
    parameter CLK_FREQ    = 100_000_000,
    parameter FIFO_DEPTH  = 16,
    parameter FIFO_ADDR_W = 4
)(
    input  wire        clk,
    input  wire        rst_n,

    // Native bus slave interface
    input  wire        uart_sel,
    input  wire        uart_valid,
    input  wire [31:0] uart_addr,
    input  wire [31:0] uart_wdata,
    input  wire [3:0]  uart_wstrb,
    output reg         uart_ready,
    output reg  [31:0] uart_rdata,

    // Serial lines
    input  wire        UART_rxd,
    output wire        UART_txd
);

    wire [3:0] reg_offset = uart_addr[3:0];

    // Baud rate registers & wires
    reg  [2:0] baud_reg;
    wire       clk_out1; // TX baud pulse
    wire       clk_out2; // RX 16x baud pulse

    // Transmitter signals & FIFO wires
    wire       tx_phy_busy;
    wire       fifo_read_tx;
    wire [7:0] tx_fifo_dout;
    wire       tx_fifo_full;
    wire       tx_fifo_empty;
    wire       tx_fifo_overflow;
    wire [FIFO_ADDR_W:0] tx_fifo_count;
    reg        tx_fifo_wr_en;
    reg  [7:0] tx_fifo_din;

    // Receiver signals & FIFO wires
    wire       rx_done;
    wire [7:0] rx_byte_raw;
    wire [7:0] rx_fifo_dout;
    wire       rx_fifo_full;
    wire       rx_fifo_empty;
    wire       rx_fifo_overflow;
    wire [FIFO_ADDR_W:0] rx_fifo_count;
    reg        rx_fifo_rd_en;
    reg        rx_overflow_sticky;
    reg        fifo_flush;

    // Baud rate generator instances
    baud_rate_tx #(.CLK_FREQ(CLK_FREQ)) baud_tx_inst (
        .clk(clk),
        .rst_n(rst_n),
        .baud_rate(baud_reg),
        .clk_out1(clk_out1)
    );

    baud_rate_rx #(.CLK_FREQ(CLK_FREQ)) baud_rx_inst (
        .clk(clk),
        .rst_n(rst_n),
        .baud_rate_rx(baud_reg),
        .clk_out2(clk_out2)
    );

    // TX FIFO Instance
    uart_fifo #(
        .DATA_WIDTH(8),
        .DEPTH(FIFO_DEPTH),
        .ADDR_WIDTH(FIFO_ADDR_W)
    ) tx_fifo_inst (
        .clk(clk),
        .rst_n(rst_n),
        .clear(fifo_flush),
        .wr_en(tx_fifo_wr_en),
        .din(tx_fifo_din),
        .full(tx_fifo_full),
        .overflow(tx_fifo_overflow),
        .rd_en(fifo_read_tx),
        .dout(tx_fifo_dout),
        .empty(tx_fifo_empty),
        .count(tx_fifo_count)
    );

    // UART Transmitter PHY instance
    uart_tx uart_tx_inst (
        .clk(clk),
        .rst_n(rst_n),
        .clk_out1(clk_out1),
        .data_available(!tx_fifo_empty),
        .data_in(tx_fifo_dout),
        .fifo_read(fifo_read_tx),
        .tx(UART_txd),
        .tx_busy(tx_phy_busy)
    );

    // UART Receiver PHY instance
    uart_rx uart_rx_inst (
        .clk(clk),
        .rst_n(rst_n),
        .clk_out2(clk_out2),
        .rx(UART_rxd),
        .rx_done(rx_done),
        .data_out(rx_byte_raw)
    );

    // RX FIFO Instance
    uart_fifo #(
        .DATA_WIDTH(8),
        .DEPTH(FIFO_DEPTH),
        .ADDR_WIDTH(FIFO_ADDR_W)
    ) rx_fifo_inst (
        .clk(clk),
        .rst_n(rst_n),
        .clear(fifo_flush),
        .wr_en(rx_done),
        .din(rx_byte_raw),
        .full(rx_fifo_full),
        .overflow(rx_fifo_overflow),
        .rd_en(rx_fifo_rd_en),
        .dout(rx_fifo_dout),
        .empty(rx_fifo_empty),
        .count(rx_fifo_count)
    );

    // Sticky RX Overflow capture
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_overflow_sticky <= 1'b0;
        end else begin
            if (rx_fifo_overflow || (rx_done && rx_fifo_full))
                rx_overflow_sticky <= 1'b1;
            
            // Clear on write to UART_STATUS_CLEAR
            if (uart_sel && uart_valid && !uart_ready && (reg_offset == 4'hC) && (|uart_wstrb) && uart_wdata[0])
                rx_overflow_sticky <= 1'b0;
        end
    end

    // Bus read/write handler and FIFO interface
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uart_ready    <= 1'b0;
            uart_rdata    <= 32'd0;
            baud_reg      <= 3'd0; // Default 9600 baud
            tx_fifo_wr_en <= 1'b0;
            tx_fifo_din   <= 8'd0;
            rx_fifo_rd_en <= 1'b0;
            fifo_flush    <= 1'b0;
        end else begin
            uart_ready    <= 1'b0;
            tx_fifo_wr_en <= 1'b0;
            rx_fifo_rd_en <= 1'b0;
            fifo_flush    <= 1'b0;

            if (uart_sel && uart_valid && !uart_ready) begin
                uart_ready <= 1'b1;

                // Bus Read Access
                case (reg_offset)
                    4'h0: begin // Read from UART_DATA pops the RX FIFO
                        uart_rdata <= {24'd0, rx_fifo_dout};
                        if (!rx_fifo_empty && (uart_wstrb == 4'b0000))
                            rx_fifo_rd_en <= 1'b1;
                    end
                    4'h4: begin // Read UART_STATUS register
                        uart_rdata <= {
                            8'd0,
                            {(8-FIFO_ADDR_W-1){1'b0}}, tx_fifo_count, // [23:16] TX FIFO fill level
                            {(8-FIFO_ADDR_W-1){1'b0}}, rx_fifo_count, // [15:8]  RX FIFO fill level
                            1'b0,                                      // [7]
                            rx_fifo_full,                              // [6] 1 = RX FIFO full
                            rx_fifo_empty,                             // [5] 1 = RX FIFO empty
                            tx_fifo_empty,                             // [4] 1 = TX FIFO empty
                            tx_fifo_full,                              // [3] 1 = TX FIFO full
                            rx_overflow_sticky,                        // [2] 1 = RX overflow
                            !rx_fifo_empty,                            // [1] 1 = RX byte available
                            (tx_phy_busy || !tx_fifo_empty)            // [0] 1 = TX busy / active
                        };
                    end
                    4'h8: begin // Read UART_BAUD register
                        uart_rdata <= {29'd0, baud_reg};
                    end
                    default: begin
                        uart_rdata <= 32'd0;
                    end
                endcase

                // Bus Write Access
                if (|uart_wstrb) begin
                    case (reg_offset)
                        4'h0: begin // Write to UART_DATA pushes into TX FIFO
                            if (!tx_fifo_full) begin
                                tx_fifo_din   <= uart_wdata[7:0];
                                tx_fifo_wr_en <= 1'b1;
                            end
                        end
                        4'h8: begin // Write to UART_BAUD updates baud rate
                            baud_reg <= uart_wdata[2:0];
                        end
                        4'hC: begin // Write to UART_STATUS_CLEAR
                            if (uart_wdata[1])
                                fifo_flush <= 1'b1;
                        end
                        default: begin end
                    endcase
                end
            end
        end
    end

endmodule

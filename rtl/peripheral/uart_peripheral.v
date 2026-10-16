`timescale 1ns / 1ps

// ============================================================================
// uart_peripheral.v -- UART MMIO Peripheral with Configurable Baud Rates
//
// Base Address: 0x2000_0000
// Registers:
//   Offset 0x00: UART_DATA   [31:0]
//                - Write: writes byte [7:0] to transmit
//                - Read : reads received byte [7:0], clears rx_valid
//   Offset 0x04: UART_STATUS [31:0]
//                - bit 0: tx_busy (1 = transmitter busy)
//                - bit 1: rx_valid (1 = new received byte available)
//                - bit 2: rx_overflow (1 = byte arrived before previous read)
//   Offset 0x08: UART_BAUD   [31:0]
//                - bits [2:0]: 0=9600 (default), 1=19200, 2=38400, 3=57600, 4=115200
//   Offset 0x0C: UART_STATUS_CLEAR [31:0]
//                - Write: clears rx_overflow and rx_valid
// ============================================================================

module uart_peripheral #(
    parameter CLK_FREQ = 100_000_000
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

    // Transmitter signals
    reg        tx_start;
    reg  [7:0] tx_data;
    wire       tx_busy;
    wire       fifo_read_tx;

    // Receiver signals
    wire       rx_done;
    wire [7:0] rx_byte_raw;
    reg  [7:0] rx_data_reg;
    reg        rx_valid;
    reg        rx_overflow;

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

    // UART Transmitter instance
    uart_tx uart_tx_inst (
        .clk(clk),
        .rst_n(rst_n),
        .clk_out1(clk_out1),
        .data_available(tx_start),
        .data_in(tx_data),
        .fifo_read(fifo_read_tx),
        .tx(UART_txd),
        .tx_busy(tx_busy)
    );

    // UART Receiver instance
    uart_rx uart_rx_inst (
        .clk(clk),
        .rst_n(rst_n),
        .clk_out2(clk_out2),
        .rx(UART_rxd),
        .rx_done(rx_done),
        .data_out(rx_byte_raw)
    );

    // RX buffer capture & status update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_data_reg <= 8'd0;
            rx_valid    <= 1'b0;
            rx_overflow <= 1'b0;
        end else begin
            if (rx_done) begin
                if (rx_valid)
                    rx_overflow <= 1'b1;
                rx_data_reg <= rx_byte_raw;
                rx_valid    <= 1'b1;
            end

            // Clear rx_valid on reading UART_DATA register
            if (uart_sel && uart_valid && !uart_ready && (reg_offset == 4'h0) && (uart_wstrb == 4'b0000)) begin
                rx_valid <= 1'b0;
            end

            // Clear status via UART_STATUS_CLEAR register
            if (uart_sel && uart_valid && !uart_ready && (reg_offset == 4'hC) && (|uart_wstrb)) begin
                rx_overflow <= 1'b0;
                rx_valid    <= 1'b0;
            end
        end
    end

    // Bus read/write handler and TX trigger
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uart_ready <= 1'b0;
            uart_rdata <= 32'd0;
            tx_start   <= 1'b0;
            tx_data    <= 8'd0;
            baud_reg   <= 3'd0; // Default 9600 baud
        end else begin
            uart_ready <= 1'b0;
            tx_start   <= 1'b0;

            if (uart_sel && uart_valid && !uart_ready) begin
                uart_ready <= 1'b1;

                // Read access
                case (reg_offset)
                    4'h0:    uart_rdata <= {24'd0, rx_data_reg};
                    4'h4:    uart_rdata <= {29'd0, rx_overflow, rx_valid, tx_busy};
                    4'h8:    uart_rdata <= {29'd0, baud_reg};
                    default: uart_rdata <= 32'd0;
                endcase

                // Write access
                if (|uart_wstrb) begin
                    case (reg_offset)
                        4'h0: begin // Write to UART_DATA transmits a byte
                            if (!tx_busy) begin
                                tx_data  <= uart_wdata[7:0];
                                tx_start <= 1'b1;
                            end
                        end
                        4'h8: begin // Write to UART_BAUD updates baud rate
                            baud_reg <= uart_wdata[2:0];
                        end
                        default: begin end
                    endcase
                end
            end
        end
    end

endmodule

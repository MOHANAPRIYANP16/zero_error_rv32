`timescale 1ns / 1ps

module uart_peripheral #(
    parameter CLK_FREQ    = 100_000_000,
    parameter FIFO_DEPTH  = 16,
    parameter FIFO_ADDR_W = 4
)(
    input  wire        clk,
    input  wire        rst_n,

    input  wire        uart_sel,
    input  wire        uart_valid,
    input  wire [31:0] uart_addr,
    input  wire [31:0] uart_wdata,
    input  wire [3:0]  uart_wstrb,
    output reg         uart_ready,
    output reg  [31:0] uart_rdata,

    input  wire        UART_rxd,
    output wire        UART_txd
);

    wire [3:0] reg_offset = uart_addr[3:0];

   
    reg  [2:0] baud_reg;
    wire       clk_out1; 
    wire       clk_out2; 

    
    wire       tx_phy_busy;
    wire       fifo_read_tx;
    wire [7:0] tx_fifo_dout;
    wire       tx_fifo_full;
    wire       tx_fifo_empty;
    wire       tx_fifo_overflow;
    wire [FIFO_ADDR_W:0] tx_fifo_count;
    reg        tx_fifo_wr_en;
    reg  [7:0] tx_fifo_din;

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

    uart_rx uart_rx_inst (
        .clk(clk),
        .rst_n(rst_n),
        .clk_out2(clk_out2),
        .rx(UART_rxd),
        .rx_done(rx_done),
        .data_out(rx_byte_raw)
    );

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

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_overflow_sticky <= 1'b0;
        end else begin
            if (rx_fifo_overflow || (rx_done && rx_fifo_full))
                rx_overflow_sticky <= 1'b1;
            
            if (uart_sel && uart_valid && !uart_ready && (reg_offset == 4'hC) && (|uart_wstrb) && uart_wdata[0])
                rx_overflow_sticky <= 1'b0;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uart_ready    <= 1'b0;
            uart_rdata    <= 32'd0;
            baud_reg      <= 3'd0; 
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

                case (reg_offset)
                    4'h0: begin 
                        uart_rdata <= {24'd0, rx_fifo_dout};
                        if (!rx_fifo_empty && (uart_wstrb == 4'b0000))
                            rx_fifo_rd_en <= 1'b1;
                    end
                    4'h4: begin 
                        uart_rdata <= {
                            8'd0,
                            {(8-FIFO_ADDR_W-1){1'b0}}, tx_fifo_count, 
                            {(8-FIFO_ADDR_W-1){1'b0}}, rx_fifo_count, 
                            1'b0,                                      
                            rx_fifo_full,                              
                            rx_fifo_empty,                             
                            tx_fifo_empty,                             
                            tx_fifo_full,                              
                            rx_overflow_sticky,                        
                            !rx_fifo_empty,                            
                            (tx_phy_busy || !tx_fifo_empty)            
                        };
                    end
                    4'h8: begin 
                        uart_rdata <= {29'd0, baud_reg};
                    end
                    default: begin
                        uart_rdata <= 32'd0;
                    end
                endcase


                if (|uart_wstrb) begin
                    case (reg_offset)
                        4'h0: begin 
                            if (!tx_fifo_full) begin
                                tx_fifo_din   <= uart_wdata[7:0];
                                tx_fifo_wr_en <= 1'b1;
                            end
                        end
                        4'h8: begin 
                            baud_reg <= uart_wdata[2:0];
                        end
                        4'hC: begin 
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

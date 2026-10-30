`timescale 1ns / 1ps

module tb_uart;

    reg clk = 0;
    always #5 clk = ~clk; // 100 MHz clock

    reg rst_n = 0;

    reg         uart_sel   = 0;
    reg         uart_valid = 0;
    reg  [31:0] uart_addr  = 0;
    reg  [31:0] uart_wdata = 0;
    reg  [3:0]  uart_wstrb = 0;
    wire        uart_ready;
    wire [31:0] uart_rdata;

    wire uart_txd;
    reg  uart_rxd = 1'b1;

    // Use fast baud parameters for simulation (115200 baud)
    uart_peripheral #(
        .CLK_FREQ(100_000_000)
    ) dut_uart (
        .clk(clk),
        .rst_n(rst_n),
        .uart_sel(uart_sel),
        .uart_valid(uart_valid),
        .uart_addr(uart_addr),
        .uart_wdata(uart_wdata),
        .uart_wstrb(uart_wstrb),
        .uart_ready(uart_ready),
        .uart_rdata(uart_rdata),
        .UART_rxd(uart_rxd),
        .UART_txd(uart_txd)
    );

    integer errors = 0;

    task uart_write;
        input [31:0] addr;
        input [31:0] wdata;
        begin
            @(posedge clk);
            uart_sel   <= 1'b1;
            uart_valid <= 1'b1;
            uart_addr  <= addr;
            uart_wdata <= wdata;
            uart_wstrb <= 4'b0001;
            @(posedge clk);
            while (!uart_ready) @(posedge clk);
            uart_sel   <= 1'b0;
            uart_valid <= 1'b0;
            uart_wstrb <= 4'b0000;
            @(posedge clk);
        end
    endtask

    task uart_read;
        input  [31:0] addr;
        output [31:0] rdata;
        begin
            @(posedge clk);
            uart_sel   <= 1'b1;
            uart_valid <= 1'b1;
            uart_addr  <= addr;
            uart_wstrb <= 4'b0000;
            @(posedge clk);
            while (!uart_ready) @(posedge clk);
            rdata = uart_rdata;
            uart_sel   <= 1'b0;
            uart_valid <= 1'b0;
            @(posedge clk);
        end
    endtask

    reg [31:0] status_val;
    reg [31:0] rx_val;

    initial begin
        $display("==================================================================");
        $display("   STARTING UART PERIPHERAL UNIT TESTBENCH                        ");
        $display("==================================================================");

        rst_n = 0;
        #25;
        rst_n = 1;
        #20;

        $display("\n--- Testing Default Baud Rate Register (0x08) ---");
        uart_read(32'h2000_0008, status_val);
        if (status_val[2:0] === 3'd0)
            $display("  [PASS] Default baud rate is 9600 (code 0)");
        else begin
            $display("  [FAIL] Default baud rate mismatch: expected 0, got %0d", status_val[2:0]);
            errors = errors + 1;
        end

        $display("\n--- Configuring Baud Rate to 115200 (code 4) ---");
        uart_write(32'h2000_0008, 32'd4);
        uart_read(32'h2000_0008, status_val);
        if (status_val[2:0] === 3'd4)
            $display("  [PASS] Configured baud rate readback confirmed: 115200 (code 4)");
        else begin
            $display("  [FAIL] Baud rate readback mismatch: expected 4, got %0d", status_val[2:0]);
            errors = errors + 1;
        end

        $display("\n--- Testing Transmission & Loopback Reception ---");
        // Connect TX output directly to RX input
        fork
            begin : tx_thread
                uart_write(32'h2000_0000, 32'h0000_0059); // Send ASCII 'Y' (0x59)
                // Wait for transmission to complete
                uart_read(32'h2000_0004, status_val);
                while (status_val[0]) begin // wait until tx_busy clears
                    #1000;
                    uart_read(32'h2000_0004, status_val);
                end
                $display("  [PASS] Transmission of byte 0x59 completed, tx_busy cleared");
            end

            begin : rx_wire_loop
                while (1) begin
                    @(posedge clk);
                    uart_rxd <= uart_txd;
                end
            end
        join_any

        #5000;
        // Verify rx_valid
        uart_read(32'h2000_0004, status_val);
        if (status_val[1] === 1'b1)
            $display("  [PASS] rx_valid asserted in status register");
        else begin
            $display("  [FAIL] rx_valid not set: status = 0x%08h", status_val);
            errors = errors + 1;
        end

        // Read received data
        uart_read(32'h2000_0000, rx_val);
        if (rx_val[7:0] === 8'h59)
            $display("  [PASS] Received byte matched: expected 0x59, got 0x%02h", rx_val[7:0]);
        else begin
            $display("  [FAIL] Received byte mismatch: expected 0x59, got 0x%02h", rx_val[7:0]);
            errors = errors + 1;
        end

        // Verify rx_valid automatically cleared after read
        uart_read(32'h2000_0004, status_val);
        if (status_val[1] === 1'b0)
            $display("  [PASS] rx_valid automatically cleared after data register read");
        else begin
            $display("  [FAIL] rx_valid did not clear after read: status = 0x%08h", status_val);
            errors = errors + 1;
        end

        $display("\n==================================================================");
        if (errors == 0) begin
            $display("   ALL UART PERIPHERAL TESTS PASSED! (0 errors)                   ");
            $display("==================================================================");
        end else begin
            $display("   UART TEST COMPLETED WITH %0d ERRORS!                           ", errors);
            $display("==================================================================");
        end

        $finish;
    end

     initial begin
        $dumpfile("tb_uart.vcd");
        $dumpvars(0,tb_uart);
    end

endmodule

`timescale 1ns / 1ps

module tb_r307_soc;

    reg clk = 0;
    always #20 clk = ~clk; 

    reg rst_n = 0;

   
    reg         mem_valid = 0;
    reg         mem_instr = 0;
    reg  [31:0] mem_addr  = 0;
    reg  [31:0] mem_wdata = 0;
    reg  [3:0]  mem_wstrb = 0;
    wire        mem_ready;
    wire [31:0] mem_rdata;

    // Slaves Wires
    wire code_sel, code_valid, code_ready;
    wire [31:0] code_rdata = 32'h0;

    wire data_sel, data_valid, data_ready;
    wire [31:0] data_rdata = 32'h0;

    wire uart_sel, uart_valid, uart_ready;
    wire [31:0] uart_rdata;

    wire gpio_sel, gpio_valid, gpio_ready;
    wire [31:0] gpio_rdata;

    wire i2c_sel, i2c_valid, i2c_ready;
    wire [31:0] i2c_rdata = 32'h0;

    wire uart1_sel, uart1_valid, uart1_ready;
    wire [31:0] uart1_rdata;

    // External UART Lines
    reg  UART0_rxd = 1'b1;
    wire UART0_txd;

    wire UART1_rxd; // Sensor to FPGA
    wire UART1_txd; // FPGA to Sensor

    // GPIO LED Lines
    wire [15:0] led;

 
    soc_bus_interconnect bus_mux (
        .clk(clk),
        .rst_n(rst_n),
        .mem_valid(mem_valid),
        .mem_instr(mem_instr),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb),
        .mem_ready(mem_ready),
        .mem_rdata(mem_rdata),

        .code_sel(code_sel),
        .code_valid(code_valid),
        .code_ready(1'b1),
        .code_rdata(code_rdata),

        .data_sel(data_sel),
        .data_valid(data_valid),
        .data_ready(1'b1),
        .data_rdata(data_rdata),

        .uart_sel(uart_sel),
        .uart_valid(uart_valid),
        .uart_ready(uart_ready),
        .uart_rdata(uart_rdata),

        .gpio_sel(gpio_sel),
        .gpio_valid(gpio_valid),
        .gpio_ready(gpio_ready),
        .gpio_rdata(gpio_rdata),

        .i2c_sel(i2c_sel),
        .i2c_valid(i2c_valid),
        .i2c_ready(1'b1),
        .i2c_rdata(i2c_rdata),

        .uart1_sel(uart1_sel),
        .uart1_valid(uart1_valid),
        .uart1_ready(uart1_ready),
        .uart1_rdata(uart1_rdata)
    );

    uart_peripheral #(
        .CLK_FREQ(25_000_000)
    ) uart0_inst (
        .clk(clk),
        .rst_n(rst_n),
        .uart_sel(uart_sel),
        .uart_valid(uart_valid),
        .uart_addr(mem_addr),
        .uart_wdata(mem_wdata),
        .uart_wstrb(mem_wstrb),
        .uart_ready(uart_ready),
        .uart_rdata(uart_rdata),
        .UART_rxd(UART0_rxd),
        .UART_txd(UART0_txd)
    );


    uart_peripheral #(
        .CLK_FREQ(25_000_000)
    ) uart1_inst (
        .clk(clk),
        .rst_n(rst_n),
        .uart_sel(uart1_sel),
        .uart_valid(uart1_valid),
        .uart_addr(mem_addr),
        .uart_wdata(mem_wdata),
        .uart_wstrb(mem_wstrb),
        .uart_ready(uart1_ready),
        .uart_rdata(uart1_rdata),
        .UART_rxd(UART1_rxd),
        .UART_txd(UART1_txd)
    );

    
    gpio_peripheral gpio_inst (
        .clk(clk),
        .rst_n(rst_n),
        .gpio_sel(gpio_sel),
        .gpio_valid(gpio_valid),
        .gpio_addr(mem_addr),
        .gpio_wdata(mem_wdata),
        .gpio_wstrb(mem_wstrb),
        .gpio_ready(gpio_ready),
        .gpio_rdata(gpio_rdata),
        .led_out(led),
        .gpio_in(16'h0000)
    );

    r307_sensor_model #(
        .BAUD_RATE(57600)
    ) sensor (
        .clk(clk),
        .rst_n(rst_n),
        .rx(UART1_txd),
        .tx(UART1_rxd)
    );

    // ------------------------------------------------------------------------
    // Bus Access Tasks
    // ------------------------------------------------------------------------
    task bus_write(input [31:0] addr, input [31:0] data);
        begin
            @(posedge clk);
            mem_addr  <= addr;
            mem_wdata <= data;
            mem_wstrb <= 4'b1111;
            mem_valid <= 1'b1;
            @(posedge clk);
            while (!mem_ready) @(posedge clk);
            mem_valid <= 1'b0;
            mem_wstrb <= 4'b0000;
            @(posedge clk);
        end
    endtask

    task bus_read(input [31:0] addr, output [31:0] data);
        begin
            @(posedge clk);
            mem_addr  <= addr;
            mem_wstrb <= 4'b0000;
            mem_valid <= 1'b1;
            @(posedge clk);
            while (!mem_ready) @(posedge clk);
            data = mem_rdata;
            mem_valid <= 1'b0;
            @(posedge clk);
        end
    endtask

    integer errors = 0;
    reg [31:0] rval;
    integer i;

    // R307 Password Verify Frame (16 bytes):
    // EF 01 FF FF FF FF 01 00 07 13 00 00 00 00 00 1B
    reg [7:0] pwd_frame [0:15];
    reg [7:0] rx_pkt [0:11];
    initial begin
        pwd_frame[0]  = 8'hEF;
        pwd_frame[1]  = 8'h01;
        pwd_frame[2]  = 8'hFF;
        pwd_frame[3]  = 8'hFF;
        pwd_frame[4]  = 8'hFF;
        pwd_frame[5]  = 8'hFF;
        pwd_frame[6]  = 8'h01; // PID Command
        pwd_frame[7]  = 8'h00; // Len High
        pwd_frame[8]  = 8'h07; // Len Low (7 bytes: cmd 1 + pwd 4 + csum 2)
        pwd_frame[9]  = 8'h13; // Command: Verify Password
        pwd_frame[10] = 8'h00; // Pwd byte 3
        pwd_frame[11] = 8'h00; // Pwd byte 2
        pwd_frame[12] = 8'h00; // Pwd byte 1
        pwd_frame[13] = 8'h00; // Pwd byte 0
        pwd_frame[14] = 8'h00; // Csum High (0x01 + 0x07 + 0x13 = 0x001B)
        pwd_frame[15] = 8'h1B; // Csum Low
    end

    initial begin
        $dumpfile("tb_r307_soc.vcd");
        $dumpvars(0, tb_r307_soc);

        $display("==================================================================");
        $display("   STARTING DUAL-UART RV32I SOC & R307 FINGERPRINT TESTBENCH      ");
        $display("==================================================================");

        rst_n = 0;
        #200;
        rst_n = 1;
        #200;

        // --------------------------------------------------------------------
        // Test 1: Address Map & Baud Rate Configuration
        // --------------------------------------------------------------------
        $display("\n--- Test 1: Configure Dual UART Baud Rates ---");
        // Set UART0 (PC console) to 115200 baud (code 4)
        bus_write(32'h2000_0008, 32'd4);
        bus_read(32'h2000_0008, rval);
        if (rval[2:0] === 3'd4)
            $display("  [PASS] UART0 Baud Rate set to 115200 (code 4)");
        else begin
            $display("  [FAIL] UART0 Baud readback mismatch: expected 4, got %0d", rval);
            errors = errors + 1;
        end

        // Set UART1 (R307 sensor) to 57600 baud (code 3)
        bus_write(32'h5000_0008, 32'd3);
        bus_read(32'h5000_0008, rval);
        if (rval[2:0] === 3'd3)
            $display("  [PASS] UART1 Baud Rate set to 57600 (code 3)");
        else begin
            $display("  [FAIL] UART1 Baud readback mismatch: expected 3, got %0d", rval);
            errors = errors + 1;
        end

        // --------------------------------------------------------------------
        // Test 2: Status Register Checks
        // --------------------------------------------------------------------
        $display("\n--- Test 2: Dual UART Status Register Checks ---");
        bus_read(32'h2000_0004, rval);
        $display("  UART0 Status: 0x%08x (tx_empty=%b, rx_empty=%b)", rval, rval[4], rval[5]);
        if (rval[4] === 1'b1 && rval[5] === 1'b1)
            $display("  [PASS] UART0 FIFOs initially empty");
        else begin
            $display("  [FAIL] Unexpected UART0 initial status");
            errors = errors + 1;
        end

        bus_read(32'h5000_0004, rval);
        $display("  UART1 Status: 0x%08x (tx_empty=%b, rx_empty=%b)", rval, rval[4], rval[5]);
        if (rval[4] === 1'b1 && rval[5] === 1'b1)
            $display("  [PASS] UART1 FIFOs initially empty");
        else begin
            $display("  [FAIL] Unexpected UART1 initial status");
            errors = errors + 1;
        end

        // --------------------------------------------------------------------
        // Test 3: Burst Write R307 Command to UART1 TX FIFO (16 clock cycles)
        // --------------------------------------------------------------------
        $display("\n--- Test 3: Transmit R307 Password Verify Frame to UART1 ---");
        $display("  Burst writing 16-byte command frame to UART1 TX FIFO at bus speed...");
        for (i = 0; i < 16; i = i + 1) begin
            bus_write(32'h5000_0000, {24'd0, pwd_frame[i]});
        end

        bus_read(32'h5000_0004, rval);
        $display("  UART1 Status after burst write: 0x%08x (TX Count = %0d, TX Busy = %b)",
                 rval, (rval >> 16) & 8'hFF, rval[0]);
        if (rval[0] === 1'b1)
            $display("  [PASS] UART1 Transmitter active and serializing packet to sensor");
        else begin
            $display("  [FAIL] UART1 should be busy transmitting");
            errors = errors + 1;
        end

        // --------------------------------------------------------------------
        // Test 4: Sensor Model Processes Packet & Sends ACK (0x00)
        // --------------------------------------------------------------------
        $display("\n--- Test 4: Waiting for Sensor ACK on UART1 RX ---");
        // Wait for sensor to receive packet and respond (57600 baud packet takes ~5 ms)
        // In simulation: 16 bytes tx (~2.7ms) + latency + 12 bytes rx (~2ms)
        $display("  Simulating UART1 serial transmission at 57600 baud...");

        // Wait until UART1 RX FIFO receives ACK packet (starts with 0xEF 0x01)
        rval = 32'd0;
        while ((rval & 32'h02) == 0) begin
            #50_000; // Advance time
            bus_read(32'h5000_0004, rval);
        end

        $display("  [PASS] Byte received in UART1 RX FIFO! Status = 0x%08x (RX Count = %0d)",
                 rval, (rval >> 8) & 8'hFF);

        // Read out ACK response packet
        // Expected ACK packet for verify password:
        // EF 01 FF FF FF FF 07 00 03 00 00 0A
        // 0: EF, 1: 01, 2-5: FF, 6: 07(ACK), 7-8: 0003(len), 9: 00(ACK_OK), 10-11: 000A(csum)
        #5_000_000; // Allow full ACK packet to enter RX FIFO

        bus_read(32'h5000_0004, rval);
        $display("  UART1 RX fill level: %0d bytes received", (rval >> 8) & 8'hFF);

        
        for (i = 0; i < 12; i = i + 1) begin
            bus_read(32'h5000_0000, rval);
            rx_pkt[i] = rval[7:0];
        end

        $display("  ACK Packet readback: %02x %02x %02x %02x %02x %02x %02x %02x %02x [%02x] %02x %02x",
                 rx_pkt[0], rx_pkt[1], rx_pkt[2], rx_pkt[3], rx_pkt[4], rx_pkt[5],
                 rx_pkt[6], rx_pkt[7], rx_pkt[8], rx_pkt[9], rx_pkt[10], rx_pkt[11]);

        if (rx_pkt[0] === 8'hEF && rx_pkt[1] === 8'h01 && rx_pkt[6] === 8'h07 && rx_pkt[9] === 8'h00) begin
            $display("  [PASS] Valid R307 ACK Header (0xEF01) and PID (0x07) received!");
            $display("  [PASS] Sensor Password Verification SUCCESS (Confirmation Code: 0x00)!");
        end else begin
            $display("  [FAIL] Unexpected ACK packet content");
            errors = errors + 1;
        end

        // --------------------------------------------------------------------
        // Test 5: Actuate GPIO LED14 (Authentication Success)
        // --------------------------------------------------------------------
        $display("\n--- Test 5: Actuate GPIO LEDs for Success Indication ---");
        bus_write(32'h3000_0000, 32'h0000_4000); // Drive LED14 HIGH
        bus_read(32'h3000_0000, rval);
        if (rval[14] === 1'b1 && rval[15] === 1'b0)
            $display("  [PASS] GPIO LED14 correctly illuminated (0x4000) for Authentication Success");
        else begin
            $display("  [FAIL] GPIO LED status unexpected: 0x%04x", rval[15:0]);
            errors = errors + 1;
        end

        $display("\n==================================================================");
        if (errors == 0)
            $display("   >>> ALL DUAL-UART & R307 SENSOR TESTS PASSED! (0 errors) <<<");
        else
            $display("   >>> TESTBENCH FINISHED WITH %0d ERRORS <<<", errors);
        $display("==================================================================");
        $finish;
    end

endmodule

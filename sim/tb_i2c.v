`timescale 1ns / 1ps

// ============================================================================
// tb_i2c.v -- Self-Checking Unit Testbench for I2C Peripheral with Behavioral Slave
// ============================================================================

module tb_i2c;

    reg clk = 0;
    always #5 clk = ~clk; // 100 MHz clock

    reg rst_n = 0;

    reg         i2c_sel   = 0;
    reg         i2c_valid = 0;
    reg  [31:0] i2c_addr  = 0;
    reg  [31:0] i2c_wdata = 0;
    reg  [3:0]  i2c_wstrb = 0;
    wire        i2c_ready;
    wire [31:0] i2c_rdata;

    wire sda;
    wire scl;

    // External pull-up resistors for open-drain bus lines
    pullup (sda);
    pullup (scl);

    // DUT I2C Peripheral
    i2c_peripheral #(
        .CLK_FREQ(100_000_000)
    ) dut_i2c (
        .clk(clk),
        .rst_n(rst_n),
        .i2c_sel(i2c_sel),
        .i2c_valid(i2c_valid),
        .i2c_addr(i2c_addr),
        .i2c_wdata(i2c_wdata),
        .i2c_wstrb(i2c_wstrb),
        .i2c_ready(i2c_ready),
        .i2c_rdata(i2c_rdata),
        .sda(sda),
        .scl(scl)
    );

    // Behavioral Sensor Slave Model (Address 0x53)
    i2c_slave_model #(
        .SLAVE_ADDR(7'h53)
    ) slave_sensor (
        .scl(scl),
        .sda(sda)
    );

    integer errors = 0;

    task i2c_bus_write;
        input [31:0] addr;
        input [31:0] wdata;
        begin
            @(posedge clk);
            i2c_sel   <= 1'b1;
            i2c_valid <= 1'b1;
            i2c_addr  <= addr;
            i2c_wdata <= wdata;
            i2c_wstrb <= 4'b0001;
            @(posedge clk);
            while (!i2c_ready) @(posedge clk);
            i2c_sel   <= 1'b0;
            i2c_valid <= 1'b0;
            i2c_wstrb <= 4'b0000;
            @(posedge clk);
        end
    endtask

    task i2c_bus_read;
        input  [31:0] addr;
        output [31:0] rdata;
        begin
            @(posedge clk);
            i2c_sel   <= 1'b1;
            i2c_valid <= 1'b1;
            i2c_addr  <= addr;
            i2c_wstrb <= 4'b0000;
            @(posedge clk);
            while (!i2c_ready) @(posedge clk);
            rdata = i2c_rdata;
            i2c_sel   <= 1'b0;
            i2c_valid <= 1'b0;
            @(posedge clk);
        end
    endtask

    reg [31:0] status_val;
    reg [31:0] read_val;
    reg [31:0] b0, b1, b2, b3;

    initial begin
        $display("==================================================================");
        $display("   STARTING I2C PERIPHERAL WITH SENSOR SLAVE MODEL TESTBENCH      ");
        $display("==================================================================");

        rst_n = 0;
        #25;
        rst_n = 1;
        #50;

        $display("\n--- Test 1: Single-Byte Write to Sensor Register 0x2D ---");
        // Set slave address = 7'h53, RWbar = 0 (write) -> {7'h53, 1'b0} = 0xA6
        i2c_bus_write(32'h4000_0004, 32'h0000_00A6);
        // Set internal register address = 0x2D
        i2c_bus_write(32'h4000_0008, 32'h0000_002D);
        // Set write data = 0x08
        i2c_bus_write(32'h4000_000C, 32'h0000_0008);
        // Start transaction (bit 0 = 1)
        i2c_bus_write(32'h4000_0000, 32'h0000_0001);

        // Wait until transaction finishes (busy == 0 and done == 1)
        #1000;
        i2c_bus_read(32'h4000_0000, status_val);
        while (status_val[1]) begin // wait while busy
            #1000;
            i2c_bus_read(32'h4000_0000, status_val);
        end

        if (status_val[0] === 1'b1 && status_val[2] === 1'b0)
            $display("  [PASS] Write transaction completed successfully (done=1, err=0)");
        else begin
            $display("  [FAIL] Write transaction failed: status = 0x%08h", status_val);
            errors = errors + 1;
        end

        if (slave_sensor.reg_mem[8'h2D] === 8'h08)
            $display("  [PASS] Sensor slave register 0x2D correctly updated with 0x08");
        else begin
            $display("  [FAIL] Sensor register 0x2D mismatch: expected 0x08, got 0x%02h", slave_sensor.reg_mem[8'h2D]);
            errors = errors + 1;
        end

        $display("\n--- Test 2: Single-Byte Read from Sensor Register 0x00 (DEVID) ---");
        // Slave address = 7'h53, RWbar = 1 (read) -> {7'h53, 1'b1} = 0xA7
        i2c_bus_write(32'h4000_0004, 32'h0000_00A7);
        // Register address = 0x00
        i2c_bus_write(32'h4000_0008, 32'h0000_0000);
        // Byte count = 1
        i2c_bus_write(32'h4000_0010, 32'h0000_0001);
        // Start transaction
        i2c_bus_write(32'h4000_0000, 32'h0000_0001);

        #1000;
        i2c_bus_read(32'h4000_0000, status_val);
        while (status_val[1]) begin
            #1000;
            i2c_bus_read(32'h4000_0000, status_val);
        end

        if (status_val[0] === 1'b1 && status_val[2] === 1'b0)
            $display("  [PASS] Read transaction completed successfully (done=1, err=0)");
        else begin
            $display("  [FAIL] Read transaction failed: status = 0x%08h", status_val);
            errors = errors + 1;
        end

        i2c_bus_read(32'h4000_0020, read_val);
        if (read_val[7:0] === 8'hE5)
            $display("  [PASS] Read DEVID byte matched: expected 0xE5, got 0x%02h", read_val[7:0]);
        else begin
            $display("  [FAIL] Read DEVID byte mismatch: expected 0xE5, got 0x%02h", read_val[7:0]);
            errors = errors + 1;
        end

        $display("\n--- Test 3: Multi-Byte Read (4 bytes starting from register 0x00) ---");
        i2c_bus_write(32'h4000_0004, 32'h0000_00A7);
        i2c_bus_write(32'h4000_0008, 32'h0000_0000);
        i2c_bus_write(32'h4000_0010, 32'h0000_0004); // 4 bytes
        i2c_bus_write(32'h4000_0000, 32'h0000_0001);

        #1000;
        i2c_bus_read(32'h4000_0000, status_val);
        while (status_val[1]) begin
            #1000;
            i2c_bus_read(32'h4000_0000, status_val);
        end

        i2c_bus_read(32'h4000_0020, b0);
        i2c_bus_read(32'h4000_0024, b1);
        i2c_bus_read(32'h4000_0028, b2);
        i2c_bus_read(32'h4000_002C, b3);

        if (b0[7:0] === 8'hE5 && b1[7:0] === 8'h12 && b2[7:0] === 8'h34 && b3[7:0] === 8'h56) begin
            $display("  [PASS] Multi-byte read matched: 0x%02h, 0x%02h, 0x%02h, 0x%02h", b0[7:0], b1[7:0], b2[7:0], b3[7:0]);
        end else begin
            $display("  [FAIL] Multi-byte read mismatch: got 0x%02h, 0x%02h, 0x%02h, 0x%02h", b0[7:0], b1[7:0], b2[7:0], b3[7:0]);
            errors = errors + 1;
        end

        $display("\n==================================================================");
        if (errors == 0) begin
            $display("   ALL I2C PERIPHERAL TESTS PASSED! (0 errors)                    ");
            $display("==================================================================");
        end else begin
            $display("   I2C TEST COMPLETED WITH %0d ERRORS!                            ", errors);
            $display("==================================================================");
        end

        $finish;
    end

endmodule

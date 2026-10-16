`timescale 1ns / 1ps

// ============================================================================
// tb_gpio.v -- Self-Checking Testbench for 32-bit GPIO Peripheral
// ============================================================================

module tb_gpio;

    reg clk = 0;
    always #5 clk = ~clk;

    reg rst_n = 0;

    reg         gpio_sel   = 0;
    reg         gpio_valid = 0;
    reg  [31:0] gpio_addr  = 0;
    reg  [31:0] gpio_wdata = 0;
    reg  [3:0]  gpio_wstrb = 0;
    wire        gpio_ready;
    wire [31:0] gpio_rdata;

    wire [15:0] led_out;
    reg  [15:0] gpio_in = 16'h1234;

    gpio_peripheral dut_gpio (
        .clk(clk),
        .rst_n(rst_n),
        .gpio_sel(gpio_sel),
        .gpio_valid(gpio_valid),
        .gpio_addr(gpio_addr),
        .gpio_wdata(gpio_wdata),
        .gpio_wstrb(gpio_wstrb),
        .gpio_ready(gpio_ready),
        .gpio_rdata(gpio_rdata),
        .led_out(led_out),
        .gpio_in(gpio_in)
    );

    integer errors = 0;

    task gpio_write;
        input [31:0] addr;
        input [31:0] wdata;
        input [3:0]  wstrb;
        begin
            @(posedge clk);
            gpio_sel   <= 1'b1;
            gpio_valid <= 1'b1;
            gpio_addr  <= addr;
            gpio_wdata <= wdata;
            gpio_wstrb <= wstrb;
            @(posedge clk);
            while (!gpio_ready) @(posedge clk);
            gpio_sel   <= 1'b0;
            gpio_valid <= 1'b0;
            gpio_wstrb <= 4'b0000;
            @(posedge clk);
        end
    endtask

    task gpio_check_read;
        input [31:0] addr;
        input [31:0] expected;
        input [255:0] name;
        begin
            @(posedge clk);
            gpio_sel   <= 1'b1;
            gpio_valid <= 1'b1;
            gpio_addr  <= addr;
            gpio_wstrb <= 4'b0000;
            @(posedge clk);
            while (!gpio_ready) @(posedge clk);
            if (gpio_rdata === expected) begin
                $display("  [PASS] %0s read: expected 0x%08h, got 0x%08h", name, expected, gpio_rdata);
            end else begin
                $display("  [FAIL] %0s read: expected 0x%08h, got 0x%08h", name, expected, gpio_rdata);
                errors = errors + 1;
            end
            gpio_sel   <= 1'b0;
            gpio_valid <= 1'b0;
            @(posedge clk);
        end
    endtask

    initial begin
        $display("==================================================================");
        $display("   STARTING GPIO PERIPHERAL UNIT TESTBENCH                        ");
        $display("==================================================================");

        rst_n = 0;
        #25;
        rst_n = 1;
        #20;

        $display("\n--- Testing Full 16-bit LED Write ---");
        gpio_write(32'h3000_0000, 32'h0000_A55A, 4'b0011);
        gpio_check_read(32'h3000_0000, 32'h0000_A55A, "LED Data Reg");
        if (led_out === 16'hA55A)
            $display("  [PASS] led_out pins matched 0xA55A");
        else begin
            $display("  [FAIL] led_out pins mismatch: expected 0xA55A, got 0x%04h", led_out);
            errors = errors + 1;
        end

        $display("\n--- Testing Partial Byte Strobe on LEDs ---");
        gpio_write(32'h3000_0000, 32'h0000_00FF, 4'b0001); // only byte 0 updated
        gpio_check_read(32'h3000_0000, 32'h0000_A5FF, "LED Byte0 Strobe");

        $display("\n--- Testing GPIO Input Pins Read ---");
        gpio_in = 16'h55AA;
        #20;
        gpio_check_read(32'h3000_0004, 32'h0000_55AA, "GPIO Input Reg");

        $display("\n==================================================================");
        if (errors == 0) begin
            $display("   ALL GPIO PERIPHERAL TESTS PASSED! (0 errors)                   ");
            $display("==================================================================");
        end else begin
            $display("   GPIO TEST COMPLETED WITH %0d ERRORS!                           ", errors);
            $display("==================================================================");
        end

        $finish;
    end

endmodule

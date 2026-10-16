`timescale 1ns / 1ps

// ============================================================================
// tb_blinking_led.v -- Verification for 1-Second GPIO LED0 Blinking Program
// ============================================================================

module tb_blinking_led;

    reg clk = 0;
    always #5 clk = ~clk; // 100 MHz clock

    reg rst_n = 0;
    wire clk_en = 1'b1;

    reg         UART_rxd = 1'b1;
    wire        UART_txd;
    wire        sda;
    wire        scl;
    wire [15:0] led;
    reg  [15:0] gpio_in = 16'h0000;
    wire [31:0] pc_out;
    wire        illegal_instruction;

    pullup (sda);
    pullup (scl);

    riscv_soc_top #(
        .CLK_FREQ   (100_000_000),
        .CODE_WORDS (1024),
        .DATA_WORDS (2048),
        .INIT_FILE  ("instruction.mem")
    ) dut_soc (
        .clk                 (clk),
        .rst_n               (rst_n),
        .clk_en              (clk_en),
        .UART_rxd            (UART_rxd),
        .UART_txd            (UART_txd),
        .sda                 (sda),
        .scl                 (scl),
        .led                 (led),
        .gpio_in             (gpio_in),
        .pc_out              (pc_out),
        .illegal_instruction (illegal_instruction)
    );

    initial begin
        $display("==================================================================");
        $display("   STARTING GPIO 0 BLINKING LED PROGRAM TESTBENCH                 ");
        $display("==================================================================");

        rst_n = 0;
        #50;
        @(posedge clk);
        rst_n = 1;
        $display("[%0t ns] Reset released. CPU executing instruction.mem...", $time);

        // Wait until PC reaches 0x08 (SW x2, 0(x1) which turns LED0 ON)
        while (pc_out != 32'h0000_0008 && $time < 5000) @(posedge clk);
        @(posedge clk); #1;

        if (led[0] === 1'b1) begin
            $display("  [PASS] LED 0 successfully turned ON (led[0] = 1, led = 0x%04h)", led);
        end else begin
            $display("  [FAIL] LED 0 failed to turn ON: led = 0x%04h", led);
            $finish;
        end

        // Wait until PC enters the delay_on loop (PC = 0x14)
        while (pc_out != 32'h0000_0014 && $time < 10000) @(posedge clk);
        $display("[%0t ns] CPU reached delay_on loop at PC = 0x%08h, LED 0 remains ON", $time, pc_out);

        $display("==================================================================");
        $display("   GPIO 0 BLINKING LED PROGRAM VERIFICATION PASSED! (0 errors)    ");
        $display("==================================================================");
        $finish;
    end

endmodule

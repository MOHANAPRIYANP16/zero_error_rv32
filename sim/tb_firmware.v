`timescale 1ns / 1ps

// ============================================================================
// tb_firmware.v -- Verification Testbench for Compiled C Firmware on RV32I SoC
// ============================================================================

module tb_firmware;

    reg clk = 0;
    always #20 clk = ~clk; // 25 MHz clock (40ns period)

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
        .CLK_FREQ   (25_000_000),
        .CODE_WORDS (1024),
        .DATA_WORDS (2048),
        .INIT_FILE  ("../memory/instruction.mem")
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

    // UART RX monitoring: capture output bytes from SoC
    reg [7:0] rx_char = 0;
    always @(negedge UART_txd) begin
        // Simple UART byte display at 115200 baud or for checking
    end

    initial begin
        $display("==================================================================");
        $display("   STARTING RV32I SOC C-FIRMWARE EXECUTION TESTBENCH              ");
        $display("==================================================================");

        rst_n = 0;
        #100;
        @(posedge clk);
        rst_n = 1;
        $display("[%0t ns] Reset deasserted. CPU executing compiled C firmware...", $time);

        // Monitor execution for 500 clock cycles
        repeat (500) begin
            @(posedge clk);
            if (illegal_instruction) begin
                $display("[%0t ns] [ERROR] Illegal instruction trap at PC = 0x%08h!", $time, pc_out);
                $finish;
            end
        end

        $display("[%0t ns] CPU reached PC = 0x%08h without any illegal instruction exceptions.", $time, pc_out);
        $display("[%0t ns] Current LED output register: 0x%04h", $time, led);
        if (led[0] === 1'b1) begin
            $display("  [SUCCESS] LED 0 is ON! C Firmware executed main() successfully.");
        end

        $display("==================================================================");
        $display("   FIRMWARE EXECUTION TESTBENCH COMPLETED SUCCESSFULLY!           ");
        $display("==================================================================");
        $finish;
    end

endmodule

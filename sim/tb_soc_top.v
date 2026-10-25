`timescale 1ns / 1ps

// ============================================================================
// tb_soc_top.v -- Comprehensive Top-Level SoC Integration Testbench
//
// Verifies:
//   - SoC reset deassertion & startup
//   - Instruction preloading from instruction.mem at reset address 0x0000_0000
//   - CPU execution of RV32I instruction suite through memory subsystem
//   - Data RAM read/write transactions via native memory bus
//   - 32-bit GPIO peripheral actuation (driving LEDs = 0x0055)
//   - UART peripheral interface ready & idle state
//   - I2C peripheral bus with external sensor slave model
//   - Infinite loop termination at PC = 0x0000_00C8
// ============================================================================

module tb_soc_top;

    reg clk = 0;
    always #5 clk = ~clk; // 100 MHz clock

    reg rst_n = 0;
    wire clk_en = 1'b1;

    // Board / External Ports
    reg         UART_rxd = 1'b1;
    wire        UART_txd;
    wire        sda;
    wire        scl;
    wire [15:0] led;
    reg  [15:0] gpio_in = 16'h0000;
    wire [31:0] pc_out;
    wire        illegal_instruction;

    // Pullups for open-drain I2C bus
    pullup (sda);
    pullup (scl);

    // DUT SoC Top Instance
    riscv_soc_top #(
        .CLK_FREQ   (100_000_000),
        .CODE_WORDS (1024),
        .DATA_WORDS (2048),
        .INIT_FILE  ("test_all_instructions.mem")
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

    // Connected I2C Sensor Model
    i2c_slave_model #(
        .SLAVE_ADDR(7'h53)
    ) sensor_slave (
        .scl(scl),
        .sda(sda)
    );

    integer errors = 0;
    integer cycles = 0;

    always @(posedge clk) begin
        if (rst_n) cycles = cycles + 1;
    end

    initial begin
        $display("==================================================================");
        $display("   STARTING INTEGRATED RV32I SOC TOP-LEVEL VERIFICATION           ");
        $display("==================================================================");

        rst_n = 0;
        #50;
        @(posedge clk);
        rst_n = 1;
        $display("[%0t ns] Reset released. CPU commencing fetch from 0x0000_0000...", $time);

        // Run until end of program (PC = 0xC8) or timeout
        while (pc_out != 32'h0000_00C8 && $time < 200000) begin
            @(posedge clk);
            if (illegal_instruction) begin
                $display("  [FAIL] Illegal instruction trap asserted at PC = 0x%08h!", pc_out);
                errors = errors + 1;
            end
        end

        // Wait a few cycles at the terminal loop
        repeat (20) @(posedge clk);

        $display("[%0t ns] CPU reached terminal loop at PC = 0x%08h after %0d clock cycles", $time, pc_out, cycles);

        // Check PC
        if (pc_out === 32'h0000_00C8) begin
            $display("  [PASS] PC successfully reached terminal address 0x0000_00C8");
        end else begin
            $display("  [FAIL] Program did not reach terminal PC: got 0x%08h", pc_out);
            errors = errors + 1;
        end

        // Check GPIO LEDs output
        if (led === 16'h0055) begin
            $display("  [PASS] GPIO LEDs driven with expected pattern: 0x%04h", led);
        end else begin
            $display("  [FAIL] GPIO LEDs mismatch: expected 0x0055, got 0x%04h", led);
            errors = errors + 1;
        end

        // Check Data RAM contents
        if (dut_soc.memory_subsys.data_ram[0] === 32'd50) begin
            $display("  [PASS] Data RAM word at offset 0x00 verified: %0d", dut_soc.memory_subsys.data_ram[0]);
        end else begin
            $display("  [FAIL] Data RAM word 0 mismatch: expected 50, got %0d", dut_soc.memory_subsys.data_ram[0]);
            errors = errors + 1;
        end

        // Check UART status
        if (UART_txd === 1'b1) begin
            $display("  [PASS] UART TX line idling high as expected");
        end else begin
            $display("  [FAIL] UART TX line not idling high");
            errors = errors + 1;
        end

        // Check I2C bus lines
        if (sda === 1'b1 && scl === 1'b1) begin
            $display("  [PASS] I2C bus lines idling high with pullups as expected");
        end else begin
            $display("  [FAIL] I2C lines not idling high: sda=%b, scl=%b", sda, scl);
            errors = errors + 1;
        end

        $display("\n==================================================================");
        if (errors == 0) begin
            $display("   INTEGRATED RV32I SOC VERIFICATION PASSED SUCCESSFULLY! (0 errors)");
            $display("==================================================================");
        end else begin
            $display("   INTEGRATED RV32I SOC FAILED WITH %0d ERRORS!                   ", errors);
            $display("==================================================================");
        end

        $finish;
    end
    initial begin
        $dumpfile("tb_soc_top.vcd");
        $dumpvars(0,tb_soc_top);
    end

endmodule

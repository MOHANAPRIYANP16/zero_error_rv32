`timescale 1ns / 1ps

// ============================================================================
// fpga_top.v -- Top-Level FPGA Module for Real Digital Boolean Board
//
// Target Device: Xilinx Spartan-7 XC7S50-CSGA324-1
// Clocking & Timing:
//   - On-board 100 MHz oscillator (pin F14)
//   - Hardware MMCM (MMCME2_BASE) generates dedicated, low-jitter 25.0 MHz
//     global clock (40.0 ns period) on BUFG network for 100% timing closure
//   - Reset button (active-high pin J2) synchronized to active-low rst_n
//     with MMCM lock qualification
// Pin mappings:
//   - UART: TX = U11, RX = V12
//   - I2C:  SCL = T5, SDA = T6
//   - LEDs: led[15:0] = {A4, B4, A3, B3, A2, B2, C3, E6, E5, E3, E2, E1, F2, F1, G2, G1}
// ============================================================================

module fpga_top (
    input  wire        clk,        // 100 MHz on-board oscillator, pin F14
    input  wire        btn_rst,    // Push-button reset, ACTIVE-HIGH, pin J2
    output wire [15:0] led,        // 16 on-board LEDs
    input  wire        UART_rxd,   // USB-UART RX (into FPGA, pin V12)
    output wire        UART_txd,   // USB-UART TX (out of FPGA, pin U11)
    inout  wire        i2c_scl,    // I2C SCL, pin T5
    inout  wire        i2c_sda     // I2C SDA, pin T6
);

    // ------------------------------------------------------------------------
    // Hardware MMCM: 100 MHz Input -> 25.0 MHz Dedicated Global SoC Clock
    // ------------------------------------------------------------------------
    wire clk_soc_unbuf;
    wire clk_soc;
    wire clkfb;
    wire mmcm_locked;

    MMCME2_BASE #(
        .BANDWIDTH          ("OPTIMIZED"),
        .CLKFBOUT_MULT_F    (10.0),       // 100 MHz * 10 = 1000 MHz VCO (valid: 600 - 1200 MHz)
        .CLKFBOUT_PHASE     (0.0),
        .CLKIN1_PERIOD      (10.000),     // 100 MHz input period
        .CLKOUT0_DIVIDE_F   (40.0),       // 1000 MHz / 40 = 25.0 MHz output (40.0 ns period)
        .CLKOUT0_DUTY_CYCLE (0.5),
        .CLKOUT0_PHASE      (0.0),
        .DIVCLK_DIVIDE      (1),
        .REF_JITTER1        (0.010),
        .STARTUP_WAIT       ("FALSE")
    ) mmcm_inst (
        .CLKOUT0            (clk_soc_unbuf),
        .CLKOUT0B           (),
        .CLKOUT1            (),
        .CLKOUT1B           (),
        .CLKOUT2            (),
        .CLKOUT2B           (),
        .CLKOUT3            (),
        .CLKOUT3B           (),
        .CLKOUT4            (),
        .CLKOUT5            (),
        .CLKOUT6            (),
        .CLKFBOUT           (clkfb),
        .CLKFBOUTB          (),
        .LOCKED             (mmcm_locked),
        .CLKIN1             (clk),
        .PWRDWN             (1'b0),
        .RST                (btn_rst),
        .CLKFBIN            (clkfb)
    );

    BUFG bufg_soc (
        .I(clk_soc_unbuf),
        .O(clk_soc)
    );

    // ------------------------------------------------------------------------
    // Reset Synchronizer: Qualified with MMCM Lock
    // ------------------------------------------------------------------------
    reg [2:0] rst_sync = 3'b000;
    always @(posedge clk_soc or posedge btn_rst) begin
        if (btn_rst)
            rst_sync <= 3'b000;
        else if (mmcm_locked)
            rst_sync <= {rst_sync[1:0], 1'b1};
    end
    wire rst_n = rst_sync[2];

    // ------------------------------------------------------------------------
    // SoC Instance (Operating at 25 MHz with 40.0 ns timing budget)
    // ------------------------------------------------------------------------
    wire [31:0] pc_debug;
    wire        illegal_instruction_debug;

    riscv_soc_top #(
        .CLK_FREQ   (25_000_000), // Peripheral baud/SCL references run at 25 MHz
        .CODE_WORDS (1024),
        .DATA_WORDS (2048),
        .INIT_FILE  ("instruction.mem")
    ) soc (
        .clk                 (clk_soc),
        .rst_n               (rst_n),
        .clk_en              (1'b1), // Continuous 25 MHz operation
        .UART_rxd            (UART_rxd),
        .UART_txd            (UART_txd),
        .sda                 (i2c_sda),
        .scl                 (i2c_scl),
        .led                 (led),
        .gpio_in             (16'h0000),
        .pc_out              (pc_debug),
        .illegal_instruction (illegal_instruction_debug)
    );

endmodule

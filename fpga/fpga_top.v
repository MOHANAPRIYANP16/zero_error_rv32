`timescale 1ns / 1ps

/*  fpga_top.v
    Target Device: Xilinx Spartan-7 XC7S50-CSGA324-1
    Clock & Reset:
    - On-board 100 MHz oscillator
    - Reset button (active-low rst_n) 
    Pin mappings:
    - UART0 (PC USB-UART): TX & RX
    - UART1 (Application uart): TX & RX
    - I2C:  SCL & SDA 
    - LEDs: led[15:0] total 16 leds
*/

module fpga_top (
    input  wire        clk,        
    input  wire        btn_rst,    
    output wire [15:0] led,        
    input  wire        UART_rxd,   
    output wire        UART_txd,   
    input  wire        UART1_rxd,  
    output wire        UART1_txd,  
    inout  wire        i2c_scl,    
    inout  wire        i2c_sda     
);

    
    // Hardware MMCM converts 100 MHz Input to 25.0 MHz enable
    wire clk_soc_unbuf;
    wire clk_soc;
    wire clkfb;
    wire mmcm_locked;

    MMCME2_BASE #(
        .BANDWIDTH          ("OPTIMIZED"),
        .CLKFBOUT_MULT_F    (10.0),       
        .CLKFBOUT_PHASE     (0.0),
        .CLKIN1_PERIOD      (10.000),     
        .CLKOUT0_DIVIDE_F   (40.0),       
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

    reg [2:0] rst_sync = 3'b000;
    always @(posedge clk_soc or posedge btn_rst) begin
        if (btn_rst)
            rst_sync <= 3'b000;
        else if (mmcm_locked)
            rst_sync <= {rst_sync[1:0], 1'b1};
    end
    wire rst_n = rst_sync[2];

    wire [31:0] pc_debug;
    wire        illegal_instruction_debug;

    riscv_soc_top #(
        .CLK_FREQ   (25_000_000), 
        .CODE_WORDS (4096),
        .DATA_WORDS (2048),
        .INIT_FILE  ("instruction.mem")
    ) soc (
        .clk                 (clk_soc),
        .rst_n               (rst_n),
        .clk_en              (1'b1), 
        .UART_rxd            (UART_rxd),
        .UART_txd            (UART_txd),
        .UART1_rxd           (UART1_rxd),
        .UART1_txd           (UART1_txd),
        .sda                 (i2c_sda),
        .scl                 (i2c_scl),
        .led                 (led),
        .gpio_in             (16'h0000),
        .pc_out              (pc_debug),
        .illegal_instruction (illegal_instruction_debug)
    );

endmodule

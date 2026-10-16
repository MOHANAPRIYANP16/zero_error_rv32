`timescale 1ns / 1ps

// ============================================================================
// gpio_peripheral.v -- 32-bit GPIO Peripheral
//
// Base Address: 0x3000_0000
// Registers:
//   Offset 0x00: GPIO_DATA_OUT [31:0]
//                - bits [15:0]  : drives 16 LEDs
//                - bits [31:16] : read as zero, write ignored
//   Offset 0x04: GPIO_DATA_IN  [31:0]
//                - bits [15:0]  : inputs from switches/buttons
//                - bits [31:16] : read as zero
//   Offset 0x08: GPIO_DIR      [31:0] (Reserved / Direction register)
// ============================================================================

module gpio_peripheral (
    input  wire        clk,
    input  wire        rst_n,

    // Native bus slave interface
    input  wire        gpio_sel,
    input  wire        gpio_valid,
    input  wire [31:0] gpio_addr,
    input  wire [31:0] gpio_wdata,
    input  wire [3:0]  gpio_wstrb,
    output reg         gpio_ready,
    output reg  [31:0] gpio_rdata,

    // External GPIO pins
    output wire [15:0] led_out,
    input  wire [15:0] gpio_in
);

    reg [15:0] led_reg;
    reg [15:0] dir_reg;

    assign led_out = led_reg;

    wire [3:0] reg_offset = gpio_addr[3:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gpio_ready <= 1'b0;
            gpio_rdata <= 32'd0;
            led_reg    <= 16'h0000;
            dir_reg    <= 16'h0000;
        end else begin
            gpio_ready <= 1'b0;
            if (gpio_sel && gpio_valid && !gpio_ready) begin
                gpio_ready <= 1'b1;

                // Register Read
                case (reg_offset)
                    4'h0:    gpio_rdata <= {16'h0000, led_reg};
                    4'h4:    gpio_rdata <= {16'h0000, gpio_in};
                    4'h8:    gpio_rdata <= {16'h0000, dir_reg};
                    default: gpio_rdata <= 32'd0;
                endcase

                // Register Write (supports byte write strobes)
                case (reg_offset)
                    4'h0: begin
                        if (gpio_wstrb[0]) led_reg[7:0]  <= gpio_wdata[7:0];
                        if (gpio_wstrb[1]) led_reg[15:8] <= gpio_wdata[15:8];
                    end
                    4'h8: begin
                        if (gpio_wstrb[0]) dir_reg[7:0]  <= gpio_wdata[7:0];
                        if (gpio_wstrb[1]) dir_reg[15:8] <= gpio_wdata[15:8];
                    end
                    default: begin end
                endcase
            end
        end
    end

endmodule

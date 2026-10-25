`timescale 1ns / 1ps

// ============================================================================
// soc_bus_interconnect.v -- Native PicoRV32-compatible Address Decoder & Bus Interconnect
//
// Complete Non-Overlapping Memory Map:
//   0x0000_0000 - 0x0000_0FFF : Code RAM (4 KB)   (Port B bus access)
//   0x1000_0000 - 0x1000_1FFF : Data RAM (8 KB)   (Scratchpad / Stack)
//   0x2000_0000 - 0x2000_00FF : UART0 Peripheral  (PC USB-UART Console / Bootloader)
//   0x3000_0000 - 0x3000_00FF : 32-bit GPIO       (LED output, Inputs, Dir)
//   0x4000_0000 - 0x4000_00FF : I2C Peripheral    (Ctrl, Slv, Reg, Wr, Cnt, Spd, Rd)
//   0x5000_0000 - 0x5000_00FF : UART1 Peripheral  (R307 Fingerprint Sensor on Pmod A)
//   Other addresses           : Unmapped (Default 1-cycle response with 0xDEADBEEF)
// ============================================================================

module soc_bus_interconnect (
    input  wire        clk,
    input  wire        rst_n,

    // Master port (CPU Core)
    input  wire        mem_valid,
    input  wire        mem_instr,
    input  wire [31:0] mem_addr,
    input  wire [31:0] mem_wdata,
    input  wire [3:0]  mem_wstrb,
    output wire        mem_ready,
    output wire [31:0] mem_rdata,

    // Slave 0: Code RAM Port B
    output wire        code_sel,
    output wire        code_valid,
    input  wire        code_ready,
    input  wire [31:0] code_rdata,

    // Slave 1: Data RAM
    output wire        data_sel,
    output wire        data_valid,
    input  wire        data_ready,
    input  wire [31:0] data_rdata,

    // Slave 2: UART0 (PC USB-UART Console)
    output wire        uart_sel,
    output wire        uart_valid,
    input  wire        uart_ready,
    input  wire [31:0] uart_rdata,

    // Slave 3: GPIO
    output wire        gpio_sel,
    output wire        gpio_valid,
    input  wire        gpio_ready,
    input  wire [31:0] gpio_rdata,

    // Slave 4: I2C
    output wire        i2c_sel,
    output wire        i2c_valid,
    input  wire        i2c_ready,
    input  wire [31:0] i2c_rdata,

    // Slave 5: UART1 (R307 Fingerprint Sensor)
    output wire        uart1_sel,
    output wire        uart1_valid,
    input  wire        uart1_ready,
    input  wire [31:0] uart1_rdata
);

    // Address range decoding based on top 4 bits
    assign code_sel  = (mem_addr[31:28] == 4'h0);
    assign data_sel  = (mem_addr[31:28] == 4'h1);
    assign uart_sel  = (mem_addr[31:28] == 4'h2);
    assign gpio_sel  = (mem_addr[31:28] == 4'h3);
    assign i2c_sel   = (mem_addr[31:28] == 4'h4);
    assign uart1_sel = (mem_addr[31:28] == 4'h5);

    wire unmapped_sel = mem_valid && !code_sel && !data_sel && !uart_sel && !gpio_sel && !i2c_sel && !uart1_sel;

    // Route valid signals to selected slave
    assign code_valid  = mem_valid && code_sel;
    assign data_valid  = mem_valid && data_sel;
    assign uart_valid  = mem_valid && uart_sel;
    assign gpio_valid  = mem_valid && gpio_sel;
    assign i2c_valid   = mem_valid && i2c_sel;
    assign uart1_valid = mem_valid && uart1_sel;

    // Unmapped address fallback handler (1-cycle termination to avoid hanging CPU)
    reg unmapped_ready;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            unmapped_ready <= 1'b0;
        end else begin
            unmapped_ready <= unmapped_sel && !unmapped_ready;
        end
    end

    // Multiplex ready and read data back to master
    assign mem_ready = code_sel     ? code_ready :
                       data_sel     ? data_ready :
                       uart_sel     ? uart_ready :
                       gpio_sel     ? gpio_ready :
                       i2c_sel      ? i2c_ready :
                       uart1_sel    ? uart1_ready :
                       unmapped_sel ? unmapped_ready :
                                      1'b0;

    assign mem_rdata = code_sel     ? code_rdata :
                       data_sel     ? data_rdata :
                       uart_sel     ? uart_rdata :
                       gpio_sel     ? gpio_rdata :
                       i2c_sel      ? i2c_rdata :
                       uart1_sel    ? uart1_rdata :
                                      32'hDEADBEEF;

endmodule

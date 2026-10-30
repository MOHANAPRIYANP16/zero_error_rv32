`timescale 1ns / 1ps

module riscv_soc_top #(
    parameter CLK_FREQ   = 100_000_000,
    parameter CODE_WORDS = 4096,
    parameter DATA_WORDS = 2048,
    parameter INIT_FILE  = "instruction.mem"
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        clk_en, 

    // UART0: PC USB to UART Bridge
    input  wire        UART_rxd,
    output wire        UART_txd,

    // UART1: external application
    input  wire        UART1_rxd,
    output wire        UART1_txd,

    // I2C
    inout  wire        sda,
    inout  wire        scl,

    // GPIO
    output wire [15:0] led,
    input  wire [15:0] gpio_in,
    output wire [31:0] pc_out,
    output wire        illegal_instruction
);

    wire [31:0] pc_wire;
    wire [31:0] instruction_wire;

    assign pc_out = pc_wire;
    wire        mem_valid;
    wire        mem_instr;
    wire        mem_ready;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_wstrb;
    wire [31:0] mem_rdata;

    wire        code_sel,  code_valid,  code_ready;
    wire [31:0] code_rdata;

    wire        data_sel,  data_valid,  data_ready;
    wire [31:0] data_rdata;

    wire        uart_sel,  uart_valid,  uart_ready;
    wire [31:0] uart_rdata;

    wire        gpio_sel,  gpio_valid,  gpio_ready;
    wire [31:0] gpio_rdata;

    wire        i2c_sel,   i2c_valid,   i2c_ready;
    wire [31:0] i2c_rdata;

    wire        uart1_sel, uart1_valid, uart1_ready;
    wire [31:0] uart1_rdata;

    risc_core cpu_core (
        .clk(clk),
        .rst_n(rst_n),
        .clk_en(clk_en),
        .instruction(instruction_wire),
        .pc_out(pc_wire),
        .mem_valid(mem_valid),
        .mem_instr(mem_instr),
        .mem_ready(mem_ready),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb),
        .mem_rdata(mem_rdata),
        .illegal_instruction(illegal_instruction)
    );

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
        .code_ready(code_ready),
        .code_rdata(code_rdata),

        .data_sel(data_sel),
        .data_valid(data_valid),
        .data_ready(data_ready),
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
        .i2c_ready(i2c_ready),
        .i2c_rdata(i2c_rdata),

        .uart1_sel(uart1_sel),
        .uart1_valid(uart1_valid),
        .uart1_ready(uart1_ready),
        .uart1_rdata(uart1_rdata)
    );

    ram_sync #(
        .CODE_WORDS(CODE_WORDS),
        .DATA_WORDS(DATA_WORDS),
        .INIT_FILE(INIT_FILE)
    ) memory_subsys (
        .clk(clk),
        .rst_n(rst_n),
        .pc_addr(pc_wire),
        .instruction(instruction_wire),

        .code_sel(code_sel),
        .code_valid(code_valid),
        .code_addr(mem_addr),
        .code_wdata(mem_wdata),
        .code_wstrb(mem_wstrb),
        .code_ready(code_ready),
        .code_rdata(code_rdata),

        .data_sel(data_sel),
        .data_valid(data_valid),
        .data_addr(mem_addr),
        .data_wdata(mem_wdata),
        .data_wstrb(mem_wstrb),
        .data_ready(data_ready),
        .data_rdata(data_rdata)
    );

    uart_peripheral #(
        .CLK_FREQ(CLK_FREQ)
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
        .UART_rxd(UART_rxd),
        .UART_txd(UART_txd)
    );


    uart_peripheral #(
        .CLK_FREQ(CLK_FREQ)
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
        .gpio_in(gpio_in)
    );

    i2c_peripheral #(
        .CLK_FREQ(CLK_FREQ)
    ) i2c_inst (
        .clk(clk),
        .rst_n(rst_n),
        .i2c_sel(i2c_sel),
        .i2c_valid(i2c_valid),
        .i2c_addr(mem_addr),
        .i2c_wdata(mem_wdata),
        .i2c_wstrb(mem_wstrb),
        .i2c_ready(i2c_ready),
        .i2c_rdata(i2c_rdata),
        .sda(sda),
        .scl(scl)
    );

endmodule

`timescale 1ns / 1ps

module soc_bus_interconnect (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        mem_valid,
    input  wire        mem_instr,
    input  wire [31:0] mem_addr,
    input  wire [31:0] mem_wdata,
    input  wire [3:0]  mem_wstrb,
    output wire        mem_ready,
    output wire [31:0] mem_rdata,

    output wire        code_sel,
    output wire        code_valid,
    input  wire        code_ready,
    input  wire [31:0] code_rdata,

    output wire        data_sel,
    output wire        data_valid,
    input  wire        data_ready,
    input  wire [31:0] data_rdata,

    output wire        uart_sel,
    output wire        uart_valid,
    input  wire        uart_ready,
    input  wire [31:0] uart_rdata,

    output wire        gpio_sel,
    output wire        gpio_valid,
    input  wire        gpio_ready,
    input  wire [31:0] gpio_rdata,

    output wire        i2c_sel,
    output wire        i2c_valid,
    input  wire        i2c_ready,
    input  wire [31:0] i2c_rdata,

    output wire        uart1_sel,
    output wire        uart1_valid,
    input  wire        uart1_ready,
    input  wire [31:0] uart1_rdata
);

    assign code_sel  = (mem_addr[31:28] == 4'h0);
    assign data_sel  = (mem_addr[31:28] == 4'h1);
    assign uart_sel  = (mem_addr[31:28] == 4'h2);
    assign gpio_sel  = (mem_addr[31:28] == 4'h3);
    assign i2c_sel   = (mem_addr[31:28] == 4'h4);
    assign uart1_sel = (mem_addr[31:28] == 4'h5);

    wire unmapped_sel = mem_valid && !code_sel && !data_sel && !uart_sel && !gpio_sel && !i2c_sel && !uart1_sel;

    assign code_valid  = mem_valid && code_sel;
    assign data_valid  = mem_valid && data_sel;
    assign uart_valid  = mem_valid && uart_sel;
    assign gpio_valid  = mem_valid && gpio_sel;
    assign i2c_valid   = mem_valid && i2c_sel;
    assign uart1_valid = mem_valid && uart1_sel;

    reg unmapped_ready;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            unmapped_ready <= 1'b0;
        end else begin
            unmapped_ready <= unmapped_sel && !unmapped_ready;
        end
    end
    
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

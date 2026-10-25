`timescale 1ns / 1ps

// ============================================================================
// ram_sync.v -- Dual-Port Code Memory and Byte-Addressable Data RAM
//
// Address ranges:
//   Code RAM: 0x0000_0000 - 0x0000_3FFF (4096 words = 16 KB)
//             Port A: Direct instruction fetch from PC (combinational/1-cycle read)
//             Port B: PicoRV32 native bus interface for data read/write
//             Preloaded via $readmemh("instruction.mem")
//
//   Data RAM: 0x1000_0000 - 0x1000_1FFF (2048 words = 8 KB)
//             PicoRV32 native bus interface with 4-bit byte write strobes
// ============================================================================

module ram_sync #(
    parameter CODE_WORDS  = 4096,
    parameter CODE_ADDR_W = 12,    // 2^12 = 4096 words = 16 KB
    parameter DATA_WORDS  = 2048,
    parameter DATA_ADDR_W = 11,    // 2^11 = 2048 words = 8 KB
    parameter INIT_FILE   = "instruction.mem"
)(
    input  wire        clk,
    input  wire        rst_n,

    // Instruction Fetch Port (Core PC)
    input  wire [31:0] pc_addr,
    output wire [31:0] instruction,

    // Native Bus Interface (Code RAM Slave)
    input  wire        code_sel,
    input  wire        code_valid,
    input  wire [31:0] code_addr,
    input  wire [31:0] code_wdata,
    input  wire [3:0]  code_wstrb,
    output reg         code_ready,
    output reg  [31:0] code_rdata,

    // Native Bus Interface (Data RAM Slave)
    input  wire        data_sel,
    input  wire        data_valid,
    input  wire [31:0] data_addr,
    input  wire [31:0] data_wdata,
    input  wire [3:0]  data_wstrb,
    output reg         data_ready,
    output reg  [31:0] data_rdata
);

    // ------------------------------------------------------------------------
    // Code Memory (16 KB)
    // ------------------------------------------------------------------------
    (* ram_style = "distributed" *) reg [31:0] code_mem [0:CODE_WORDS-1];
    integer i;

    initial begin
        for (i = 0; i < CODE_WORDS; i = i + 1)
            code_mem[i] = 32'h00000013; // NOP (addi x0, x0, 0)
        $readmemh(INIT_FILE, code_mem);
    end

    // Port A: Instruction fetch
    wire [CODE_ADDR_W-1:0] code_pc_word_addr = pc_addr[CODE_ADDR_W+1:2];
    assign instruction = (pc_addr[31:CODE_ADDR_W+2] == {(30-CODE_ADDR_W){1'b0}}) ?
                         code_mem[code_pc_word_addr] : 32'h00000013;

    // Port B: Bus access (1 wait-state synchronous response)
    wire [CODE_ADDR_W-1:0] code_bus_word_addr = code_addr[CODE_ADDR_W+1:2];

    // Synchronous memory write (no reset on storage array)
    always @(posedge clk) begin
        if (code_sel && code_valid && !code_ready) begin
            if (code_wstrb[0]) code_mem[code_bus_word_addr][7:0]   <= code_wdata[7:0];
            if (code_wstrb[1]) code_mem[code_bus_word_addr][15:8]  <= code_wdata[15:8];
            if (code_wstrb[2]) code_mem[code_bus_word_addr][23:16] <= code_wdata[23:16];
            if (code_wstrb[3]) code_mem[code_bus_word_addr][31:24] <= code_wdata[31:24];
        end
    end

    // Bus control and read data register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            code_ready <= 1'b0;
            code_rdata <= 32'd0;
        end else begin
            code_ready <= 1'b0;
            if (code_sel && code_valid && !code_ready) begin
                code_ready <= 1'b1;
                code_rdata <= code_mem[code_bus_word_addr];
            end
        end
    end

    // ------------------------------------------------------------------------
    // Data RAM (8 KB) -- Inferred as Xilinx True Block RAM (RAMB36)
    // ------------------------------------------------------------------------
    (* ram_style = "block" *) reg [31:0] data_ram [0:DATA_WORDS-1];
    integer j;

    initial begin
        for (j = 0; j < DATA_WORDS; j = j + 1)
            data_ram[j] = 32'd0;
    end

    wire [DATA_ADDR_W-1:0] data_bus_word_addr = data_addr[DATA_ADDR_W+1:2];

    // Synchronous memory write & read
    always @(posedge clk) begin
        if (data_sel && data_valid && !data_ready) begin
            if (data_wstrb[0]) data_ram[data_bus_word_addr][7:0]   <= data_wdata[7:0];
            if (data_wstrb[1]) data_ram[data_bus_word_addr][15:8]  <= data_wdata[15:8];
            if (data_wstrb[2]) data_ram[data_bus_word_addr][23:16] <= data_wdata[23:16];
            if (data_wstrb[3]) data_ram[data_bus_word_addr][31:24] <= data_wdata[31:24];
            data_rdata <= data_ram[data_bus_word_addr];
        end
    end

    // Bus control handshake
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_ready <= 1'b0;
        end else begin
            data_ready <= 1'b0;
            if (data_sel && data_valid && !data_ready) begin
                data_ready <= 1'b1;
            end
        end
    end

endmodule

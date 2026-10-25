`timescale 1ns / 1ps

// ============================================================================
// uart_fifo.v -- Parameterizable Synchronous First-Word Fall-Through (FWFT) FIFO
//
// Features:
//   - Zero-latency combinational read output (FWFT): dout is always valid when !empty
//   - Safe single-clock pop and push with simultaneous read/write support
//   - Full, empty, overflow flags, and current word counter
//   - Synthesizes efficiently into Xilinx Distributed LUTRAM on Spartan-7
// ============================================================================

module uart_fifo #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH      = 16,
    parameter ADDR_WIDTH = 4 // $clog2(DEPTH)
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  clear,

    // Write Interface (Push)
    input  wire                  wr_en,
    input  wire [DATA_WIDTH-1:0] din,
    output wire                  full,
    output reg                   overflow,

    // Read Interface (Pop)
    input  wire                  rd_en,
    output wire [DATA_WIDTH-1:0] dout,
    output wire                  empty,

    // Fill Level
    output reg  [ADDR_WIDTH:0]   count
);

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [ADDR_WIDTH-1:0] wr_ptr;
    reg [ADDR_WIDTH-1:0] rd_ptr;

    assign empty = (count == {(ADDR_WIDTH+1){1'b0}});
    assign full  = (count == DEPTH[ADDR_WIDTH:0]);

    // First-Word Fall-Through (FWFT): output is always the current read head
    assign dout  = mem[rd_ptr];

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr   <= {ADDR_WIDTH{1'b0}};
            rd_ptr   <= {ADDR_WIDTH{1'b0}};
            count    <= {(ADDR_WIDTH+1){1'b0}};
            overflow <= 1'b0;
            for (i = 0; i < DEPTH; i = i + 1)
                mem[i] <= {DATA_WIDTH{1'b0}};
        end else if (clear) begin
            wr_ptr   <= {ADDR_WIDTH{1'b0}};
            rd_ptr   <= {ADDR_WIDTH{1'b0}};
            count    <= {(ADDR_WIDTH+1){1'b0}};
            overflow <= 1'b0;
        end else begin
            case ({wr_en && !full, rd_en && !empty})
                2'b10: begin // Write only
                    mem[wr_ptr] <= din;
                    wr_ptr      <= wr_ptr + 1'b1;
                    count       <= count + 1'b1;
                end
                2'b01: begin // Read only
                    rd_ptr      <= rd_ptr + 1'b1;
                    count       <= count - 1'b1;
                end
                2'b11: begin // Simultaneous read and write
                    mem[wr_ptr] <= din;
                    wr_ptr      <= wr_ptr + 1'b1;
                    rd_ptr      <= rd_ptr + 1'b1;
                    count       <= count;
                end
                default: begin end
            endcase

            // Sticky overflow indicator when pushing to an already full FIFO
            if (wr_en && full && !rd_en) begin
                overflow <= 1'b1;
            end
        end
    end

endmodule

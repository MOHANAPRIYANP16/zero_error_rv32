`timescale 1ns / 1ps

module uart_fifo #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH      = 16,
    parameter ADDR_WIDTH = 4 
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  clear,

    input  wire                  wr_en,
    input  wire [DATA_WIDTH-1:0] din,
    output wire                  full,
    output reg                   overflow,

    input  wire                  rd_en,
    output wire [DATA_WIDTH-1:0] dout,
    output wire                  empty,

    output reg  [ADDR_WIDTH:0]   count
);

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [ADDR_WIDTH-1:0] wr_ptr;
    reg [ADDR_WIDTH-1:0] rd_ptr;

    assign empty = (count == {(ADDR_WIDTH+1){1'b0}});
    assign full  = (count == DEPTH[ADDR_WIDTH:0]);

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
                2'b10: begin 
                    mem[wr_ptr] <= din;
                    wr_ptr      <= wr_ptr + 1'b1;
                    count       <= count + 1'b1;
                end
                2'b01: begin 
                    rd_ptr      <= rd_ptr + 1'b1;
                    count       <= count - 1'b1;
                end
                2'b11: begin 
                    mem[wr_ptr] <= din;
                    wr_ptr      <= wr_ptr + 1'b1;
                    rd_ptr      <= rd_ptr + 1'b1;
                    count       <= count;
                end
                default: begin end
            endcase

           
            if (wr_en && full && !rd_en) begin
                overflow <= 1'b1;
            end
        end
    end

endmodule

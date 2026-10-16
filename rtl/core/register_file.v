`timescale 1ns / 1ps

module register_file (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        clk_en,
    input  wire        stall,
    input  wire [4:0]  Read_register_1,
    input  wire [4:0]  Read_register_2,
    input  wire [4:0]  write_register,
    input  wire [31:0] write_data,
    input  wire        reg_write,
    output wire [31:0] read_data_1,
    output wire [31:0] read_data_2
);

    reg [31:0] memory [0:31];
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 32; i = i + 1)
                memory[i] <= 32'd0;
        end else if (reg_write && (write_register != 5'd0) && clk_en && !stall) begin
            memory[write_register] <= write_data;
        end
    end

    // x0 is hardwired to 0
    assign read_data_1 = (Read_register_1 == 5'd0) ? 32'd0 : memory[Read_register_1];
    assign read_data_2 = (Read_register_2 == 5'd0) ? 32'd0 : memory[Read_register_2];

endmodule

`timescale 1ns / 1ps

module i2c_slave_model #(
    parameter SLAVE_ADDR = 7'h53
)(
    input  wire scl,
    inout  wire sda
);

    reg [7:0] reg_addr;
    reg [7:0] reg_mem [0:255];
    reg       sda_drive;
    assign sda = sda_drive ? 1'b0 : 1'bz;

    reg bus_ready;
    integer i;

    initial begin
        sda_drive = 1'b0;
        bus_ready = 1'b0;
        reg_addr  = 8'h00;
        for (i = 0; i < 256; i = i + 1)
            reg_mem[i] = 8'h00;

        reg_mem[8'h00] = 8'hE5; 
        reg_mem[8'h01] = 8'h12;
        reg_mem[8'h02] = 8'h34;
        reg_mem[8'h03] = 8'h56;
        reg_mem[8'h2D] = 8'h08; 
        reg_mem[8'h31] = 8'h0B; 
    end

    always @(posedge scl or posedge sda) begin
        if (scl === 1'b1 && sda === 1'b1)
            bus_ready <= 1'b1;
    end

    localparam ST_IDLE         = 4'd0,
               ST_ADDR         = 4'd1,
               ST_ADDR_ACK     = 4'd2,
               ST_WR_REG       = 4'd3,
               ST_WR_REG_ACK   = 4'd4,
               ST_WR_DATA      = 4'd5,
               ST_WR_DATA_ACK  = 4'd6,
               ST_RD_BYTE      = 4'd7,
               ST_RD_ACK       = 4'd8;

    reg [3:0] state;
    reg [2:0] bit_idx;
    reg [7:0] shift_in;
    reg [7:0] cur_read_byte;
    reg       is_read;
    reg       matched;
    reg       start_flag;
    reg       stop_flag;

    always @(negedge sda or negedge scl) begin
        if (!scl || !bus_ready)
            start_flag <= 1'b0;
        else
            start_flag <= 1'b1;
    end

    always @(posedge sda or negedge scl) begin
        if (!scl || !bus_ready)
            stop_flag <= 1'b0;
        else
            stop_flag <= 1'b1;
    end

    wire start_or_stop = start_flag | stop_flag;

    always @(posedge scl or posedge start_or_stop) begin
        if (start_or_stop) begin
            if (stop_flag) begin
                state   <= ST_IDLE;
                bit_idx <= 3'd7;
                matched <= 1'b0;
            end else if (start_flag) begin
                state    <= ST_ADDR;
                bit_idx  <= 3'd7;
                shift_in <= 8'h00;
                matched  <= 1'b0;
            end
        end else begin
            case (state)
                ST_ADDR: begin
                    shift_in <= {shift_in[6:0], sda};
                    if (bit_idx == 3'd0) begin
                        is_read <= sda;
                        matched <= ({shift_in[6:0], sda} >> 1) == SLAVE_ADDR;
                        state   <= ST_ADDR_ACK;
                    end else begin
                        bit_idx <= bit_idx - 1'b1;
                    end
                end

                ST_ADDR_ACK: begin
                    if (matched) begin
                        if (is_read) begin
                            cur_read_byte <= reg_mem[reg_addr];
                            state         <= ST_RD_BYTE;
                            bit_idx       <= 3'd7;
                        end else begin
                            state   <= ST_WR_REG;
                            bit_idx <= 3'd7;
                        end
                    end else begin
                        state <= ST_IDLE;
                    end
                end

                ST_WR_REG: begin
                    shift_in <= {shift_in[6:0], sda};
                    if (bit_idx == 3'd0) begin
                        reg_addr <= {shift_in[6:0], sda};
                        state    <= ST_WR_REG_ACK;
                    end else begin
                        bit_idx <= bit_idx - 1'b1;
                    end
                end

                ST_WR_REG_ACK: begin
                    bit_idx <= 3'd7;
                    state   <= ST_WR_DATA;
                end

                ST_WR_DATA: begin
                    shift_in <= {shift_in[6:0], sda};
                    if (bit_idx == 3'd0) begin
                        reg_mem[reg_addr] <= {shift_in[6:0], sda};
                        state             <= ST_WR_DATA_ACK;
                    end else begin
                        bit_idx <= bit_idx - 1'b1;
                    end
                end

                ST_WR_DATA_ACK: begin
                    state <= ST_IDLE;
                end

                ST_RD_BYTE: begin
                    if (bit_idx == 3'd0) begin
                        state <= ST_RD_ACK;
                    end else begin
                        bit_idx <= bit_idx - 1'b1;
                    end
                end

                ST_RD_ACK: begin
                    if (sda) begin
                        state <= ST_IDLE;
                    end else begin
                        reg_addr      <= reg_addr + 1'b1;
                        cur_read_byte <= reg_mem[reg_addr + 1'b1];
                        bit_idx       <= 3'd7;
                        state         <= ST_RD_BYTE;
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

    always @(negedge scl or posedge start_or_stop) begin
        if (start_or_stop) begin
            sda_drive <= 1'b0;
        end else begin
            case (state)
                ST_ADDR_ACK:    sda_drive <= matched;
                ST_WR_REG_ACK:  sda_drive <= matched;
                ST_WR_DATA_ACK: sda_drive <= matched;
                ST_RD_BYTE:     sda_drive <= !cur_read_byte[bit_idx];
                default:        sda_drive <= 1'b0;
            endcase
        end
    end

endmodule

`timescale 1ns / 1ps

// ============================================================================
// i2c_master.v -- Core I2C Master FSM supporting Write, Multi-Byte Read,
//                 and Repeated START
// ============================================================================

module i2c_master (
    input  wire       clk,
    input  wire       rst_n,

    // Command interface
    input  wire       start_cmd,
    input  wire [6:0] slv_addr,
    input  wire       rwbar,       // 0: Write, 1: Read
    input  wire [7:0] reg_addr,
    input  wire [7:0] wr_data,
    input  wire [2:0] byte_cnt,

    // Status interface
    output reg        busy,
    output reg        done,
    output reg        err,

    // Received data buffer
    output reg  [7:0] rd_data0,
    output reg  [7:0] rd_data1,
    output reg  [7:0] rd_data2,
    output reg  [7:0] rd_data3,

    // SCL Generator interface
    output reg        scl_trig,
    input  wire       phase_fall,
    input  wire       phase_low,
    input  wire       phase_rise,
    input  wire       phase_high,

    // SDA interface
    input  wire       sda_in,
    output reg        sda_oe
);

    localparam IDLE         = 5'd0,
               START1       = 5'd1,
               START2       = 5'd2,
               SLAVE_ADDR_W = 5'd3,
               WAIT_ACK1    = 5'd4,
               ACK1         = 5'd5,
               REG_ADDR     = 5'd6,
               WAIT_ACK2    = 5'd7,
               ACK2         = 5'd8,
               WRITEDATA    = 5'd9,
               WAIT_ACK3    = 5'd10,
               ACK3         = 5'd11,
               RESTART      = 5'd12,
               SLAVE_ADDR_R = 5'd13,
               WAIT_ACK4    = 5'd14,
               ACK4         = 5'd15,
               READDATA     = 5'd16,
               WAIT_ACK5    = 5'd17,
               ACK5         = 5'd18,
               STOP1        = 5'd19,
               STOP2        = 5'd20,
               ERROR        = 5'd21;

    reg [4:0] state;
    reg [2:0] bit_cnt;
    reg [7:0] shift_reg;
    reg [2:0] count;
    reg [7:0] read_buf [0:7];

    integer i;

    // Buffer outputs
    always @(*) begin
        rd_data0 = read_buf[0];
        rd_data1 = read_buf[1];
        rd_data2 = read_buf[2];
        rd_data3 = read_buf[3];
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sda_oe    <= 1'b0;
            scl_trig  <= 1'b0;
            state     <= IDLE;
            busy      <= 1'b0;
            done      <= 1'b0;
            err       <= 1'b0;
            shift_reg <= 8'd0;
            bit_cnt   <= 3'd0;
            count     <= 3'd0;
            for (i = 0; i < 8; i = i + 1)
                read_buf[i] <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    sda_oe   <= 1'b0;
                    scl_trig <= 1'b0;
                    if (start_cmd && !busy) begin
                        busy     <= 1'b1;
                        done     <= 1'b0;
                        err      <= 1'b0;
                        count    <= 3'd0;
                        state    <= START1;
                    end
                end

                START1: begin
                    sda_oe   <= 1'b0; // Release SDA
                    scl_trig <= 1'b1; // Start SCL clock generator
                    state    <= START2;
                end

                START2: begin
                    if (phase_high) begin
                        sda_oe    <= 1'b1; // Pull SDA low while SCL is high -> START
                        shift_reg <= {slv_addr, 1'b0}; // First phase is always write (address)
                        bit_cnt   <= 3'd7;
                        state     <= SLAVE_ADDR_W;
                    end
                end

                SLAVE_ADDR_W: begin
                    if (phase_low) begin
                        sda_oe <= ~shift_reg[7];
                    end else if (phase_rise) begin
                        shift_reg <= {shift_reg[6:0], 1'b0};
                        if (bit_cnt == 3'd0)
                            state <= WAIT_ACK1;
                        else
                            bit_cnt <= bit_cnt - 1'b1;
                    end
                end

                WAIT_ACK1: begin
                    if (phase_low) begin
                        sda_oe <= 1'b0; // Release SDA for slave ACK
                        state  <= ACK1;
                    end
                end

                ACK1: begin
                    if (phase_high) begin
                        if (sda_in) begin
                            state <= ERROR; // NACK received
                        end else begin
                            shift_reg <= reg_addr;
                            bit_cnt   <= 3'd7;
                            state     <= REG_ADDR;
                        end
                    end
                end

                REG_ADDR: begin
                    if (phase_low) begin
                        sda_oe <= ~shift_reg[7];
                        if (bit_cnt == 3'd0)
                            state <= WAIT_ACK2;
                        else
                            bit_cnt <= bit_cnt - 1'b1;
                    end else if (phase_rise) begin
                        shift_reg <= {shift_reg[6:0], 1'b0};
                    end
                end

                WAIT_ACK2: begin
                    if (phase_low) begin
                        sda_oe <= 1'b0;
                        state  <= ACK2;
                    end
                end

                ACK2: begin
                    if (phase_high) begin
                        if (sda_in) begin
                            state <= ERROR;
                        end else begin
                            if (rwbar) begin
                                state <= RESTART;
                            end else begin
                                bit_cnt   <= 3'd7;
                                shift_reg <= wr_data;
                                state     <= WRITEDATA;
                            end
                        end
                    end
                end

                WRITEDATA: begin
                    if (phase_low) begin
                        sda_oe <= ~shift_reg[7];
                        if (bit_cnt == 3'd0)
                            state <= WAIT_ACK3;
                        else
                            bit_cnt <= bit_cnt - 1'b1;
                    end else if (phase_rise) begin
                        shift_reg <= {shift_reg[6:0], 1'b0};
                    end
                end

                WAIT_ACK3: begin
                    if (phase_low) begin
                        sda_oe <= 1'b0;
                        state  <= ACK3;
                    end
                end

                ACK3: begin
                    if (phase_high) begin
                        state <= sda_in ? ERROR : STOP1;
                    end
                end

                RESTART: begin
                    if (phase_high) begin
                        sda_oe    <= 1'b1; // Repeated start
                        shift_reg <= {slv_addr, 1'b1}; // Read address
                        bit_cnt   <= 3'd7;
                        state     <= SLAVE_ADDR_R;
                    end
                end

                SLAVE_ADDR_R: begin
                    if (phase_low) begin
                        sda_oe <= ~shift_reg[7];
                        if (bit_cnt == 3'd0)
                            state <= WAIT_ACK4;
                        else
                            bit_cnt <= bit_cnt - 1'b1;
                    end else if (phase_rise) begin
                        shift_reg <= {shift_reg[6:0], 1'b0};
                    end
                end

                WAIT_ACK4: begin
                    if (phase_low) begin
                        sda_oe <= 1'b0;
                        state  <= ACK4;
                    end
                end

                ACK4: begin
                    if (phase_high) begin
                        if (sda_in) begin
                            state <= ERROR;
                        end else begin
                            bit_cnt <= 3'd7;
                            state   <= READDATA;
                        end
                    end
                end

                READDATA: begin
                    if (phase_high) begin
                        shift_reg <= {shift_reg[6:0], sda_in};
                        if (bit_cnt == 3'd0)
                            state <= WAIT_ACK5;
                        else
                            bit_cnt <= bit_cnt - 1'b1;
                    end
                    if (phase_fall && bit_cnt != 3'd0)
                        sda_oe <= 1'b0;
                end

                WAIT_ACK5: begin
                    if (phase_low) begin
                        // Master ACK if more bytes, NACK on last byte
                        if (count == (byte_cnt - 1'b1) || byte_cnt == 3'd0)
                            sda_oe <= 1'b0; // Master NACK
                        else
                            sda_oe <= 1'b1; // Master ACK
                        state <= ACK5;
                    end
                end

                ACK5: begin
                    if (phase_high) begin
                        read_buf[count] <= shift_reg;
                        if (count == (byte_cnt - 1'b1) || byte_cnt == 3'd0) begin
                            state <= STOP1;
                        end else begin
                            count     <= count + 1'b1;
                            bit_cnt   <= 3'd7;
                            shift_reg <= 8'd0;
                            state     <= READDATA;
                        end
                    end
                end

                STOP1: begin
                    if (phase_rise) begin
                        sda_oe <= 1'b1;
                    end else if (phase_high) begin
                        sda_oe <= 1'b0; // Release SDA while SCL is high -> STOP
                        state  <= STOP2;
                    end
                end

                STOP2: begin
                    if (phase_high) begin
                        busy     <= 1'b0;
                        done     <= 1'b1;
                        scl_trig <= 1'b0;
                        state    <= IDLE;
                    end
                end

                ERROR: begin
                    err      <= 1'b1;
                    sda_oe   <= 1'b0;
                    state    <= STOP1;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule

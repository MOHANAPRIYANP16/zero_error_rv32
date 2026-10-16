`timescale 1ns / 1ps

// ============================================================================
// i2c_peripheral.v -- I2C MMIO Peripheral with Native Bus Interface
//
// Base Address: 0x4000_0000
// Registers:
//   Offset 0x00: I2C_CTRL_STATUS [31:0]
//                - Write bit 0: start transaction
//                - Read : bit 0 = done, bit 1 = busy, bit 2 = err
//   Offset 0x04: I2C_SLV_ADDR    [31:0]
//                - bits [7:1] = 7-bit slave address
//                - bit  [0]   = RWbar (0 = write, 1 = read)
//   Offset 0x08: I2C_REG_ADDR    [31:0]
//                - bits [7:0] = internal sensor/device register address
//   Offset 0x0C: I2C_WR_DATA     [31:0]
//                - bits [7:0] = byte to write to the device
//   Offset 0x10: I2C_BYTE_CNT    [31:0]
//                - bits [2:0] = number of bytes to read (1 to 8)
//   Offset 0x14: I2C_CONFIG      [31:0]
//                - bit  [0]   = SCL speed: 0 = 400 kHz, 1 = 100 kHz
//   Offset 0x20: I2C_RD_DATA0    [31:0] (Read byte 0)
//   Offset 0x24: I2C_RD_DATA1    [31:0] (Read byte 1)
//   Offset 0x28: I2C_RD_DATA2    [31:0] (Read byte 2)
//   Offset 0x2C: I2C_RD_DATA3    [31:0] (Read byte 3)
// ============================================================================

module i2c_peripheral #(
    parameter CLK_FREQ = 100_000_000
)(
    input  wire        clk,
    input  wire        rst_n,

    // Native bus slave interface
    input  wire        i2c_sel,
    input  wire        i2c_valid,
    input  wire [31:0] i2c_addr,
    input  wire [31:0] i2c_wdata,
    input  wire [3:0]  i2c_wstrb,
    output reg         i2c_ready,
    output reg  [31:0] i2c_rdata,

    // External I2C bus pins
    inout  wire        sda,
    inout  wire        scl
);

    wire [5:0] reg_offset = i2c_addr[5:0];

    // MMIO Registers
    reg [6:0] slv_addr_reg;
    reg       rwbar_reg;
    reg [7:0] reg_addr_reg;
    reg [7:0] wr_data_reg;
    reg [2:0] byte_cnt_reg;
    reg       mode_100k_reg;
    reg       start_pulse;

    // FSM and SCL signals
    wire scl_trig, phase_fall, phase_low, phase_rise, phase_high;
    wire sda_oe, sda_in, scl_in, output_scl;
    wire busy, done, err;
    wire [7:0] rd_data0, rd_data1, rd_data2, rd_data3;

    // Open-drain bidirectional pins
    assign sda     = sda_oe ? 1'b0 : 1'bz;
    assign sda_in  = sda;
    assign scl     = output_scl;
    assign scl_in  = scl;

    // SCL Generator Instance
    scl_gen #(.CLK_FREQUENCY(CLK_FREQ)) scl_inst (
        .clk(clk),
        .rst_n(rst_n),
        .scl_fsm(scl_trig),
        .mode_100k(mode_100k_reg),
        .scl_in(scl_in),
        .output_scl(output_scl),
        .phase_fall(phase_fall),
        .phase_low(phase_low),
        .phase_rise(phase_rise),
        .phase_high(phase_high)
    );

    // I2C Master FSM Instance
    i2c_master i2c_master_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start_cmd(start_pulse),
        .slv_addr(slv_addr_reg),
        .rwbar(rwbar_reg),
        .reg_addr(reg_addr_reg),
        .wr_data(wr_data_reg),
        .byte_cnt(byte_cnt_reg),
        .busy(busy),
        .done(done),
        .err(err),
        .rd_data0(rd_data0),
        .rd_data1(rd_data1),
        .rd_data2(rd_data2),
        .rd_data3(rd_data3),
        .scl_trig(scl_trig),
        .phase_fall(phase_fall),
        .phase_low(phase_low),
        .phase_rise(phase_rise),
        .phase_high(phase_high),
        .sda_in(sda_in),
        .sda_oe(sda_oe)
    );

    // Bus read/write handler
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            i2c_ready     <= 1'b0;
            i2c_rdata     <= 32'd0;
            slv_addr_reg  <= 7'd0;
            rwbar_reg     <= 1'b0;
            reg_addr_reg  <= 8'd0;
            wr_data_reg   <= 8'd0;
            byte_cnt_reg  <= 3'd1;
            mode_100k_reg <= 1'b0; // Default 400 kHz
            start_pulse   <= 1'b0;
        end else begin
            i2c_ready   <= 1'b0;
            start_pulse <= 1'b0;

            if (i2c_sel && i2c_valid && !i2c_ready) begin
                i2c_ready <= 1'b1;

                // Read registers
                case (reg_offset)
                    6'h00:   i2c_rdata <= {29'd0, err, busy, done};
                    6'h04:   i2c_rdata <= {24'd0, slv_addr_reg, rwbar_reg};
                    6'h08:   i2c_rdata <= {24'd0, reg_addr_reg};
                    6'h0C:   i2c_rdata <= {24'd0, wr_data_reg};
                    6'h10:   i2c_rdata <= {29'd0, byte_cnt_reg};
                    6'h14:   i2c_rdata <= {31'd0, mode_100k_reg};
                    6'h20:   i2c_rdata <= {24'd0, rd_data0};
                    6'h24:   i2c_rdata <= {24'd0, rd_data1};
                    6'h28:   i2c_rdata <= {24'd0, rd_data2};
                    6'h2C:   i2c_rdata <= {24'd0, rd_data3};
                    default: i2c_rdata <= 32'd0;
                endcase

                // Write registers
                if (|i2c_wstrb) begin
                    case (reg_offset)
                        6'h00: begin
                            if (i2c_wdata[0] && !busy)
                                start_pulse <= 1'b1;
                        end
                        6'h04: begin
                            slv_addr_reg <= i2c_wdata[7:1];
                            rwbar_reg    <= i2c_wdata[0];
                        end
                        6'h08: begin
                            reg_addr_reg <= i2c_wdata[7:0];
                        end
                        6'h0C: begin
                            wr_data_reg <= i2c_wdata[7:0];
                        end
                        6'h10: begin
                            byte_cnt_reg <= i2c_wdata[2:0];
                        end
                        6'h14: begin
                            mode_100k_reg <= i2c_wdata[0];
                        end
                        default: begin end
                    endcase
                end
            end
        end
    end

endmodule

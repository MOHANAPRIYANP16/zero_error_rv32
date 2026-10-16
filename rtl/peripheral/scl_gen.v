`timescale 1ns / 1ps

// ============================================================================
// scl_gen.v -- Configurable I2C SCL and Phase Generator with Clock Stretching
//
// Supports:
//   - 400 kHz Fast Mode (mode_100k = 0)
//   - 100 kHz Standard Mode (mode_100k = 1)
//   - Clock stretching: if slave holds SCL low when master releases it,
//     wait until SCL line actually rises before entering phase_high.
// ============================================================================

module scl_gen #(
    parameter CLK_FREQUENCY = 100_000_000
)(
    input  wire  clk,
    input  wire  rst_n,
    input  wire  scl_fsm,      // Active when I2C transaction is running
    input  wire  mode_100k,    // 0: 400 kHz, 1: 100 kHz
    input  wire  scl_in,       // SCL line feedback for clock stretching
    output wire  output_scl,   // Driven low or High-Z
    output wire  phase_fall,
    output wire  phase_low,
    output wire  phase_rise,
    output wire  phase_high
);

    // Divisor per phase: (CLK_FREQUENCY / SCL_FREQUENCY) / 4
    // At 100 MHz:
    //   400 kHz: 100_000_000 / 400_000 / 4 = 62.5 -> 62 cycles
    //   100 kHz: 100_000_000 / 100_000 / 4 = 250 cycles
    wire [15:0] phase_divider = mode_100k ? (CLK_FREQUENCY / 400_000) : (CLK_FREQUENCY / 1_600_000);

    reg [1:0]  phase;
    reg [15:0] count;
    reg        scl_enable; // 1 = drive low, 0 = release high

    // Clock stretching detection: when master releases SCL (phase 3), wait if slave holds SCL low
    wire stretching = (!scl_enable && (scl_in === 1'b0));

    wire count_trigger = (count >= phase_divider - 1) && !stretching;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count      <= 16'd0;
            scl_enable <= 1'b0;
            phase      <= 2'd3; // High idle
        end else if (scl_fsm) begin
            if (stretching) begin
                // Hold count while slave is stretching the clock
                count <= count;
            end else if (count_trigger) begin
                count <= 16'd0;
                phase <= (phase == 2'd3) ? 2'd0 : (phase + 1'b1);
            end else begin
                count <= count + 1'b1;
            end

            // SCL line drive control
            if (phase == 2'd0 && count_trigger)
                scl_enable <= 1'b1; // Drive low on fall
            else if (phase == 2'd2 && count_trigger)
                scl_enable <= 1'b0; // Release high on rise
        end else begin
            scl_enable <= 1'b0;
            phase      <= 2'd3; // High idle
            count      <= 16'd0;
        end
    end

    assign phase_fall = (phase == 2'd0 && count_trigger);
    assign phase_low  = (phase == 2'd1 && count_trigger);
    assign phase_rise = (phase == 2'd2 && count_trigger);
    assign phase_high = (phase == 2'd3 && count_trigger);

    // Open-drain driver
    assign output_scl = scl_enable ? 1'b0 : 1'bz;

endmodule

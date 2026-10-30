`timescale 1ns / 1ps

module scl_gen #(
    parameter CLK_FREQUENCY = 100_000_000
)(
    input  wire  clk,
    input  wire  rst_n,
    input  wire  scl_fsm,      
    input  wire  mode_100k,    
    input  wire  scl_in,       
    output wire  output_scl,   
    output wire  phase_fall,
    output wire  phase_low,
    output wire  phase_rise,
    output wire  phase_high
);

    
    wire [15:0] phase_divider = mode_100k ? (CLK_FREQUENCY / 400_000) : (CLK_FREQUENCY / 1_600_000);

    reg [1:0]  phase;
    reg [15:0] count;
    reg        scl_enable; 

    
    wire stretching = (!scl_enable && (scl_in === 1'b0));

    wire count_trigger = (count >= phase_divider - 1) && !stretching;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count      <= 16'd0;
            scl_enable <= 1'b0;
            phase      <= 2'd3; 
        end else if (scl_fsm) begin
            if (stretching) begin
                count <= count;
            end else if (count_trigger) begin
                count <= 16'd0;
                phase <= (phase == 2'd3) ? 2'd0 : (phase + 1'b1);
            end else begin
                count <= count + 1'b1;
            end

            if (phase == 2'd0 && count_trigger)
                scl_enable <= 1'b1; 
            else if (phase == 2'd2 && count_trigger)
                scl_enable <= 1'b0; 
        end else begin
            scl_enable <= 1'b0;
            phase      <= 2'd3; 
            count      <= 16'd0;
        end
    end

    assign phase_fall = (phase == 2'd0 && count_trigger);
    assign phase_low  = (phase == 2'd1 && count_trigger);
    assign phase_rise = (phase == 2'd2 && count_trigger);
    assign phase_high = (phase == 2'd3 && count_trigger);

    assign output_scl = scl_enable ? 1'b0 : 1'bz;

endmodule

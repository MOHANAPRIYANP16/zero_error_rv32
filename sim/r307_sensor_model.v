`timescale 1ns / 1ps

module r307_sensor_model #(
    parameter BAUD_RATE = 57600
)(
    input  wire clk,
    input  wire rst_n,
    input  wire rx,       
    output reg  tx        
);

    localparam BIT_PERIOD = 1_000_000_000 / BAUD_RATE;

    initial tx = 1'b1;

    task send_byte(input [7:0] b);
        integer bit_idx;
        begin
            tx <= 1'b0; 
            #(BIT_PERIOD);
            for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                tx <= b[bit_idx];
                #(BIT_PERIOD);
            end
            tx <= 1'b1; 
            #(BIT_PERIOD);
        end
    endtask

    task send_ack_packet(input [7:0] ack_code, input [15:0] extra_len, input [127:0] extra_data);
        integer i;
        reg [15:0] total_len;
        reg [15:0] csum;
        reg [7:0]  extra_byte;
        begin
            total_len = 16'd3 + extra_len; 
            csum = 16'h0007 + total_len + ack_code; 

            send_byte(8'hEF);
            send_byte(8'h01);
            send_byte(8'hFF);
            send_byte(8'hFF);
            send_byte(8'hFF);
            send_byte(8'hFF);
            send_byte(8'h07);
            send_byte(total_len[15:8]);
            send_byte(total_len[7:0]);
            send_byte(ack_code);

            for (i = 0; i < extra_len; i = i + 1) begin
                extra_byte = extra_data >> ((extra_len - 1 - i) * 8);
                send_byte(extra_byte);
                csum = csum + extra_byte;
            end

            send_byte(csum[15:8]);
            send_byte(csum[7:0]);
        end
    endtask

    task receive_byte(output [7:0] b);
        integer bit_idx;
        begin
            @(negedge rx);
            #(BIT_PERIOD / 2); 
            #(BIT_PERIOD);
            for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                b[bit_idx] = rx;
                #(BIT_PERIOD);
            end
        end
    endtask

    reg [7:0] rx_b;
    reg [7:0] cmd_code;
    reg [15:0] pkg_len;
    integer k;

    always begin : model_loop
        receive_byte(rx_b);
        if (rx_b == 8'hEF) begin
            receive_byte(rx_b);
            if (rx_b == 8'h01) begin
             
                for (k = 0; k < 4; k = k + 1) receive_byte(rx_b);
               
                receive_byte(rx_b);
                receive_byte(rx_b);
                pkg_len[15:8] = rx_b;
                receive_byte(rx_b);
                pkg_len[7:0] = rx_b;
                receive_byte(cmd_code);
                for (k = 0; k < pkg_len - 1; k = k + 1) begin
                    receive_byte(rx_b);
                end

                #(BIT_PERIOD * 10); 

                case (cmd_code)
                    8'h13: begin 
                        send_ack_packet(8'h00, 16'd0, 128'd0);
                    end
                    8'h0F: begin 
                        send_ack_packet(8'h00, 16'd16, {16'h0000, 16'h0000, 16'd1000, 16'd3, 32'hFFFFFFFF, 16'd2, 16'd6});
                    end
                    8'h01: begin 
                        send_ack_packet(8'h00, 16'd0, 128'd0);
                    end
                    8'h02: begin 
                        send_ack_packet(8'h00, 16'd0, 128'd0);
                    end
                    8'h05: begin 
                        send_ack_packet(8'h00, 16'd0, 128'd0);
                    end
                    8'h06: begin 
                        send_ack_packet(8'h00, 16'd0, 128'd0);
                    end
                    8'h04: begin 
                        send_ack_packet(8'h00, 16'd4, {16'd5, 16'd120, 96'd0});
                    end
                    8'h0C: begin 
                        send_ack_packet(8'h00, 16'd0, 128'd0);
                    end
                    8'h0D: begin 
                        send_ack_packet(8'h00, 16'd0, 128'd0);
                    end
                    default: begin
                        send_ack_packet(8'h00, 16'd0, 128'd0);
                    end
                endcase
            end
        end
    end

endmodule

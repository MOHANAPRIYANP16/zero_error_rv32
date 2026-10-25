`timescale 1ns / 1ps

// ============================================================================
// r307_sensor_model.v -- Behavioral UART Simulation Model of R307 Fingerprint Sensor
//
// Emulates:
//   - Packet framing: Header (0xEF01), Addr (0xFFFFFFFF), PID (0x07 ACK), Checksum
//   - Verify Password (0x13) -> Returns ACK 0x00
//   - Read System Parameters (0x0F) -> Returns capacity = 1000, baud = 6 (57600)
//   - Get Image (0x01) -> Returns ACK 0x00
//   - Image to Template (0x02) -> Returns ACK 0x00
//   - Generate Model (0x05) -> Returns ACK 0x00
//   - Store Template (0x06) -> Returns ACK 0x00
//   - Search Template (0x04) -> Returns Matched ID = 5, Score = 120
//   - Empty Database (0x0D) -> Returns ACK 0x00
// ============================================================================

module r307_sensor_model #(
    parameter BAUD_RATE = 57600
)(
    input  wire clk,
    input  wire rst_n,
    input  wire rx,       // Connected to SoC UART1_txd
    output reg  tx        // Connected to SoC UART1_rxd
);

    localparam BIT_PERIOD = 1_000_000_000 / BAUD_RATE; // in ns

    initial tx = 1'b1;

    task send_byte(input [7:0] b);
        integer bit_idx;
        begin
            tx <= 1'b0; // Start bit
            #(BIT_PERIOD);
            for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                tx <= b[bit_idx];
                #(BIT_PERIOD);
            end
            tx <= 1'b1; // Stop bit
            #(BIT_PERIOD);
        end
    endtask

    task send_ack_packet(input [7:0] ack_code, input [15:0] extra_len, input [127:0] extra_data);
        integer i;
        reg [15:0] total_len;
        reg [15:0] csum;
        reg [7:0]  extra_byte;
        begin
            total_len = 16'd3 + extra_len; // 1 (PID) + 2 (len) + 1 (ack_code) + extra_len + 2 (csum) -> pkg len = 1+extra_len+2 = 3+extra_len
            csum = 16'h0007 + total_len + ack_code; // PID(0x07) + len + ack

            // Header & Address
            send_byte(8'hEF);
            send_byte(8'h01);
            send_byte(8'hFF);
            send_byte(8'hFF);
            send_byte(8'hFF);
            send_byte(8'hFF);

            // PID = 0x07 (ACK)
            send_byte(8'h07);

            // Package length
            send_byte(total_len[15:8]);
            send_byte(total_len[7:0]);

            // ACK Confirmation Code
            send_byte(ack_code);

            // Extra data (if any)
            for (i = 0; i < extra_len; i = i + 1) begin
                extra_byte = extra_data >> ((extra_len - 1 - i) * 8);
                send_byte(extra_byte);
                csum = csum + extra_byte;
            end

            // Checksum
            send_byte(csum[15:8]);
            send_byte(csum[7:0]);
        end
    endtask

    // UART RX Byte receiver task
    task receive_byte(output [7:0] b);
        integer bit_idx;
        begin
            @(negedge rx);
            #(BIT_PERIOD / 2); // Sample at mid-bit
            #(BIT_PERIOD);
            for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                b[bit_idx] = rx;
                #(BIT_PERIOD);
            end
        end
    endtask

    // Main packet parser loop
    reg [7:0] rx_b;
    reg [7:0] cmd_code;
    reg [15:0] pkg_len;
    integer k;

    always begin : model_loop
        // Look for 0xEF
        receive_byte(rx_b);
        if (rx_b == 8'hEF) begin
            receive_byte(rx_b);
            if (rx_b == 8'h01) begin
                // Read 4 address bytes
                for (k = 0; k < 4; k = k + 1) receive_byte(rx_b);
                // Read PID (0x01 command)
                receive_byte(rx_b);
                // Read Package length
                receive_byte(rx_b);
                pkg_len[15:8] = rx_b;
                receive_byte(rx_b);
                pkg_len[7:0] = rx_b;

                // Read Command Code
                receive_byte(cmd_code);

                // Discard remaining parameters and checksum
                for (k = 0; k < pkg_len - 1; k = k + 1) begin
                    receive_byte(rx_b);
                end

                // Formulate response
                #(BIT_PERIOD * 10); // Simulated sensor latency

                case (cmd_code)
                    8'h13: begin // Verify password
                        send_ack_packet(8'h00, 16'd0, 128'd0);
                    end
                    8'h0F: begin // Read system params: status(2B)=0, model(2B)=0, capacity(2B)=1000, sec_level(2B)=3, addr(4B)=0xFFFFFFFF, pkg_sz(2B)=2, baud_mult(2B)=6
                        send_ack_packet(8'h00, 16'd16, {16'h0000, 16'h0000, 16'd1000, 16'd3, 32'hFFFFFFFF, 16'd2, 16'd6});
                    end
                    8'h01: begin // Get Image
                        send_ack_packet(8'h00, 16'd0, 128'd0);
                    end
                    8'h02: begin // GenChar / ImageToTZ
                        send_ack_packet(8'h00, 16'd0, 128'd0);
                    end
                    8'h05: begin // RegModel
                        send_ack_packet(8'h00, 16'd0, 128'd0);
                    end
                    8'h06: begin // Store template
                        send_ack_packet(8'h00, 16'd0, 128'd0);
                    end
                    8'h04: begin // Search: matched_id = 5, score = 120
                        send_ack_packet(8'h00, 16'd4, {16'd5, 16'd120, 96'd0});
                    end
                    8'h0C: begin // Delete template
                        send_ack_packet(8'h00, 16'd0, 128'd0);
                    end
                    8'h0D: begin // Empty database
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

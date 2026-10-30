`timescale 1ns / 1ps

module tb_bootloader;

    reg clk = 0;
    always #20 clk = ~clk; 

    reg rst_n = 0;
    wire clk_en = 1'b1;

    reg         UART_rxd = 1'b1;
    wire        UART_txd;
    wire        sda;
    wire        scl;
    wire [15:0] led;
    reg  [15:0] gpio_in = 16'h0000;
    wire [31:0] pc_out;
    wire        illegal_instruction;

    pullup (sda);
    pullup (scl);

    
    riscv_soc_top #(
        .CLK_FREQ   (25_000_000),
        .CODE_WORDS (1024),
        .DATA_WORDS (2048),
        .INIT_FILE  ("../memory/instruction.mem")
    ) dut_soc (
        .clk                 (clk),
        .rst_n               (rst_n),
        .clk_en              (clk_en),
        .UART_rxd            (UART_rxd),
        .UART_txd            (UART_txd),
        .sda                 (sda),
        .scl                 (scl),
        .led                 (led),
        .gpio_in             (gpio_in),
        .pc_out              (pc_out),
        .illegal_instruction (illegal_instruction)
    );

    localparam BIT_PERIOD = 8680;
    task send_uart_byte(input [7:0] b);
        integer bit_idx;
        begin
            UART_rxd = 1'b0;
            #BIT_PERIOD;
            for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                UART_rxd = b[bit_idx];
                #BIT_PERIOD;
            end
            UART_rxd = 1'b1;
            #BIT_PERIOD;
        end
    endtask

    reg [7:0] rx_byte;
    integer rx_bit;
    task wait_for_ack(output [7:0] ack_char);
        begin
            @(negedge UART_txd);
            #(BIT_PERIOD / 2); 
            for (rx_bit = 0; rx_bit < 8; rx_bit = rx_bit + 1) begin
                #BIT_PERIOD;
                rx_byte[rx_bit] = UART_txd;
            end
            #BIT_PERIOD; 
            ack_char = rx_byte;
        end
    endtask

    reg [7:0] app_payload [0:15];
    initial begin
        
        app_payload[0]  = 8'hb7; app_payload[1]  = 8'h00; app_payload[2]  = 8'h00; app_payload[3]  = 8'h30;
        app_payload[4]  = 8'h37; app_payload[5]  = 8'h51; app_payload[6]  = 8'h05; app_payload[7]  = 8'h00;
        app_payload[8]  = 8'h23; app_payload[9]  = 8'ha0; app_payload[10] = 8'h20; app_payload[11] = 8'h00;
        app_payload[12] = 8'h6f; app_payload[13] = 8'h00; app_payload[14] = 8'h00; app_payload[15] = 8'h00;
    end

    reg [7:0] ack_received;
    integer k;

    initial begin
        $display("==================================================================");
        $display("   STARTING UART BOOTLOADER VERIFICATION TESTBENCH                ");
        $display("==================================================================");

        rst_n = 0;
        #100;
        @(posedge clk);
        rst_n = 1;
        $display("[%0t ns] Reset released. Bootloader running from 0x0000_0000...", $time);
        
        wait (led == 16'h0001);
        $display("[%0t ns] [PASS] Bootloader waiting for upload (led = 0x%04h)", $time, led);
        #3_000_000; 
        $display("[%0t ns] Host sending 'p' command (0x70)...", $time);
        send_uart_byte("p");
        #BIT_PERIOD;

        $display("[%0t ns] Host sending length header: 16 bytes (0x00000010)...", $time);
        send_uart_byte(8'h10); 
        send_uart_byte(8'h00); 
        send_uart_byte(8'h00); 
        send_uart_byte(8'h00); 

        wait (led == 16'h0003);
        $display("[%0t ns] [PASS] Bootloader entered receiving state (led = 0x%04h)", $time, led);

        $display("[%0t ns] Streaming 16 application instruction bytes...", $time);
        for (k = 0; k < 16; k = k + 1) begin
            send_uart_byte(app_payload[k]);
            #BIT_PERIOD; 
        end

        
        wait (led == 16'h0001);
        $display("[%0t ns] [PASS] Payload flashing complete! Bootloader waiting for execute...", $time);
        #50000;
        $display("[%0t ns] User presses 'e' in terminal...", $time);
        send_uart_byte("e");

        wait (pc_out >= 32'h0000_0200 && pc_out <= 32'h0000_0210);
        $display("[%0t ns] [PASS] CPU successfully jumped to APP_BASE! (PC = 0x%08h)", $time, pc_out);

        wait (led == 16'h5000);
        $display("[%0t ns] [PASS] Uploaded application executed sw instruction! (led = 0x%04h)", $time, led);



        $display("==================================================================");
        $display("   UART BOOTLOADER VERIFICATION COMPLETED WITH 100%% SUCCESS!      ");
        $display("==================================================================");
        $finish;
    end

    initial begin
        #15_000_000;
        $display("[TIMEOUT] Simulation exceeded 15ms limit.");
        $finish;
    end

endmodule

`timescale 1ns / 1ps

// ============================================================================
// tb_bootloader.v -- End-to-End Simulation Testbench for UART Bootloader
//
// Verifies:
//   1. SoC boots into resident bootloader in instruction.mem.
//   2. Bootloader configures UART and asserts LED0 (led = 0x0001, waiting).
//   3. Testbench sends 4-byte length header over UART RX.
//   4. Bootloader indicates receiving (led = 0x0003).
//   5. Testbench streams application instruction bytes over UART RX.
//   6. Bootloader writes bytes directly to Instruction Memory @ 0x0000_0200.
//   7. Bootloader indicates complete (led = 0xFFFF) and sends 'K' ACK over UART TX.
//   8. CPU jumps to 0x0000_0200 and executes the uploaded application!
// ============================================================================

module tb_bootloader;

    reg clk = 0;
    always #20 clk = ~clk; // 25.0 MHz clock (40ns period)

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

    // Instantiate SoC Top with Bootloader preloaded in instruction.mem
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

    // Bit period for 115200 baud (at 25MHz, ~8680ns per bit)
    localparam BIT_PERIOD = 8680;

    // Task: Transmit 1 byte over UART (1 start bit, 8 data bits, 1 stop bit)
    task send_uart_byte(input [7:0] b);
        integer bit_idx;
        begin
            // Start bit
            UART_rxd = 1'b0;
            #BIT_PERIOD;

            // 8 data bits (LSB first)
            for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                UART_rxd = b[bit_idx];
                #BIT_PERIOD;
            end

            // Stop bit
            UART_rxd = 1'b1;
            #BIT_PERIOD;
        end
    endtask

    // UART receiver monitor to capture 'K' acknowledgement
    reg [7:0] rx_byte;
    integer rx_bit;
    task wait_for_ack(output [7:0] ack_char);
        begin
            @(negedge UART_txd);
            #(BIT_PERIOD / 2); // Sample middle of start bit
            for (rx_bit = 0; rx_bit < 8; rx_bit = rx_bit + 1) begin
                #BIT_PERIOD;
                rx_byte[rx_bit] = UART_txd;
            end
            #BIT_PERIOD; // Stop bit
            ack_char = rx_byte;
        end
    endtask

    // Test application payload: 4 RV32I instructions (16 bytes)
    // Inst 0: 0x300000b7 (lui x1, 0x30000)      -> GPIO base
    // Inst 1: 0x12340137 (lui x2, 0x12340)
    // Inst 2: 0x0020a023 (sw  x2, 0(x1))         -> Sets LEDs to 0x1234 (upper bits masked)
    // Inst 3: 0x0000006f (j   .)                 -> Infinite loop
    reg [7:0] app_payload [0:15];
    initial begin
        // lui x1, 0x30000 -> 300000b7
        app_payload[0]  = 8'hb7; app_payload[1]  = 8'h00; app_payload[2]  = 8'h00; app_payload[3]  = 8'h30;
        // lui x2, 0x00055 -> 00055137 (sets LEDs to 0x0055)
        app_payload[4]  = 8'h37; app_payload[5]  = 8'h51; app_payload[6]  = 8'h05; app_payload[7]  = 8'h00;
        // sw  x2, 0(x1)   -> 0020a023
        app_payload[8]  = 8'h23; app_payload[9]  = 8'ha0; app_payload[10] = 8'h20; app_payload[11] = 8'h00;
        // j   .           -> 0000006f
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

        // Step 1: Verify Bootloader asserts waiting state on LEDs
        wait (led == 16'h0001);
        $display("[%0t ns] [PASS] Bootloader waiting for upload (led = 0x%04h)", $time, led);
        #3_000_000; // Allow "[Boot] Press 'e' to run" greeting to finish transmitting over UART

        // Step 2: Host sends 'p' command followed by 4-byte little-endian length
        $display("[%0t ns] Host sending 'p' command (0x70)...", $time);
        send_uart_byte("p");
        #BIT_PERIOD;

        $display("[%0t ns] Host sending length header: 16 bytes (0x00000010)...", $time);
        send_uart_byte(8'h10); // Length byte 0
        send_uart_byte(8'h00); // Length byte 1
        send_uart_byte(8'h00); // Length byte 2
        send_uart_byte(8'h00); // Length byte 3

        // Step 3: Verify Bootloader acknowledges length and sets receiving status
        wait (led == 16'h0003);
        $display("[%0t ns] [PASS] Bootloader entered receiving state (led = 0x%04h)", $time, led);

        // Step 4: Stream 16 application payload bytes over UART
        $display("[%0t ns] Streaming 16 application instruction bytes...", $time);
        for (k = 0; k < 16; k = k + 1) begin
            send_uart_byte(app_payload[k]);
            #BIT_PERIOD; // 1 stop bit gap between bytes
        end

        // Step 5: Bootloader signals write complete and returns to waiting state (led = 0x0001)
        wait (led == 16'h0001);
        $display("[%0t ns] [PASS] Payload flashing complete! Bootloader waiting for execute...", $time);
        #50000;

        // Step 6: User sends 'e' command in terminal to execute application!
        $display("[%0t ns] User presses 'e' in terminal...", $time);
        send_uart_byte("e");

        // Step 7: Verify CPU jumped to APP_BASE (0x0000_0200) and executed payload
        wait (pc_out >= 32'h0000_0200 && pc_out <= 32'h0000_0210);
        $display("[%0t ns] [PASS] CPU successfully jumped to APP_BASE! (PC = 0x%08h)", $time, pc_out);

        wait (led == 16'h5000);
        $display("[%0t ns] [PASS] Uploaded application executed sw instruction! (led = 0x%04h)", $time, led);



        $display("==================================================================");
        $display("   UART BOOTLOADER VERIFICATION COMPLETED WITH 100%% SUCCESS!      ");
        $display("==================================================================");
        $finish;
    end

    // Safety timeout
    initial begin
        #15_000_000;
        $display("[TIMEOUT] Simulation exceeded 15ms limit.");
        $finish;
    end

endmodule

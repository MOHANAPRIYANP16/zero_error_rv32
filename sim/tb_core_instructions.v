`timescale 1ns / 1ps

module tb_core_instructions;

    reg clk = 0;
    always #5 clk = ~clk; 

    reg rst_n = 0;
    wire clk_en = 1'b1;
    wire [31:0] pc_wire;
    wire [31:0] instruction_wire;
    wire        mem_valid;
    wire        mem_instr;
    wire        mem_ready;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_wstrb;
    wire [31:0] mem_rdata;
    wire        illegal_instruction;

    wire        code_sel, code_valid, code_ready;
    wire [31:0] code_rdata;
    wire        data_sel, data_valid, data_ready;
    wire [31:0] data_rdata;
    wire        uart_sel, uart_valid, uart_ready;
    wire [31:0] uart_rdata;
    wire        gpio_sel, gpio_valid, gpio_ready;
    wire [31:0] gpio_rdata;
    wire        i2c_sel,  i2c_valid,  i2c_ready;
    wire [31:0] i2c_rdata;

    risc_core dut_core (
        .clk(clk),
        .rst_n(rst_n),
        .clk_en(clk_en),
        .instruction(instruction_wire),
        .pc_out(pc_wire),
        .mem_valid(mem_valid),
        .mem_instr(mem_instr),
        .mem_ready(mem_ready),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb),
        .mem_rdata(mem_rdata),
        .illegal_instruction(illegal_instruction)
    );

    soc_bus_interconnect bus_mux (
        .clk(clk),
        .rst_n(rst_n),
        .mem_valid(mem_valid),
        .mem_instr(mem_instr),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb),
        .mem_ready(mem_ready),
        .mem_rdata(mem_rdata),

        .code_sel(code_sel),
        .code_valid(code_valid),
        .code_ready(code_ready),
        .code_rdata(code_rdata),

        .data_sel(data_sel),
        .data_valid(data_valid),
        .data_ready(data_ready),
        .data_rdata(data_rdata),

        .uart_sel(uart_sel),
        .uart_valid(uart_valid),
        .uart_ready(uart_ready),
        .uart_rdata(uart_rdata),

        .gpio_sel(gpio_sel),
        .gpio_valid(gpio_valid),
        .gpio_ready(gpio_ready),
        .gpio_rdata(gpio_rdata),

        .i2c_sel(i2c_sel),
        .i2c_valid(i2c_valid),
        .i2c_ready(i2c_ready),
        .i2c_rdata(i2c_rdata)
    );

    ram_sync #(
        .CODE_WORDS(1024),
        .DATA_WORDS(2048),
        .INIT_FILE("test_all_instructions.mem")
    ) memory_subsys (
        .clk(clk),
        .rst_n(rst_n),
        .pc_addr(pc_wire),
        .instruction(instruction_wire),

        .code_sel(code_sel),
        .code_valid(code_valid),
        .code_addr(mem_addr),
        .code_wdata(mem_wdata),
        .code_wstrb(mem_wstrb),
        .code_ready(code_ready),
        .code_rdata(code_rdata),

        .data_sel(data_sel),
        .data_valid(data_valid),
        .data_addr(mem_addr),
        .data_wdata(mem_wdata),
        .data_wstrb(mem_wstrb),
        .data_ready(data_ready),
        .data_rdata(data_rdata)
    );

    wire [15:0] led_out;
    gpio_peripheral gpio_inst (
        .clk(clk),
        .rst_n(rst_n),
        .gpio_sel(gpio_sel),
        .gpio_valid(gpio_valid),
        .gpio_addr(mem_addr),
        .gpio_wdata(mem_wdata),
        .gpio_wstrb(mem_wstrb),
        .gpio_ready(gpio_ready),
        .gpio_rdata(gpio_rdata),
        .led_out(led_out),
        .gpio_in(16'h0000)
    );

    assign uart_ready = 1'b1;
    assign uart_rdata = 32'd0;
    assign i2c_ready  = 1'b1;
    assign i2c_rdata  = 32'd0;

    integer errors = 0;

    task check_reg;
        input [4:0]  reg_num;
        input [31:0] expected;
        input [255:0] test_name;
        reg [31:0] actual;
        begin
            actual = dut_core.rf_block.memory[reg_num];
            if (actual === expected) begin
                $display("  [PASS] %0s (x%0d): expected 0x%08h, got 0x%08h", test_name, reg_num, expected, actual);
            end else begin
                $display("  [FAIL] %0s (x%0d): expected 0x%08h, got 0x%08h", test_name, reg_num, expected, actual);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        $display("==================================================================");
        $display("   STARTING RV32I CORE INSTRUCTION SET VERIFICATION TESTBENCH     ");
        $display("==================================================================");

        rst_n = 0;
        #25;
        rst_n = 1;

        while (pc_wire != 32'h0000_00C8 && $time < 100000) begin
            @(posedge clk);
        end
        
        repeat (10) @(posedge clk);

        $display("Program execution reached PC = 0x%08h at time %0t ns", pc_wire, $time);

        $display("\n--- Checking Group G: Upper Immediate Instructions ---");
        check_reg(2, 32'h12345000, "LUI   x2, 0x12345");
        check_reg(3, 32'h00001004, "AUIPC x3, 0x00001");

        $display("\n--- Checking Group B: I-type Immediate Arithmetic & Logic ---");
        check_reg(4,  32'd10,        "ADDI  x4, 10");
        check_reg(5,  -32'd5,        "ADDI  x5, -5");
        check_reg(6,  32'd1,         "SLTI  x6 (-5 < 0 signed)");
        check_reg(7,  32'd1,         "SLTIU x7 (10 < 20 unsigned)");
        check_reg(8,  32'd5,         "XORI  x8 (10 ^ 15)");
        check_reg(9,  32'd15,        "ORI   x9 (10 | 5)");
        check_reg(10, 32'd8,         "ANDI  x10 (10 & 8)");
        check_reg(11, 32'd40,        "SLLI  x11 (10 << 2)");
        check_reg(12, 32'd20,        "SRLI  x12 (40 >> 1)");
        check_reg(13, -32'd3,        "SRAI  x13 (-5 >>> 1)");

        $display("\n--- Checking Group A: R-type Arithmetic & Logic Instructions ---");
        check_reg(14, 32'd50,        "ADD   x14 (10 + 40)");
        check_reg(15, 32'd30,        "SUB   x15 (40 - 10)");
        check_reg(16, 32'd10,        "AND   x16 (10 & 15)");
        check_reg(17, 32'd15,        "OR    x17 (10 | 5)");
        check_reg(18, 32'd15,        "XOR   x18 (10 ^ 5)");
        check_reg(19, 32'd20,        "SLL   x19 (10 << 1)");
        check_reg(20, 32'd10,        "SRL   x20 (20 >> 1)");
        check_reg(21, -32'd3,        "SRA   x21 (-5 >>> 1)");
        check_reg(22, 32'd1,         "SLT   x22 (-5 < 10 signed)");
        check_reg(23, 32'd1,         "SLTU  x23 (10 < -5 unsigned)");

        $display("\n--- Checking Group C & D: Loads & Stores ---");
        check_reg(25, 32'd50,        "LW    x25 from SW offset 0");
        check_reg(26, 32'd40,        "LH    x26 from SH offset 4 (signed)");
        check_reg(27, 32'd40,        "LHU   x27 from SH offset 4 (unsigned)");
        check_reg(28, 32'd10,        "LB    x28 from SB offset 8 (signed)");
        check_reg(29, 32'd10,        "LBU   x29 from SB offset 8 (unsigned)");

        $display("\n--- Checking Group E: Conditional Branches ---");
        if (dut_core.rf_block.memory[30] === 32'd0) begin
            $display("  [PASS] All 6 Branches (BEQ, BNE, BLT, BGE, BLTU, BGEU) correctly taken!");
        end else begin
            $display("  [FAIL] Branch test failed! x30 was overwritten with 99!");
            errors = errors + 1;
        end

        $display("\n--- Checking Group F: Jumps (JAL, JALR) ---");
        check_reg(1, 32'h000000BC,   "JALR return address in x1 (PC+4 of JALR at 0xB8)");

        $display("\n--- Checking MMIO GPIO Write ---");
        if (led_out === 16'h0055) begin
            $display("  [PASS] GPIO LED output correctly driven: 0x%04h", led_out);
        end else begin
            $display("  [FAIL] GPIO LED output mismatch: expected 0x0055, got 0x%04h", led_out);
            errors = errors + 1;
        end

        $display("\n==================================================================");
        if (errors == 0) begin
            $display("   ALL RV32I INSTRUCTION TESTS PASSED SUCCESSFULLY! (0 errors)    ");
            $display("==================================================================");
        end else begin
            $display("   RV32I TEST COMPLETED WITH %0d ERRORS!                         ", errors);
            $display("==================================================================");
        end

        $finish;
    end

endmodule

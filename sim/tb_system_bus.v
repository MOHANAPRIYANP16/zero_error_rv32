`timescale 1ns / 1ps

module tb_system_bus;

    reg clk = 0;
    always #5 clk = ~clk;

    reg rst_n = 0;

    // Master signals
    reg         mem_valid = 0;
    reg         mem_instr = 0;
    reg  [31:0] mem_addr  = 0;
    reg  [31:0] mem_wdata = 0;
    reg  [3:0]  mem_wstrb = 0;
    wire        mem_ready;
    wire [31:0] mem_rdata;

    // Slaves
    wire        code_sel,  code_valid,  code_ready;
    wire [31:0] code_rdata;
    wire        data_sel,  data_valid,  data_ready;
    wire [31:0] data_rdata;
    wire        uart_sel,  uart_valid,  uart_ready;
    wire [31:0] uart_rdata;
    wire        gpio_sel,  gpio_valid,  gpio_ready;
    wire [31:0] gpio_rdata;
    wire        i2c_sel,   i2c_valid,   i2c_ready;
    wire [31:0] i2c_rdata;

    // Interconnect instance
    soc_bus_interconnect dut_bus (
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

    // Dummy responder slaves
    reg code_ready_r, data_ready_r, uart_ready_r, gpio_ready_r, i2c_ready_r;
    reg [31:0] code_mem_mock, data_mem_mock, uart_reg_mock, gpio_reg_mock, i2c_reg_mock;

    assign code_ready = code_ready_r;
    assign data_ready = data_ready_r;
    assign uart_ready = uart_ready_r;
    assign gpio_ready = gpio_ready_r;
    assign i2c_ready  = i2c_ready_r;

    assign code_rdata = code_mem_mock;
    assign data_rdata = data_mem_mock;
    assign uart_rdata = uart_reg_mock;
    assign gpio_rdata = gpio_reg_mock;
    assign i2c_rdata  = i2c_reg_mock;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            code_ready_r <= 0; data_ready_r <= 0; uart_ready_r <= 0;
            gpio_ready_r <= 0; i2c_ready_r  <= 0;
            code_mem_mock <= 32'h1111_0000;
            data_mem_mock <= 32'h2222_0000;
            uart_reg_mock <= 32'h3333_0000;
            gpio_reg_mock <= 32'h4444_0000;
            i2c_reg_mock  <= 32'h5555_0000;
        end else begin
            code_ready_r <= code_valid && !code_ready_r;
            data_ready_r <= data_valid && !data_ready_r;
            uart_ready_r <= uart_valid && !uart_ready_r;
            gpio_ready_r <= gpio_valid && !gpio_ready_r;
            i2c_ready_r  <= i2c_valid  && !i2c_ready_r;

            if (code_valid && |mem_wstrb) code_mem_mock <= mem_wdata;
            if (data_valid && |mem_wstrb) data_mem_mock <= mem_wdata;
            if (uart_valid && |mem_wstrb) uart_reg_mock <= mem_wdata;
            if (gpio_valid && |mem_wstrb) gpio_reg_mock <= mem_wdata;
            if (i2c_valid  && |mem_wstrb) i2c_reg_mock  <= mem_wdata;
        end
    end

    integer errors = 0;

    task bus_write;
        input [31:0] addr;
        input [31:0] wdata;
        begin
            @(posedge clk);
            mem_addr  <= addr;
            mem_wdata <= wdata;
            mem_wstrb <= 4'b1111;
            mem_valid <= 1'b1;
            @(posedge clk);
            while (!mem_ready) @(posedge clk);
            mem_valid <= 1'b0;
            mem_wstrb <= 4'b0000;
            @(posedge clk);
        end
    endtask

    task bus_read;
        input  [31:0] addr;
        input  [31:0] expected;
        input  [255:0] name;
        begin
            @(posedge clk);
            mem_addr  <= addr;
            mem_wstrb <= 4'b0000;
            mem_valid <= 1'b1;
            @(posedge clk);
            while (!mem_ready) @(posedge clk);
            if (mem_rdata === expected) begin
                $display("  [PASS] %0s read at 0x%08h: expected 0x%08h, got 0x%08h", name, addr, expected, mem_rdata);
            end else begin
                $display("  [FAIL] %0s read at 0x%08h: expected 0x%08h, got 0x%08h", name, addr, expected, mem_rdata);
                errors = errors + 1;
            end
            mem_valid <= 1'b0;
            @(posedge clk);
        end
    endtask

    initial begin
        $display("==================================================================");
        $display("   STARTING SOC SYSTEM BUS & ADDRESS DECODER TESTBENCH            ");
        $display("==================================================================");

        rst_n = 0;
        #25;
        rst_n = 1;
        #20;

        $display("\n--- Testing Code RAM Bus Access (0x0000_0000) ---");
        bus_write(32'h0000_0100, 32'hCAFE_BABE);
        bus_read (32'h0000_0100, 32'hCAFE_BABE, "Code RAM");

        $display("\n--- Testing Data RAM Bus Access (0x1000_0000) ---");
        bus_write(32'h1000_0020, 32'h1234_5678);
        bus_read (32'h1000_0020, 32'h1234_5678, "Data RAM");

        $display("\n--- Testing UART MMIO Access (0x2000_0000) ---");
        bus_write(32'h2000_0000, 32'h0000_0041);
        bus_read (32'h2000_0000, 32'h0000_0041, "UART MMIO");

        $display("\n--- Testing GPIO MMIO Access (0x3000_0000) ---");
        bus_write(32'h3000_0000, 32'h0000_A5A5);
        bus_read (32'h3000_0000, 32'h0000_A5A5, "GPIO MMIO");

        $display("\n--- Testing I2C MMIO Access (0x4000_0000) ---");
        bus_write(32'h4000_0004, 32'h0000_00A7);
        bus_read (32'h4000_0004, 32'h0000_00A7, "I2C MMIO");

        $display("\n--- Testing Unmapped Address Safegaurd (0x5000_0000) ---");
        bus_read (32'h5000_0000, 32'hDEADBEEF, "Unmapped Space");

        $display("\n==================================================================");
        if (errors == 0) begin
            $display("   ALL SYSTEM BUS INTERCONNECT TESTS PASSED! (0 errors)          ");
            $display("==================================================================");
        end else begin
            $display("   SYSTEM BUS TEST COMPLETED WITH %0d ERRORS!                    ", errors);
            $display("==================================================================");
        end

        $finish;
    end

endmodule

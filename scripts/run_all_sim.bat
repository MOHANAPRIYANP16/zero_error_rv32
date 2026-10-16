@echo off
REM ============================================================================
REM run_all_sim.bat -- Automated Verification Suite for Custom RV32I SoC
REM ============================================================================

set IVERILOG=C:\iverilog\bin\iverilog.exe
set VVP=C:\iverilog\bin\vvp.exe

echo ======================================================================
echo    RUNNING COMPLETE RV32I SOC REGRESSION SIMULATION SUITE
echo ======================================================================

echo [1/6] Running RV32I Core Instruction Set Testbench...
%IVERILOG% -g2012 -o riscv_soc\sim\tb_core.vvp -I riscv_soc\rtl\core -I riscv_soc\rtl\peripheral -I riscv_soc\memory riscv_soc\rtl\core\*.v riscv_soc\rtl\peripheral\ram_sync.v riscv_soc\rtl\peripheral\gpio_peripheral.v riscv_soc\rtl\peripheral\soc_bus_interconnect.v riscv_soc\sim\tb_core_instructions.v
if %ERRORLEVEL% neq 0 ( echo [FAIL] Compilation failed for tb_core_instructions & exit /b 1 )
%VVP% riscv_soc\sim\tb_core.vvp
if %ERRORLEVEL% neq 0 ( echo [FAIL] Simulation failed for tb_core_instructions & exit /b 1 )

echo.
echo [2/6] Running System Bus Interconnect and Memory Map Testbench...
%IVERILOG% -g2012 -o riscv_soc\sim\tb_bus.vvp riscv_soc\rtl\peripheral\soc_bus_interconnect.v riscv_soc\sim\tb_system_bus.v
if %ERRORLEVEL% neq 0 ( echo [FAIL] Compilation failed for tb_system_bus & exit /b 1 )
%VVP% riscv_soc\sim\tb_bus.vvp
if %ERRORLEVEL% neq 0 ( echo [FAIL] Simulation failed for tb_system_bus & exit /b 1 )

echo.
echo [3/6] Running GPIO Peripheral Unit Testbench...
%IVERILOG% -g2012 -o riscv_soc\sim\tb_gpio.vvp riscv_soc\rtl\peripheral\gpio_peripheral.v riscv_soc\sim\tb_gpio.v
if %ERRORLEVEL% neq 0 ( echo [FAIL] Compilation failed for tb_gpio & exit /b 1 )
%VVP% riscv_soc\sim\tb_gpio.vvp
if %ERRORLEVEL% neq 0 ( echo [FAIL] Simulation failed for tb_gpio & exit /b 1 )

echo.
echo [4/6] Running UART Peripheral Unit Testbench...
%IVERILOG% -g2012 -o riscv_soc\sim\tb_uart.vvp riscv_soc\rtl\peripheral\baud_rate_tx.v riscv_soc\rtl\peripheral\baud_rate_rx.v riscv_soc\rtl\peripheral\uart_tx.v riscv_soc\rtl\peripheral\uart_rx.v riscv_soc\rtl\peripheral\uart_peripheral.v riscv_soc\sim\tb_uart.v
if %ERRORLEVEL% neq 0 ( echo [FAIL] Compilation failed for tb_uart & exit /b 1 )
%VVP% riscv_soc\sim\tb_uart.vvp
if %ERRORLEVEL% neq 0 ( echo [FAIL] Simulation failed for tb_uart & exit /b 1 )

echo.
echo [5/6] Running I2C Peripheral with Behavioral Sensor Model Testbench...
%IVERILOG% -g2012 -o riscv_soc\sim\tb_i2c.vvp riscv_soc\rtl\peripheral\scl_gen.v riscv_soc\rtl\peripheral\i2c_master.v riscv_soc\rtl\peripheral\i2c_peripheral.v riscv_soc\sim\i2c_slave_model.v riscv_soc\sim\tb_i2c.v
if %ERRORLEVEL% neq 0 ( echo [FAIL] Compilation failed for tb_i2c & exit /b 1 )
%VVP% riscv_soc\sim\tb_i2c.vvp
if %ERRORLEVEL% neq 0 ( echo [FAIL] Simulation failed for tb_i2c & exit /b 1 )

echo.
echo [6/6] Running Integrated RV32I SoC Top-Level Testbench...
%IVERILOG% -g2012 -o riscv_soc\sim\tb_soc.vvp -I riscv_soc\rtl\core -I riscv_soc\rtl\peripheral -I riscv_soc\memory riscv_soc\rtl\core\*.v riscv_soc\rtl\peripheral\*.v riscv_soc\rtl\top\*.v riscv_soc\sim\i2c_slave_model.v riscv_soc\sim\tb_soc_top.v
if %ERRORLEVEL% neq 0 ( echo [FAIL] Compilation failed for tb_soc_top & exit /b 1 )
%VVP% riscv_soc\sim\tb_soc.vvp
if %ERRORLEVEL% neq 0 ( echo [FAIL] Simulation failed for tb_soc_top & exit /b 1 )

echo.
echo ======================================================================
echo    ALL 6 SIMULATION TESTBENCHES EXECUTED AND PASSED SUCCESSFULLY!
echo ======================================================================

# System Clock (100 MHz on-board oscillator)
set_property -dict {PACKAGE_PIN F14 IOSTANDARD LVCMOS33} [get_ports clk]
create_clock -period 10.000 -name sys_clk [get_ports clk]

# Configuration properties
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

# Active-High Reset Push Button (BTN0 / PIN J2)
set_property -dict {PACKAGE_PIN J2 IOSTANDARD LVCMOS33} [get_ports btn_rst]

# 16 User LEDs
set_property -dict {PACKAGE_PIN G1 IOSTANDARD LVCMOS33} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN G2 IOSTANDARD LVCMOS33} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN F1 IOSTANDARD LVCMOS33} [get_ports {led[2]}]
set_property -dict {PACKAGE_PIN F2 IOSTANDARD LVCMOS33} [get_ports {led[3]}]
set_property -dict {PACKAGE_PIN E1 IOSTANDARD LVCMOS33} [get_ports {led[4]}]
set_property -dict {PACKAGE_PIN E2 IOSTANDARD LVCMOS33} [get_ports {led[5]}]
set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS33} [get_ports {led[6]}]
set_property -dict {PACKAGE_PIN E5 IOSTANDARD LVCMOS33} [get_ports {led[7]}]
set_property -dict {PACKAGE_PIN E6 IOSTANDARD LVCMOS33} [get_ports {led[8]}]
set_property -dict {PACKAGE_PIN C3 IOSTANDARD LVCMOS33} [get_ports {led[9]}]
set_property -dict {PACKAGE_PIN B2 IOSTANDARD LVCMOS33} [get_ports {led[10]}]
set_property -dict {PACKAGE_PIN A2 IOSTANDARD LVCMOS33} [get_ports {led[11]}]
set_property -dict {PACKAGE_PIN B3 IOSTANDARD LVCMOS33} [get_ports {led[12]}]
set_property -dict {PACKAGE_PIN A3 IOSTANDARD LVCMOS33} [get_ports {led[13]}]
set_property -dict {PACKAGE_PIN B4 IOSTANDARD LVCMOS33} [get_ports {led[14]}]
set_property -dict {PACKAGE_PIN A4 IOSTANDARD LVCMOS33} [get_ports {led[15]}]

# Onboard USB-UART Bridge (UART0 - PC Console / Bootloader)
set_property -dict {PACKAGE_PIN V12 IOSTANDARD LVCMOS33} [get_ports UART_rxd]
set_property -dict {PACKAGE_PIN U11 IOSTANDARD LVCMOS33} [get_ports UART_txd]

# Pmod A UART1 (R307 Fingerprint Sensor: pin 3 = FPGA TX -> R307 RX, pin 4 = FPGA RX -> R307 TX)
set_property -dict {PACKAGE_PIN B14 IOSTANDARD LVCMOS33} [get_ports UART1_txd]
set_property -dict {PACKAGE_PIN A14 IOSTANDARD LVCMOS33} [get_ports UART1_rxd]

# I2C Bus Pins (with pull-up enabled for open-drain operation)
set_property -dict {PACKAGE_PIN T5 IOSTANDARD LVCMOS33 PULLUP true} [get_ports i2c_scl]
set_property -dict {PACKAGE_PIN T6 IOSTANDARD LVCMOS33 PULLUP true} [get_ports i2c_sda]

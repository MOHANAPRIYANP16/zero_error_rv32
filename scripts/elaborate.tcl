# ============================================================================
# elaborate.tcl -- Standalone RTL Elaboration & Syntax Verification Script
# Usage:
#   vivado -mode batch -source riscv_soc/scripts/elaborate.tcl
# ============================================================================

set SCRIPT_DIR [file dirname [file normalize [info script]]]
set SOC_ROOT   [file normalize "$SCRIPT_DIR/.."]
set PART_NAME  "xc7s50csga324-1"
set TOP_MODULE "fpga_top"

puts "======================================================================"
puts "  RUNNING STANDALONE RTL ELABORATION CHECK"
puts "  Part: $PART_NAME | Top: $TOP_MODULE"
puts "======================================================================"

# Read all RTL sources with space-safe list passing
set core_files       [glob "$SOC_ROOT/rtl/core/*.v"]
set peripheral_files [glob "$SOC_ROOT/rtl/peripheral/*.v"]
set top_files        [glob "$SOC_ROOT/rtl/top/*.v"]
set fpga_files       [list "$SOC_ROOT/fpga/fpga_top.v"]
set xdc_files        [list "$SOC_ROOT/constraints/boolean_board.xdc"]

read_verilog $core_files
read_verilog $peripheral_files
read_verilog $top_files
read_verilog $fpga_files
read_xdc     $xdc_files

# Run elaboration
synth_design -rtl -name rtl_1 -top "$TOP_MODULE" -part "$PART_NAME"

puts "======================================================================"
puts "  \[PASS\] RTL ELABORATION COMPLETED SUCCESSFULLY WITH ZERO ERRORS!"
puts "======================================================================"

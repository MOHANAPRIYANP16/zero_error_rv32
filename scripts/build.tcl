# ============================================================================
# build.tcl -- Vivado Build Script for Custom RV32I SoC on Digital Boolean Board
# Target Part: Xilinx Spartan-7 XC7S50-CSGA324-1
#
# Usage:
#   vivado -mode batch -source riscv_soc/scripts/build.tcl
# ============================================================================

set SCRIPT_DIR [file dirname [file normalize [info script]]]
set SOC_ROOT   [file normalize "$SCRIPT_DIR/.."]
set PROJ_DIR   "$SOC_ROOT/build/riscv_soc_proj"
set PART_NAME  "xc7s50csga324-1"
set TOP_MODULE "fpga_top"

puts "======================================================================"
puts "  STARTING VIVADO PROJECT CREATION & BUILD"
puts "  SoC Root: $SOC_ROOT"
puts "  Target Part: $PART_NAME"
puts "  Top Module: $TOP_MODULE"
puts "======================================================================"

# Open existing project or create new project
file mkdir "$SOC_ROOT/build"
if {[file exists "$PROJ_DIR/riscv_soc_proj.xpr"]} {
    puts "Opening existing project: $PROJ_DIR/riscv_soc_proj.xpr"
    open_project "$PROJ_DIR/riscv_soc_proj.xpr"
    reset_run synth_1
    reset_run impl_1
} else {
    create_project -force riscv_soc_proj "$PROJ_DIR" -part "$PART_NAME"
}

# Add RTL Core Sources
add_files -norecurse [list \
    "$SOC_ROOT/rtl/core/alu.v" \
    "$SOC_ROOT/rtl/core/alu_control.v" \
    "$SOC_ROOT/rtl/core/alu_src_mux.v" \
    "$SOC_ROOT/rtl/core/branch_comparator.v" \
    "$SOC_ROOT/rtl/core/control_unit.v" \
    "$SOC_ROOT/rtl/core/immediate_generator.v" \
    "$SOC_ROOT/rtl/core/load_store_unit.v" \
    "$SOC_ROOT/rtl/core/pc.v" \
    "$SOC_ROOT/rtl/core/pc_offset_adder.v" \
    "$SOC_ROOT/rtl/core/pc_plus_4.v" \
    "$SOC_ROOT/rtl/core/register_file.v" \
    "$SOC_ROOT/rtl/core/write_back_mux.v" \
    "$SOC_ROOT/rtl/core/risc_core.v" \
]

# Add RTL Peripheral Sources
add_files -norecurse [list \
    "$SOC_ROOT/rtl/peripheral/baud_rate_tx.v" \
    "$SOC_ROOT/rtl/peripheral/baud_rate_rx.v" \
    "$SOC_ROOT/rtl/peripheral/uart_tx.v" \
    "$SOC_ROOT/rtl/peripheral/uart_rx.v" \
    "$SOC_ROOT/rtl/peripheral/uart_peripheral.v" \
    "$SOC_ROOT/rtl/peripheral/scl_gen.v" \
    "$SOC_ROOT/rtl/peripheral/i2c_master.v" \
    "$SOC_ROOT/rtl/peripheral/i2c_peripheral.v" \
    "$SOC_ROOT/rtl/peripheral/gpio_peripheral.v" \
    "$SOC_ROOT/rtl/peripheral/ram_sync.v" \
    "$SOC_ROOT/rtl/peripheral/soc_bus_interconnect.v" \
]

# Add RTL Top & FPGA Top Sources
add_files -norecurse [list \
    "$SOC_ROOT/rtl/top/riscv_soc_top.v" \
    "$SOC_ROOT/fpga/fpga_top.v" \
]

# Add Memory Initialization File
add_files -norecurse [list \
    "$SOC_ROOT/memory/instruction.mem" \
]

# Add Constraints
add_files -fileset constrs_1 -norecurse [list \
    "$SOC_ROOT/constraints/boolean_board.xdc" \
]

# Set Top Module
set_property top "$TOP_MODULE" [current_fileset]
update_compile_order -fileset sources_1

# Copy instruction.mem into project directory
file copy -force "$SOC_ROOT/memory/instruction.mem" "$PROJ_DIR/"

puts "--- Launching Synthesis Run (synth_1) ---"
launch_runs synth_1 -jobs 2
wait_on_run synth_1

set synth_status [get_property STATUS [get_runs synth_1]]
set synth_prog   [get_property PROGRESS [get_runs synth_1]]
puts "Synthesis Status: $synth_status ($synth_prog)"
if {![string match "*Complete*" $synth_status] && $synth_prog != "100%"} {
    puts "  \[FAIL\] Synthesis Failed! Check synth_1/runme.log"
    exit 1
}
puts "  \[PASS\] Synthesis Completed Successfully!"

puts "--- Configuring Implementation Properties ---"
set_property STEPS.OPT_DESIGN.ARGS.DIRECTIVE NoBramPowerOpt [get_runs impl_1]
set_property STEPS.POWER_OPT_DESIGN.IS_ENABLED false [get_runs impl_1]

puts "--- Launching Implementation Run with Bitstream Generation (impl_1) ---"
launch_runs impl_1 -to_step write_bitstream -jobs 2
wait_on_run impl_1

set impl_status [get_property STATUS [get_runs impl_1]]
set impl_prog   [get_property PROGRESS [get_runs impl_1]]
puts "Implementation Status: $impl_status ($impl_prog)"
if {![string match "*Complete*" $impl_status] && $impl_prog != "100%"} {
    puts "  \[FAIL\] Implementation / Bitstream Generation Failed! Check impl_1/runme.log"
    exit 1
}

set bit_files [glob -nocomplain "$PROJ_DIR/riscv_soc_proj.runs/impl_1/*.bit"]
puts "======================================================================"
puts "  BUILD SUCCEEDED!"
puts "  Generated Bitstream: $bit_files"
puts "======================================================================"

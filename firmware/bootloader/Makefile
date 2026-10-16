# ============================================================================
# Makefile -- Resident UART Bootloader for Custom RV32I SoC
# ============================================================================

XPACK_DEFAULT ?= /opt/riscv/xpack-riscv-none-elf-gcc-15.2.0-1/bin
ifneq ($(wildcard $(XPACK_DEFAULT)/riscv-none-elf-gcc),)
    CROSS_COMPILE ?= $(XPACK_DEFAULT)/riscv-none-elf-
else
    CROSS_COMPILE ?= riscv-none-elf-
endif

CC             = $(CROSS_COMPILE)gcc
OBJCOPY        = $(CROSS_COMPILE)objcopy
OBJDUMP        = $(CROSS_COMPILE)objdump
SIZE           = $(CROSS_COMPILE)size
PYTHON         ?= python3

TOOLS_DIR      = ../tools
MEMORY_DIR     = ../../memory

CFLAGS         = -march=rv32i -mabi=ilp32 -mno-relax -Os -ffreestanding -nostdlib \
                 -ffunction-sections -fdata-sections -Wall -Wextra -Wno-array-bounds
LDFLAGS        = -T sections.ld -nostdlib -Wl,--no-relax -Wl,--gc-sections
LDLIBS         = -lgcc

OBJS           = start.o main.o

all: bootloader.elf bootloader.bin bootloader.dump bootloader.mem

bootloader.elf: $(OBJS) sections.ld
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $(OBJS) $(LDLIBS)
	$(SIZE) $@

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

%.o: %.s
	$(CC) $(CFLAGS) -c $< -o $@

bootloader.bin: bootloader.elf
	$(OBJCOPY) -O binary $< $@

bootloader.dump: bootloader.elf
	$(OBJDUMP) -d -S $< > $@

bootloader.mem: bootloader.bin $(TOOLS_DIR)/elf2mem.py
	$(PYTHON) $(TOOLS_DIR)/elf2mem.py bootloader.bin 1024 bootloader.mem

# Direct install into SoC Instruction Memory so Vivado reads it on synthesis / bitstream
install: bootloader.mem
	cp bootloader.mem $(MEMORY_DIR)/instruction.mem
	@echo "[Installed] Copied bootloader.mem to $(MEMORY_DIR)/instruction.mem"

clean:
	rm -f bootloader.elf bootloader.bin bootloader.dump bootloader.mem $(OBJS)

.PHONY: all clean install

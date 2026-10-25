# ============================================================================
# common.mk -- Shared compilation rules for RV32I firmware applications
# ============================================================================

# Auto-detect toolchain in PATH or default xPack installation path
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

COMMON_DIR    ?= ../../common
DRIVERS_DIR   ?= ../../drivers
TOOLS_DIR     ?= ../../tools
MEMORY_DIR    ?= ../../../memory

CFLAGS        ?= -march=rv32i -mabi=ilp32 -mno-relax -ffreestanding -nostdlib \
                 -ffunction-sections -fdata-sections \
                 -Wall -Wextra -Os -g \
                 -I$(COMMON_DIR) -I$(DRIVERS_DIR)

BOOTLOADER    ?= 1

ifeq ($(BOOTLOADER),1)
    LINKER_SCRIPT ?= $(COMMON_DIR)/linker_boot_app.ld
else
    LINKER_SCRIPT ?= $(COMMON_DIR)/linker.ld
endif

LDFLAGS       ?= -T $(LINKER_SCRIPT) -nostdlib -Wl,--no-relax -Wl,--gc-sections
LDLIBS        ?= -lgcc

# App & Local Common object files
APP_OBJS       = $(APP_SRCS:.c=.o)
COMMON_OBJS    = startup.o kprintf.o uart.o gpio.o i2c.o
ALL_OBJS       = $(APP_OBJS) $(COMMON_OBJS)

all: $(TARGET).elf $(TARGET).bin $(TARGET).dump $(TARGET).mem

$(TARGET).elf: $(ALL_OBJS) $(LINKER_SCRIPT)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $(ALL_OBJS) $(LDLIBS)
	$(SIZE) $@

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

startup.o: $(COMMON_DIR)/startup.S
	$(CC) $(CFLAGS) -c $< -o $@

kprintf.o: $(COMMON_DIR)/kprintf.c $(COMMON_DIR)/kprintf.h
	$(CC) $(CFLAGS) -c $< -o $@

uart.o: $(DRIVERS_DIR)/uart.c $(DRIVERS_DIR)/uart.h
	$(CC) $(CFLAGS) -c $< -o $@

gpio.o: $(DRIVERS_DIR)/gpio.c $(DRIVERS_DIR)/gpio.h
	$(CC) $(CFLAGS) -c $< -o $@

i2c.o: $(DRIVERS_DIR)/i2c.c $(DRIVERS_DIR)/i2c.h
	$(CC) $(CFLAGS) -c $< -o $@

$(TARGET).bin: $(TARGET).elf
	$(OBJCOPY) -O binary $< $@

$(TARGET).dump: $(TARGET).elf
	$(OBJDUMP) -d -S $< > $@

$(TARGET).mem: $(TARGET).bin $(TOOLS_DIR)/elf2mem.py
	$(PYTHON) $(TOOLS_DIR)/elf2mem.py $(TARGET).bin 4096 $(TARGET).mem

# Install the generated .mem directly into SoC instruction memory for Vivado simulation / bitstream
install: $(TARGET).mem
	cp $(TARGET).mem $(MEMORY_DIR)/instruction.mem
	@echo "[Installed] Copied $(TARGET).mem to $(MEMORY_DIR)/instruction.mem"

clean:
	rm -f $(TARGET).elf $(TARGET).bin $(TARGET).dump $(TARGET).mem $(ALL_OBJS)

.PHONY: all clean install

# ============================================================================
# Makefile -- Application compiled for UART Bootloader Upload
# Origin: 0x0000_0200 in Instruction Memory
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

COMMON_DIR     = ../common
DRIVERS_DIR    = ../drivers

CFLAGS         = -march=rv32i -mabi=ilp32 -mno-relax -ffreestanding -nostdlib \
                 -ffunction-sections -fdata-sections -Wall -Wextra -Os -g \
                 -I$(COMMON_DIR) -I$(DRIVERS_DIR)

LDFLAGS        = -T $(COMMON_DIR)/linker_boot_app.ld -nostdlib -Wl,--no-relax -Wl,--gc-sections
LDLIBS         = -lgcc

OBJS           = main.o startup.o kprintf.o uart.o gpio.o

TARGET         = boot_app

all: $(TARGET).elf $(TARGET).bin $(TARGET).dump

$(TARGET).elf: $(OBJS) $(COMMON_DIR)/linker_boot_app.ld
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $(OBJS) $(LDLIBS)
	$(SIZE) $@

main.o: main.c
	$(CC) $(CFLAGS) -c $< -o $@

startup.o: $(COMMON_DIR)/startup.S
	$(CC) $(CFLAGS) -c $< -o $@

kprintf.o: $(COMMON_DIR)/kprintf.c $(COMMON_DIR)/kprintf.h
	$(CC) $(CFLAGS) -c $< -o $@

uart.o: $(DRIVERS_DIR)/uart.c $(DRIVERS_DIR)/uart.h
	$(CC) $(CFLAGS) -c $< -o $@

gpio.o: $(DRIVERS_DIR)/gpio.c $(DRIVERS_DIR)/gpio.h
	$(CC) $(CFLAGS) -c $< -o $@

$(TARGET).bin: $(TARGET).elf
	$(OBJCOPY) -O binary $< $@

$(TARGET).dump: $(TARGET).elf
	$(OBJDUMP) -d -S $< > $@

clean:
	rm -f $(TARGET).elf $(TARGET).bin $(TARGET).dump $(OBJS)

.PHONY: all clean

# ============================================================================
# Master Firmware Makefile for Custom RV32I SoC
# ============================================================================

APPS = bootloader \
       boot_app \
       app/01_blinky \
       app/02_hello_uart \
       app/03_gpio_demo \
       app/04_i2c_scan \
       app/05_integrated_demo \
       app/06_r307_fingerprint

all:
	@for dir in $(APPS); do \
		echo "=========================================="; \
		echo "Building $$dir ..."; \
		echo "=========================================="; \
		$(MAKE) -C $$dir all || exit 1; \
	done
	@echo ""
	@echo "All firmware applications & bootloader built successfully."

clean:
	@for dir in $(APPS); do \
		$(MAKE) -C $$dir clean; \
	done
	@echo "All build artifacts cleaned."

# Target to install resident Bootloader into instruction.mem ($readmemh)
load_bootloader:
	$(MAKE) -C bootloader install

# Targets to install standalone applications directly into instruction.mem
load_blinky:
	$(MAKE) -C app/01_blinky install

load_uart:
	$(MAKE) -C app/02_hello_uart install

load_gpio:
	$(MAKE) -C app/03_gpio_demo install

load_i2c:
	$(MAKE) -C app/04_i2c_scan install

load_demo:
	$(MAKE) -C app/05_integrated_demo \
       app/06_r307_fingerprint install

# Upload helper to send boot_app over UART
upload:
	python tools/upload.py $(PORT) boot_app/boot_app.bin

help:
	@echo "Usage:"
	@echo "  make all                     Build bootloader and all application demos"
	@echo "  make clean                   Clean all build artifacts"
	@echo "  make load_bootloader         Install resident UART bootloader into instruction.mem"
	@echo "  make load_blinky             Install standalone blinky into instruction.mem"
	@echo "  make load_uart               Install standalone hello_uart into instruction.mem"
	@echo "  make load_gpio               Install standalone gpio_demo into instruction.mem"
	@echo "  make load_i2c                Install standalone i2c_scan into instruction.mem"
	@echo "  make load_demo               Install standalone integrated_demo into instruction.mem"
	@echo "  make upload PORT=COM14       Upload boot_app.bin over UART to FPGA bootloader"

.PHONY: all clean load_bootloader load_blinky load_uart load_gpio load_i2c load_demo upload help

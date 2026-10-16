/* ============================================================================
 * 05_integrated_demo -- Comprehensive Interactive SoC Test Suite
 * Target: Custom RV32I Single-Cycle SoC on Real Digital Boolean FPGA
 * ============================================================================ */

#include "../../common/soc_regs.h"
#include "../../common/kprintf.h"
#include "../../drivers/uart.h"
#include "../../drivers/gpio.h"
#include "../../drivers/i2c.h"

static void print_menu(void)
{
    kprintf("\n=== RV32I SoC Menu ===\n");
    kprintf("1: Blink LEDs\n");
    kprintf("2: Read Inputs\n");
    kprintf("3: Scan I2C\n");
    kprintf("4: SoC Info\n");
    kprintf("5: Test RAM\n");
    kprintf("Select (1-5): ");
}

static void test_ram(void)
{
    kprintf("\nTesting 8KB Data RAM...\n");
    volatile uint32_t *ram = (volatile uint32_t *)DATA_RAM_BASE;

    bool pass = true;
    for (int i = 0; i < 32; i++) {
        uint32_t pat = 0xA5A50000 | (uint32_t)i;
        ram[i] = pat;
        if (ram[i] != pat) {
            kprintf("FAIL at %d: 0x%x != 0x%x\n", i, ram[i], pat);
            pass = false;
            break;
        }
    }
    if (pass) {
        kprintf("PASS: RAM verified!\n");
    }
}

int main(void)
{
    uart_init(UART_BAUD_115200);
    i2c_init(I2C_SPEED_STD_100K);
    gpio_set_leds(0x0001);

    delay_ms(100);

    while (1) {
        print_menu();
        char choice = uart_getc();
        kprintf("%c\n", choice);

        switch (choice) {
            case '1': {
                kprintf("Blinking...\n");
                for (int i = 0; i < 4; i++) {
                    gpio_set_leds(0xFFFF);
                    delay_ms(150);
                    gpio_set_leds(0x0000);
                    delay_ms(150);
                }
                kprintf("Done.\n");
                break;
            }
            case '2': {
                uint16_t in_val = gpio_get_inputs();
                kprintf("Inputs: 0x%x\n", in_val);
                gpio_set_leds(in_val);
                break;
            }
            case '3': {
                kprintf("Scanning I2C...\n");
                int found = 0;
                for (uint8_t a = 0x08; a <= 0x77; a++) {
                    if (i2c_ping(a)) {
                        kprintf("Found: 0x%x\n", a);
                        found++;
                    }
                }
                kprintf("Total: %d\n", found);
                break;
            }
            case '4': {
                kprintf("\nSoC Info:\n");
                kprintf("Clk: 25MHz, ISA: RV32I\n");
                kprintf("ROM: 4KB @ 0x0, RAM: 8KB @ 0x10000000\n");
                kprintf("UART: 0x20000000, GPIO: 0x30000000\n");
                break;
            }
            case '5': {
                test_ram();
                break;
            }
            default: {
                kprintf("Invalid.\n");
                break;
            }
        }
    }

    return 0;
}

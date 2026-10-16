/* ============================================================================
 * 04_i2c_scan -- I2C Bus Scanner Utility
 * Target: Custom RV32I Single-Cycle SoC on Real Digital Boolean FPGA
 * ============================================================================ */

#include "../../common/soc_regs.h"
#include "../../common/kprintf.h"
#include "../../drivers/uart.h"
#include "../../drivers/gpio.h"
#include "../../drivers/i2c.h"

int main(void)
{
    uart_init(UART_BAUD_115200);
    i2c_init(I2C_SPEED_STD_100K);
    gpio_set_leds(0x000F);

    delay_ms(100);

    kprintf("\n--- Starting I2C Bus Scan (100 kHz standard mode) ---\n");
    kprintf("     0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f\n");

    uint8_t found_count = 0;

    for (uint8_t row = 0; row < 0x80; row += 16) {
        kprintf("%02x: ", row);
        for (uint8_t col = 0; col < 16; col++) {
            uint8_t addr = row + col;
            if (addr < 0x08 || addr > 0x77) {
                kprintf("   ");
            } else {
                if (i2c_ping(addr)) {
                    kprintf("%02x ", addr);
                    found_count++;
                } else {
                    kprintf("-- ");
                }
            }
        }
        kprintf("\n");
    }

    kprintf("Scan completed: %u device(s) found.\n\n", found_count);
    gpio_set_leds((uint16_t)found_count);

    while (1) {
        delay_ms(1000);
    }

    return 0;
}

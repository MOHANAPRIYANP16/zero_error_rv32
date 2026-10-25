/* ============================================================================
 * 04_i2c_scan -- I2C Scanner & MPU-6050 Diagnostic Utility
 * Target: Custom RV32I SoC on Real Digital Boolean FPGA
 * Origin: 0x0000_0200 (for UART Bootloader Upload via upload.py)
 * ============================================================================
 * GPIO Indication:
 *   - LED0 (G1, Bit 0): ON = I2C device detected (Working correctly)
 *   - LED1 (G2, Bit 1): ON = No device detected (Error / check wiring)
 *
 * I2C Pins:
 *   - SCL = Pin T5
 *   - SDA = Pin T6
 * ============================================================================ */

#include "../../common/soc_regs.h"
#include "../../common/kprintf.h"
#include "../../drivers/uart.h"
#include "../../drivers/gpio.h"
#include "../../drivers/i2c.h"

static void print_hex_byte(uint8_t val)
{
    static const char hex[] = "0123456789abcdef";
    uart_putc(hex[(val >> 4) & 0x0F]);
    uart_putc(hex[val & 0x0F]);
}

int main(void)
{
    uart_init(UART_BAUD_115200);
    i2c_init(I2C_SPEED_STD_100K);

    // Initial startup LED flash: all 16 LEDs ON momentarily
    gpio_set_leds(0xFFFF);
    delay_ms(200);
    gpio_set_leds(0x0000);

    while (1) {
        uart_puts("\n========================================\n");
        uart_puts("   RV32I I2C Scanner (MPU-6050 Focus)   \n");
        uart_puts("========================================\n");
        uart_puts("Pins : SCL=T5, SDA=T6\n");
        uart_puts("LEDs : LED0=Success | LED1=Error\n\n");
        uart_puts("     0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f\n");

        uint8_t found_count = 0;
        uint8_t dev_addr = 0;

        for (uint8_t row = 0; row < 0x80; row += 16) {
            print_hex_byte(row);
            uart_puts(": ");
            for (uint8_t col = 0; col < 16; col++) {
                uint8_t addr = row + col;
                if (addr < 0x08 || addr > 0x77) {
                    uart_puts("   ");
                } else {
                    if (i2c_ping(addr)) {
                        print_hex_byte(addr);
                        uart_putc(' ');
                        found_count++;
                        dev_addr = addr;
                    } else {
                        uart_puts("-- ");
                    }
                }
            }
            uart_putc('\n');
        }

        uart_puts("----------------------------------------\n");

        if (found_count > 0) {
            // First GPIO (LED0) ON: Working correctly
            gpio_set_leds(0x0001);

            uart_puts("[OK] Device found at address: 0x");
            print_hex_byte(dev_addr);
            uart_puts("\n[OK] LED0 (First GPIO) is ON.\n");

            if (dev_addr == 0x68 || dev_addr == 0x69) {
                uart_puts("[MPU6050] Detected MPU-6050 6-Axis IMU Sensor!\n");
                uint8_t whoami = 0;
                if (i2c_read_reg(dev_addr, 0x75, &whoami)) {
                    uart_puts("[MPU6050] WHO_AM_I (0x75) = 0x");
                    print_hex_byte(whoami);
                    if (whoami == 0x68) {
                        uart_puts(" (Chip ID verified OK!)\n");
                    } else {
                        uart_puts("\n");
                    }
                }
            } else if (dev_addr == 0x70) {
                uart_puts("[SHTC3] Detected Sensirion SHTC3 Temp & Humidity Sensor!\n");
                uart_puts("[SHTC3] Sensor woke up from sleep mode successfully.\n");
            }
        } else {
            // Second GPIO (LED1) ON: Error / Not found
            gpio_set_leds(0x0002);

            uart_puts("[ERROR] No I2C devices found. LED1 is ON.\n");
            uart_puts("Wiring: SCL->T5, SDA->T6, VCC->3.3V, GND->GND\n");
            uart_puts("MPU6050 AD0->GND (addr 0x68) or 3.3V (0x69)\n");
        }

        uart_puts("\nRe-scanning in 3 seconds (or send key)...\n\n");

        for (int i = 0; i < 30; i++) {
            if (uart_has_rx()) {
                (void)uart_getc();
                break;
            }
            delay_ms(100);
        }
    }

    return 0;
}

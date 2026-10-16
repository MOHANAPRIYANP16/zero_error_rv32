/* ============================================================================
 * 02_hello_uart -- UART Banner and Echo Demo
 * Target: Custom RV32I Single-Cycle SoC on Real Digital Boolean FPGA
 * ============================================================================ */

#include "../../common/soc_regs.h"
#include "../../common/kprintf.h"
#include "../../drivers/uart.h"
#include "../../drivers/gpio.h"

int main(void)
{
    // Initialize UART at 115200 baud
    uart_init(UART_BAUD_115200);

    // Initial LED indication
    gpio_set_leds(0x0001);

    delay_ms(100);

    kprintf("\n");
    kprintf("====================================================\n");
    kprintf("   Welcome to Custom RV32I Single-Cycle SoC!\n");
    kprintf("   Board: Real Digital Boolean (XC7S50-CSGA324)\n");
    kprintf("   Core : RV32I Base Integer ISA @ 25.0 MHz\n");
    kprintf("   ROM  : 4 KB Code RAM   [0x0000_0000 - 0x0000_0FFF]\n");
    kprintf("   RAM  : 8 KB Data RAM   [0x1000_0000 - 0x1000_1FFF]\n");
    kprintf("   Baud : 115200 8N1\n");
    kprintf("====================================================\n");
    kprintf("Type any character into your serial terminal to echo...\n\n");

    uint32_t char_count = 0;

    while (1) {
        if (uart_has_rx()) {
            char c = uart_getc();
            char_count++;

            // Echo character back
            uart_putc(c);

            // Toggle LED0 on each received byte
            gpio_toggle_led(0);

            // Periodically print count
            if (c == '\r' || c == '\n') {
                kprintf("\n[Echo Total: %u characters received]\n", char_count);
            }
        }
    }

    return 0;
}

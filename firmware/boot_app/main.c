/* ============================================================================
 * boot_app -- Sample Application Uploaded at Runtime via UART Bootloader
 * Target: Custom RV32I Single-Cycle SoC on Real Digital Boolean FPGA
 * Origin: 0x0000_0200 (Instruction Memory)
 * ============================================================================ */

#include "../common/soc_regs.h"
#include "../common/kprintf.h"
#include "../drivers/uart.h"
#include "../drivers/gpio.h"

int main(void)
{
    // Initialize UART at 115200 baud
    uart_init(UART_BAUD_115200);

    // Initial LED indication: all 16 LEDs ON momentarily
    gpio_set_leds(0xFFFF);
    delay_ms(300);
    gpio_set_leds(0x0000);

    kprintf("\n\n");
    kprintf("****************************************************\n");
    kprintf("   SUCCESS: Application Launched by Bootloader!    \n");
    kprintf("   Running from Instruction Memory @ 0x0000_0200   \n");
    kprintf("   Core Frequency: 25.0 MHz (RV32I Single-Cycle)   \n");
    kprintf("****************************************************\n");
    kprintf("Echo mode active. Type characters into serial terminal:\n");

    uint16_t chaser = 0x0001;

    while (1) {
        // Fast bouncing LED chaser pattern
        gpio_set_leds(chaser);
        chaser <<= 1;
        if (chaser == 0) chaser = 0x0001;

        // If user sends character, echo back
        if (uart_has_rx()) {
            char c = uart_getc();
            kprintf("[FPGA Echo]: %c\n", c);
        }

        delay_ms(80);
    }

    return 0;
}

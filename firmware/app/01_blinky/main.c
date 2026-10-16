/* ============================================================================
 * 01_blinky -- 1-Second GPIO LED Blinking and Chaser Demo
 * Target: Custom RV32I Single-Cycle SoC on Real Digital Boolean FPGA
 * ============================================================================ */

#include "../../common/soc_regs.h"
#include "../../common/kprintf.h"
#include "../../drivers/gpio.h"

int main(void)
{
    // Initialize GPIO LEDs to all OFF
    gpio_set_leds(0x0000);

    while (1) {
        // Turn ON LED 0
        gpio_set_led(0, true);
        delay_ms(500);

        // Turn OFF LED 0
        gpio_set_led(0, false);
        delay_ms(500);
    }

    return 0;
}

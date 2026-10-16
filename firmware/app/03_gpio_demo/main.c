/* ============================================================================
 * 03_gpio_demo -- 16-LED Scanner & Input Read Demo
 * Target: Custom RV32I Single-Cycle SoC on Real Digital Boolean FPGA
 * ============================================================================ */

#include "../../common/soc_regs.h"
#include "../../common/kprintf.h"
#include "../../drivers/gpio.h"

int main(void)
{
    uint16_t led_mask = 0x0001;
    bool direction_left = true;

    while (1) {
        // Read input switches / buttons
        uint16_t inputs = gpio_get_inputs();

        // If any switch is ON, mirror lower 16 switches directly onto LEDs
        if (inputs != 0) {
            gpio_set_leds(inputs);
            delay_ms(50);
            continue;
        }

        // Default: Knight Rider scanning LED animation
        gpio_set_leds(led_mask);
        delay_ms(60);

        if (direction_left) {
            led_mask <<= 1;
            if (led_mask == 0x8000) {
                direction_left = false;
            }
        } else {
            led_mask >>= 1;
            if (led_mask == 0x0001) {
                direction_left = true;
            }
        }
    }

    return 0;
}

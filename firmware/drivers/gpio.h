#ifndef GPIO_H
#define GPIO_H

#include "../common/soc_regs.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Set all 16 LEDs with a 16-bit bitmask.
 * @param mask Bitmask where bit 0 is LED0 and bit 15 is LED15.
 */
void gpio_set_leds(uint16_t mask);

/**
 * @brief Read back the current state of the 16 LEDs.
 * @return 16-bit bitmask of current LED outputs.
 */
uint16_t gpio_get_leds(void);

/**
 * @brief Set or clear a specific individual LED.
 * @param pin LED index (0 to 15).
 * @param state true to turn ON (1), false to turn OFF (0).
 */
void gpio_set_led(uint8_t pin, bool state);

/**
 * @brief Toggle a specific individual LED.
 * @param pin LED index (0 to 15).
 */
void gpio_toggle_led(uint8_t pin);

/**
 * @brief Read the current digital state of the 16 onboard GPIO inputs (switches/buttons).
 * @return 16-bit input word.
 */
uint16_t gpio_get_inputs(void);

#ifdef __cplusplus
}
#endif

#endif // GPIO_H

#include "gpio.h"

void gpio_set_leds(uint16_t mask)
{
    GPIO_REG_DATA_OUT = (uint32_t)mask;
}

uint16_t gpio_get_leds(void)
{
    return (uint16_t)(GPIO_REG_DATA_OUT & 0xFFFF);
}

void gpio_set_led(uint8_t pin, bool state)
{
    if (pin > 15) return;
    uint32_t current = GPIO_REG_DATA_OUT;
    if (state) {
        current |= (1UL << pin);
    } else {
        current &= ~(1UL << pin);
    }
    GPIO_REG_DATA_OUT = current;
}

void gpio_toggle_led(uint8_t pin)
{
    if (pin > 15) return;
    GPIO_REG_DATA_OUT ^= (1UL << pin);
}

uint16_t gpio_get_inputs(void)
{
    return (uint16_t)(GPIO_REG_DATA_IN & 0xFFFF);
}

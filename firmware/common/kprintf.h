#ifndef KPRINTF_H
#define KPRINTF_H

#include <stddef.h>
#include <stdint.h>
#include <stdarg.h>
#include "soc_regs.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Calibrated delay loop in CPU instruction cycles.
 * @param cycles Number of clock cycles to delay.
 */
void delay_cycles(uint32_t cycles);

/**
 * @brief Calibrated millisecond delay (calibrated for 25 MHz RV32I core).
 * @param ms Delay duration in milliseconds.
 */
void delay_ms(uint32_t ms);

/**
 * @brief Calibrated microsecond delay.
 * @param us Delay duration in microseconds.
 */
void delay_us(uint32_t us);

/**
 * @brief Lightweight, reentrant printf that outputs directly to UART.
 * Supports: %c, %s, %d, %i, %u, %x, %X, %p, %%
 */
int kprintf(const char *fmt, ...);

/**
 * @brief Lightweight snprintf for formatting into a buffer.
 */
int ksnprintf(char *buf, size_t size, const char *fmt, ...);

// Standard string helpers for bare-metal
void *kmemset(void *dst, int val, size_t count);
void *kmemcpy(void *dst, const void *src, size_t count);
size_t kstrlen(const char *str);

#ifdef __cplusplus
}
#endif

#endif // KPRINTF_H

#include "kprintf.h"
#include "../drivers/uart.h"

// Delay calibrated for 25.0 MHz Single-Cycle RV32I Core
// In single cycle: addi = 1 cycle, bnez = 1 cycle -> 2 cycles per iteration.
void delay_cycles(uint32_t count)
{
    if (count == 0) return;
    __asm__ volatile (
        "1: addi %0, %0, -1\n"
        "   bnez %0, 1b\n"
        : "+r"(count)
    );
}

void delay_ms(uint32_t ms)
{
    while (ms--) {
        // 25,000 cycles / 2 = 12,500 loop iterations per ms
        delay_cycles(12500);
    }
}

void delay_us(uint32_t us)
{
    while (us--) {
        // 25 cycles / 2 ~ 12 loop iterations per us
        delay_cycles(12);
    }
}

void *kmemset(void *dst, int val, size_t count)
{
    uint8_t *p = (uint8_t *)dst;
    while (count--) {
        *p++ = (uint8_t)val;
    }
    return dst;
}

void *kmemcpy(void *dst, const void *src, size_t count)
{
    uint8_t *d = (uint8_t *)dst;
    const uint8_t *s = (const uint8_t *)src;
    while (count--) {
        *d++ = *s++;
    }
    return dst;
}

size_t kstrlen(const char *str)
{
    size_t len = 0;
    while (str && str[len]) {
        len++;
    }
    return len;
}

static void print_num(uint32_t val, uint32_t base, bool uppercase, bool is_signed)
{
    char buf[32];
    int idx = 0;

    if (is_signed && ((int32_t)val < 0)) {
        uart_putc('-');
        val = (uint32_t)(-(int32_t)val);
    }

    if (val == 0) {
        uart_putc('0');
        return;
    }

    const char *digits = uppercase ? "0123456789ABCDEF" : "0123456789abcdef";

    while (val > 0) {
        buf[idx++] = digits[val % base];
        val /= base;
    }

    while (idx > 0) {
        uart_putc(buf[--idx]);
    }
}

int kprintf(const char *fmt, ...)
{
    if (!fmt) return 0;
    va_list args;
    va_start(args, fmt);

    int count = 0;
    for (const char *p = fmt; *p != '\0'; p++) {
        if (*p != '%') {
            uart_putc(*p);
            count++;
            continue;
        }

        p++; // Skip '%'
        switch (*p) {
            case 'c': {
                char c = (char)va_arg(args, int);
                uart_putc(c);
                count++;
                break;
            }
            case 's': {
                const char *s = va_arg(args, const char *);
                if (!s) s = "(null)";
                while (*s) {
                    uart_putc(*s++);
                    count++;
                }
                break;
            }
            case 'd':
            case 'i': {
                int32_t d = va_arg(args, int32_t);
                print_num((uint32_t)d, 10, false, true);
                count++;
                break;
            }
            case 'u': {
                uint32_t u = va_arg(args, uint32_t);
                print_num(u, 10, false, false);
                count++;
                break;
            }
            case 'x': {
                uint32_t x = va_arg(args, uint32_t);
                print_num(x, 16, false, false);
                count++;
                break;
            }
            case 'X': {
                uint32_t x = va_arg(args, uint32_t);
                print_num(x, 16, true, false);
                count++;
                break;
            }
            case 'p': {
                uint32_t ptr = va_arg(args, uint32_t);
                uart_puts("0x");
                print_num(ptr, 16, false, false);
                count += 2;
                break;
            }
            case '%': {
                uart_putc('%');
                count++;
                break;
            }
            default: {
                uart_putc('%');
                uart_putc(*p);
                count += 2;
                break;
            }
        }
    }

    va_end(args);
    return count;
}

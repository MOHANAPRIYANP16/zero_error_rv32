#include "uart.h"

void uart_init(uint8_t baud_code)
{
    UART_REG_BAUD = (uint32_t)(baud_code & 0x07);
    UART_REG_STATUS_CLEAR = 0x01; // Clear any pending status
}

void uart_putc(char c)
{
    // Auto-convert LF to CRLF for standard serial terminals
    if (c == '\n') {
        while (UART_REG_STATUS & UART_STATUS_TX_BUSY)
            ;
        UART_REG_DATA = (uint32_t)'\r';
    }

    while (UART_REG_STATUS & UART_STATUS_TX_BUSY)
        ;
    UART_REG_DATA = (uint32_t)(uint8_t)c;
}

char uart_getc(void)
{
    while (!(UART_REG_STATUS & UART_STATUS_RX_VALID))
        ;
    return (char)(UART_REG_DATA & 0xFF);
}

bool uart_has_rx(void)
{
    return (UART_REG_STATUS & UART_STATUS_RX_VALID) != 0;
}

void uart_puts(const char *str)
{
    if (!str) return;
    while (*str) {
        uart_putc(*str++);
    }
}

void uart_clear_status(void)
{
    UART_REG_STATUS_CLEAR = 0x01;
}

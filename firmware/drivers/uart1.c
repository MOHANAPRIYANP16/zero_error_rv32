#include "uart1.h"
#include "kprintf.h"

void uart1_init(uint8_t baud_code)
{
    UART1_REG_BAUD = (uint32_t)(baud_code & 0x07);
    UART1_REG_STATUS_CLEAR = 0x03; // Clear status and flush FIFOs
}

void uart1_putc(uint8_t c)
{
    while (UART1_REG_STATUS & UART_STATUS_TX_FULL)
        ;
    UART1_REG_DATA = (uint32_t)c;
}

bool uart1_has_rx(void)
{
    return (UART1_REG_STATUS & UART_STATUS_RX_VALID) != 0;
}

uint8_t uart1_getc(void)
{
    while (!(UART1_REG_STATUS & UART_STATUS_RX_VALID))
        ;
    return (uint8_t)(UART1_REG_DATA & 0xFF);
}

int uart1_getc_timeout(uint8_t *c, uint32_t timeout_ms)
{
    // 25,000 cycles per ms in 25 MHz single-cycle RV32I core
    // Polling loop takes ~4 cycles per iteration -> ~6,250 iterations/ms
    uint32_t iterations = timeout_ms * 6250UL;

    while (iterations--) {
        if (UART1_REG_STATUS & UART_STATUS_RX_VALID) {
            *c = (uint8_t)(UART1_REG_DATA & 0xFF);
            return 0; // Success
        }
    }
    return -1; // Timeout
}

void uart1_flush_rx(void)
{
    while (UART1_REG_STATUS & UART_STATUS_RX_VALID) {
        (void)UART1_REG_DATA;
    }
}

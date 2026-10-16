#ifndef UART_H
#define UART_H

#include "../common/soc_regs.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Initialize UART with specified baud rate.
 * @param baud_code UART_BAUD_9600, UART_BAUD_19200, UART_BAUD_38400, UART_BAUD_57600, or UART_BAUD_115200.
 */
void uart_init(uint8_t baud_code);

/**
 * @brief Transmit a single character over UART (blocking until transmitter ready).
 * @param c Character to transmit.
 */
void uart_putc(char c);

/**
 * @brief Receive a single character over UART (blocking until byte received).
 * @return Received character.
 */
char uart_getc(void);

/**
 * @brief Check if a byte is available to read in the receiver buffer.
 * @return true if data available, false otherwise.
 */
bool uart_has_rx(void);

/**
 * @brief Transmit a null-terminated string over UART.
 * @param str Pointer to string.
 */
void uart_puts(const char *str);

/**
 * @brief Clear UART RX overflow and status flags.
 */
void uart_clear_status(void);

#ifdef __cplusplus
}
#endif

#endif // UART_H

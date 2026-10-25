#ifndef UART1_H
#define UART1_H

#include <stdint.h>
#include <stdbool.h>
#include "soc_regs.h"

#ifdef __cplusplus
extern "C" {
#endif

void    uart1_init(uint8_t baud_code);
void    uart1_putc(uint8_t c);
uint8_t uart1_getc(void);
int     uart1_getc_timeout(uint8_t *c, uint32_t timeout_ms);
bool    uart1_has_rx(void);
void    uart1_flush_rx(void);

#ifdef __cplusplus
}
#endif

#endif // UART1_H

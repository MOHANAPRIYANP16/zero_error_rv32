// ============================================================================
// main.c -- Resident UART Bootloader for Custom RV32I SoC
//
// Features:
//   1. Waits for upload from upload.py ('p' command) OR user execute ('e' command).
//   2. If 'e' or 'E' is pressed in serial terminal (PuTTY / miniterm):
//      - Jumps immediately to APP_BASE (0x0000_0200) and executes the application.
//   3. If 'p' or 'P' is received from upload.py:
//      - Reads 4-byte little-endian length N.
//      - Programs N bytes directly into Instruction Memory at APP_BASE.
//      - Sends 'K' acknowledgement byte back to host.
// ============================================================================

#define UART_DATA         (*(volatile unsigned int *)0x20000000)
#define UART_STATUS       (*(volatile unsigned int *)0x20000004)
#define UART_BAUD         (*(volatile unsigned int *)0x20000008)
#define UART_STATUS_CLEAR (*(volatile unsigned int *)0x2000000C)
#define LED_REG           (*(volatile unsigned int *)0x30000000)

// Application destination inside Instruction Memory
#define APP_BASE          ((volatile unsigned char *)0x00000200)

#define TX_BUSY           0x1
#define RX_VALID          0x2

typedef void (*app_entry_t)(void);

static unsigned char uart_getc(void)
{
    while (!(UART_STATUS & RX_VALID))
        ;
    return (unsigned char)(UART_DATA & 0xFF);
}

static void uart_putc(unsigned char c)
{
    while (UART_STATUS & TX_BUSY)
        ;
    UART_DATA = (unsigned int)c;
}

static void uart_puts(const char *s)
{
    while (*s) {
        if (*s == '\n')
            uart_putc('\r');
        uart_putc(*s++);
    }
}

int main(void)
{
    // Configure UART to 115200 baud and clear status
    UART_BAUD = 4;
    UART_STATUS_CLEAR = 1;

    // LED status: waiting for upload or execute
    LED_REG = 0x0001;

    uart_puts("\n[Boot] Press 'e' to run\n");

    while (1) {
        unsigned char c = uart_getc();

        // User command 'e' or 'E' in PuTTY / serial monitor -> Run app!
        if (c == 'e' || c == 'E') {
            uart_puts("Booting...\n\n");
            LED_REG = 0xFFFF;
            ((app_entry_t)APP_BASE)();
        }
        // Program command 'p' or 'P' from upload.py -> Flash application into RAM
        else if (c == 'p' || c == 'P') {
            LED_REG = 0x0003; // Receiving payload

            // Receive 4-byte little-endian length
            unsigned int len = 0;
            len |= (unsigned int)uart_getc();
            len |= (unsigned int)uart_getc() << 8;
            len |= (unsigned int)uart_getc() << 16;
            len |= (unsigned int)uart_getc() << 24;

            // Write bytes directly into Instruction Memory at APP_BASE
            volatile unsigned char *dst = APP_BASE;
            for (unsigned int i = 0; i < len; i++) {
                dst[i] = uart_getc();
            }

            LED_REG = 0x0001; // Back to waiting state
            uart_putc('K');   // Send ACK byte to upload script
        }
    }
}

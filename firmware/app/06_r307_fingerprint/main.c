#include <stdint.h>
#include <stdbool.h>
#include "soc_regs.h"
#include "kprintf.h"
#include "uart.h"
#include "uart1.h"
#include "gpio.h"
#include "r307.h"

static void led_auth_success(void)
{
    gpio_set_led(15, false); // Clear failure LED (LED15)
    gpio_set_led(14, true);  // Turn on success LED (LED14)
    delay_ms(800);
    gpio_set_led(14, false);
}

static void led_auth_failure(void)
{
    gpio_set_led(14, false); // Clear success LED (LED14)
    gpio_set_led(15, true);  // Turn on failure LED (LED15)
    delay_ms(800);
    gpio_set_led(15, false);
}

static uint16_t read_number(void)
{
    uint16_t val = 0;
    while (1) {
        char c = uart_getc();
        if (c == '\r' || c == '\n') {
            uart_putc('\n');
            break;
        }
        if (c >= '0' && c <= '9') {
            uart_putc(c);
            val = (uint16_t)(val * 10 + (c - '0'));
        }
    }
    return val;
}

static void show_sensor_status(void)
{
    uint16_t capacity = 0;
    uint16_t baud_multiplier = 0;

    int rc = r307_read_system_parameters(&capacity, &baud_multiplier);
    if (rc == R307_RESULT_OK) {
        kprintf("Sensor Status: ONLINE\n");
        kprintf("  Finger library capacity: %u\n", capacity);
        kprintf("  Configured baud:         %u bps (N=%u)\n", (uint32_t)baud_multiplier * 9600UL, baud_multiplier);
    } else {
        kprintf("Sensor Status: ERROR (%s)\n", r307_error_string(rc));
    }
}

int main(void)
{
    // 1. Initialize UART0 (PC USB-UART Console) @ 115200 baud
    uart_init(UART_BAUD_115200);

    // 2. Turn off all 16 LEDs (clears the 0xFFFF bootloader banner)
    gpio_set_leds(0x0000);

    // 3. Initialize UART1 (R307 Fingerprint Sensor on Pmod A) @ 57600 baud
    uart1_init(R307_BAUD_CODE);

    kprintf("\n");
    kprintf("========================================\n");
    kprintf("   RV32I R307 Fingerprint System       \n");
    kprintf("   UART0: PC Console (115200 baud)     \n");
    kprintf("   UART1: R307 Sensor (57600 baud)     \n");
    kprintf("========================================\n");

    // Allow sensor to power up internal DSP (250 ms)
    kprintf("Initializing sensor connection...\n");
    delay_ms(250);

    // Verify handshake password
    int pwd_status = r307_verify_password(0x00000000UL);
    if (pwd_status == R307_RESULT_OK) {
        kprintf("Sensor handshake: SUCCESS (password verified)\n");
        led_auth_success();
    } else {
        kprintf("Sensor handshake: %s\n", r307_error_string(pwd_status));
        led_auth_failure();
    }

    for (;;) {
        kprintf("\n============================\n");
        kprintf("   R307 Fingerprint Menu    \n");
        kprintf("============================\n");
        kprintf("e - Enroll new fingerprint\n");
        kprintf("a - Authenticate fingerprint\n");
        kprintf("d - Delete fingerprint ID\n");
        kprintf("c - Clear entire database\n");
        kprintf("s - Sensor status\n\n");
        kprintf("CMD> ");

        char cmd = uart_getc();
        uart_putc(cmd);
        kprintf("\n\n");

        if (cmd == 'e' || cmd == 'E') {
            kprintf("Enter ID to enroll (0-999): ");
            uint16_t id = read_number();
            kprintf("Enrolling ID %u...\n", id);

            int rc = r307_enroll(id);
            if (rc == R307_RESULT_OK) {
                led_auth_success();
            } else {
                led_auth_failure();
            }
        } else if (cmd == 'a' || cmd == 'A') {
            kprintf("Authenticating...\n");
            uint16_t matched_id = 0;
            uint16_t match_score = 0;

            r307_verify_result_t res = r307_verify(0, 1000, &matched_id, &match_score);
            if (res == R307_VERIFY_MATCH) {
                kprintf("AUTHENTICATION SUCCESS\n");
                kprintf("  Matched ID:    %u\n", matched_id);
                kprintf("  Match Score:   %u\n", match_score);
                led_auth_success();
            } else if (res == R307_VERIFY_NO_MATCH) {
                kprintf("AUTHENTICATION FAILED: No match found\n");
                led_auth_failure();
            } else if (res == R307_VERIFY_TIMEOUT) {
                kprintf("AUTHENTICATION FAILED: Timeout waiting for finger\n");
                led_auth_failure();
            } else {
                kprintf("AUTHENTICATION FAILED: Sensor error\n");
                led_auth_failure();
            }
        } else if (cmd == 'd' || cmd == 'D') {
            kprintf("Enter ID to delete (0-999): ");
            uint16_t id = read_number();
            int rc = r307_delete(id, 1);
            if (rc == R307_RESULT_OK) {
                kprintf("Fingerprint ID %u deleted.\n", id);
                led_auth_success();
            } else {
                kprintf("Delete failed: %s\n", r307_error_string(rc));
                led_auth_failure();
            }
        } else if (cmd == 'c' || cmd == 'C') {
            kprintf("Clear entire fingerprint database? (y/n): ");
            char confirm = uart_getc();
            uart_putc(confirm);
            kprintf("\n");
            if (confirm == 'y' || confirm == 'Y') {
                int rc = r307_empty_database();
                if (rc == R307_RESULT_OK) {
                    kprintf("Database successfully cleared.\n");
                    led_auth_success();
                } else {
                    kprintf("Clear database failed: %s\n", r307_error_string(rc));
                    led_auth_failure();
                }
            } else {
                kprintf("Operation cancelled.\n");
            }
        } else if (cmd == 's' || cmd == 'S') {
            show_sensor_status();
        } else {
            kprintf("Unknown command '%c'. Valid options: e, a, d, c, s\n", cmd);
        }
    }

    return 0;
}

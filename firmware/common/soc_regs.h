#ifndef SOC_REGS_H
#define SOC_REGS_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// ============================================================================
// SoC Memory & System Configuration
// Clock: 25.0 MHz (Real Digital Boolean FPGA board MMCM output)
// ============================================================================
#define SOC_CLOCK_FREQ_HZ       25000000UL
#define SOC_CYCLES_PER_MS       (SOC_CLOCK_FREQ_HZ / 1000UL)
#define SOC_CYCLES_PER_US       (SOC_CLOCK_FREQ_HZ / 1000000UL)

// Memory Map Base Addresses
#define CODE_RAM_BASE           0x00000000UL // 4 KB Instruction / Code RAM
#define DATA_RAM_BASE           0x10000000UL // 8 KB Scratchpad / Data RAM
#define DATA_RAM_SIZE           0x00002000UL // 8192 Bytes
#define STACK_TOP               (DATA_RAM_BASE + DATA_RAM_SIZE)

#define UART_BASE               0x20000000UL // Configurable UART
#define GPIO_BASE               0x30000000UL // 16-bit LED / Input GPIO
#define I2C_BASE                0x40000000UL // I2C Master Controller

// ============================================================================
// UART Register Map (Base: 0x2000_0000)
// ============================================================================
#define UART_REG_DATA           (*(volatile uint32_t *)(UART_BASE + 0x00))
#define UART_REG_STATUS         (*(volatile uint32_t *)(UART_BASE + 0x04))
#define UART_REG_BAUD           (*(volatile uint32_t *)(UART_BASE + 0x08))
#define UART_REG_STATUS_CLEAR   (*(volatile uint32_t *)(UART_BASE + 0x0C))

// UART Status Bits
#define UART_STATUS_TX_BUSY     (1UL << 0) // 1: Transmitter busy
#define UART_STATUS_RX_VALID    (1UL << 1) // 1: Byte available in RX buffer
#define UART_STATUS_RX_OVERFLOW (1UL << 2) // 1: Byte overwritten before read

// UART Baud Selection Codes
#define UART_BAUD_9600          0
#define UART_BAUD_19200         1
#define UART_BAUD_38400         2
#define UART_BAUD_57600         3
#define UART_BAUD_115200        4

// ============================================================================
// GPIO Register Map (Base: 0x3000_0000)
// ============================================================================
#define GPIO_REG_DATA_OUT       (*(volatile uint32_t *)(GPIO_BASE + 0x00)) // [15:0] drives 16 LEDs
#define GPIO_REG_DATA_IN        (*(volatile uint32_t *)(GPIO_BASE + 0x04)) // [15:0] reads inputs
#define GPIO_REG_DIR            (*(volatile uint32_t *)(GPIO_BASE + 0x08)) // Direction register

// ============================================================================
// I2C Register Map (Base: 0x4000_0000)
// ============================================================================
#define I2C_REG_CTRL_STATUS     (*(volatile uint32_t *)(I2C_BASE + 0x00))
#define I2C_REG_SLV_ADDR        (*(volatile uint32_t *)(I2C_BASE + 0x04))
#define I2C_REG_REG_ADDR        (*(volatile uint32_t *)(I2C_BASE + 0x08))
#define I2C_REG_WR_DATA         (*(volatile uint32_t *)(I2C_BASE + 0x0C))
#define I2C_REG_BYTE_CNT        (*(volatile uint32_t *)(I2C_BASE + 0x10))
#define I2C_REG_CONFIG          (*(volatile uint32_t *)(I2C_BASE + 0x14))
#define I2C_REG_RD_DATA0        (*(volatile uint32_t *)(I2C_BASE + 0x20))
#define I2C_REG_RD_DATA1        (*(volatile uint32_t *)(I2C_BASE + 0x24))
#define I2C_REG_RD_DATA2        (*(volatile uint32_t *)(I2C_BASE + 0x28))
#define I2C_REG_RD_DATA3        (*(volatile uint32_t *)(I2C_BASE + 0x2C))

// I2C Control / Status Bits
#define I2C_CTRL_START          (1UL << 0) // Write 1 to start transaction
#define I2C_STATUS_DONE         (1UL << 0) // Read 1: Transaction finished
#define I2C_STATUS_BUSY         (1UL << 1) // Read 1: Controller currently busy
#define I2C_STATUS_ERR          (1UL << 2) // Read 1: NACK or bus error detected

// I2C Configuration Speed Modes
#define I2C_SPEED_FAST_400K     0
#define I2C_SPEED_STD_100K      1

// I2C Read/Write Direction Bit
#define I2C_DIR_WRITE           0
#define I2C_DIR_READ            1

#ifdef __cplusplus
}
#endif

#endif // SOC_REGS_H

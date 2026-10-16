#ifndef I2C_H
#define I2C_H

#include "../common/soc_regs.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Initialize I2C controller clock speed.
 * @param speed_mode I2C_SPEED_STD_100K (100 kHz) or I2C_SPEED_FAST_400K (400 kHz).
 */
void i2c_init(uint8_t speed_mode);

/**
 * @brief Write a single byte to an I2C slave's internal register.
 * @param dev_addr 7-bit slave device address (0x00 to 0x7F).
 * @param reg_addr Target register address in the slave device.
 * @param data Data byte to write.
 * @return true if successful (ACK received), false if NACK/error occurred.
 */
bool i2c_write_reg(uint8_t dev_addr, uint8_t reg_addr, uint8_t data);

/**
 * @brief Read a single byte from an I2C slave's internal register.
 * @param dev_addr 7-bit slave device address.
 * @param reg_addr Target register address.
 * @param data_out Pointer to receive the read byte.
 * @return true if successful, false on error.
 */
bool i2c_read_reg(uint8_t dev_addr, uint8_t reg_addr, uint8_t *data_out);

/**
 * @brief Read multiple consecutive bytes (up to 4 bytes) from an I2C slave.
 * @param dev_addr 7-bit slave device address.
 * @param reg_addr Starting register address.
 * @param buffer Pointer to byte buffer (must have at least count bytes).
 * @param count Number of bytes to read (1 to 4).
 * @return true if successful, false on error.
 */
bool i2c_read_burst(uint8_t dev_addr, uint8_t reg_addr, uint8_t *buffer, uint8_t count);

/**
 * @brief Probe/Ping an I2C slave device to verify presence on the bus.
 * @param dev_addr 7-bit slave address.
 * @return true if device acknowledged, false if no ACK received.
 */
bool i2c_ping(uint8_t dev_addr);

#ifdef __cplusplus
}
#endif

#endif // I2C_H

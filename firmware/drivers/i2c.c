#include "i2c.h"

void i2c_init(uint8_t speed_mode)
{
    I2C_REG_CONFIG = (uint32_t)(speed_mode & 0x01);
}

static bool i2c_wait_completion(void)
{
    // Wait for the hardware controller to latch start command and assert BUSY
    uint32_t timeout = 50000;
    while (!(I2C_REG_CTRL_STATUS & I2C_STATUS_BUSY) && --timeout)
        ;

    // Wait until controller finishes transaction and deasserts BUSY
    timeout = 500000;
    while ((I2C_REG_CTRL_STATUS & I2C_STATUS_BUSY) && --timeout)
        ;

    if (timeout == 0) {
        return false; // Bus timeout (e.g. clock held low or disconnect)
    }

    uint32_t status = I2C_REG_CTRL_STATUS;
    if (status & I2C_STATUS_ERR) {
        return false;
    }
    return (status & I2C_STATUS_DONE) != 0;
}

bool i2c_write_reg(uint8_t dev_addr, uint8_t reg_addr, uint8_t data)
{
    // Set 7-bit slave address with RWbar = 0 (write)
    I2C_REG_SLV_ADDR = (uint32_t)((dev_addr << 1) | I2C_DIR_WRITE);
    I2C_REG_REG_ADDR = (uint32_t)reg_addr;
    I2C_REG_WR_DATA  = (uint32_t)data;

    // Trigger start
    I2C_REG_CTRL_STATUS = I2C_CTRL_START;

    return i2c_wait_completion();
}

bool i2c_read_reg(uint8_t dev_addr, uint8_t reg_addr, uint8_t *data_out)
{
    if (!data_out) return false;

    // Set 7-bit slave address with RWbar = 1 (read)
    I2C_REG_SLV_ADDR = (uint32_t)((dev_addr << 1) | I2C_DIR_READ);
    I2C_REG_REG_ADDR = (uint32_t)reg_addr;
    I2C_REG_BYTE_CNT = 1; // 1 byte

    // Trigger start
    I2C_REG_CTRL_STATUS = I2C_CTRL_START;

    if (!i2c_wait_completion()) {
        return false;
    }

    *data_out = (uint8_t)(I2C_REG_RD_DATA0 & 0xFF);
    return true;
}

bool i2c_read_burst(uint8_t dev_addr, uint8_t reg_addr, uint8_t *buffer, uint8_t count)
{
    if (!buffer || count == 0 || count > 4) return false;

    I2C_REG_SLV_ADDR = (uint32_t)((dev_addr << 1) | I2C_DIR_READ);
    I2C_REG_REG_ADDR = (uint32_t)reg_addr;
    I2C_REG_BYTE_CNT = (uint32_t)count;

    I2C_REG_CTRL_STATUS = I2C_CTRL_START;

    if (!i2c_wait_completion()) {
        return false;
    }

    if (count >= 1) buffer[0] = (uint8_t)(I2C_REG_RD_DATA0 & 0xFF);
    if (count >= 2) buffer[1] = (uint8_t)(I2C_REG_RD_DATA1 & 0xFF);
    if (count >= 3) buffer[2] = (uint8_t)(I2C_REG_RD_DATA2 & 0xFF);
    if (count >= 4) buffer[3] = (uint8_t)(I2C_REG_RD_DATA3 & 0xFF);

    return true;
}

bool i2c_ping(uint8_t dev_addr)
{
    uint8_t dummy;
    // 1. Standard register-based read probe (MPU-6050, BMP280, RTC, EEPROM, etc.)
    if (i2c_read_reg(dev_addr, 0x00, &dummy)) {
        return true;
    }

    // 2. Sensirion SHTC3 (0x70): Powers up in deep sleep mode and uses 16-bit commands.
    // It will NACK register reads until woken up with command 0x3517.
    if (dev_addr == 0x70) {
        if (i2c_write_reg(0x70, 0x35, 0x17)) {
            return true;
        }
    }

    return false;
}

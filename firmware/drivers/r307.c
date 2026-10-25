#include "r307.h"
#include "uart1.h"
#include "kprintf.h"

#define R307_PACKET_TIMEOUT_MS 1000UL
#define R307_FINGER_TIMEOUT_MS 15000UL

static uint16_t calc_checksum(const uint8_t *data, uint16_t len) {
    uint16_t sum = 0;
    for (uint16_t i = 0; i < len; i++) {
        sum = (uint16_t)(sum + data[i]);
    }
    return sum;
}

static void write_u16_be(uint8_t *p, uint16_t val) {
    p[0] = (uint8_t)(val >> 8);
    p[1] = (uint8_t)(val & 0xFF);
}

static uint16_t read_u16_be(const uint8_t *p) {
    return (uint16_t)(((uint16_t)p[0] << 8) | (uint16_t)p[1]);
}

int r307_send_command(uint8_t command, const uint8_t *parameters, uint16_t parameter_length) {
    uint8_t frame[80];
    uint16_t content_length = (uint16_t)(1 + parameter_length);
    uint16_t package_length = (uint16_t)(content_length + 2);
    uint16_t frame_len = (uint16_t)(9 + package_length);

    if (content_length > 64) {
        return R307_RESULT_PACKET;
    }

    /* Header */
    frame[0] = 0xEF;
    frame[1] = 0x01;
    /* Default Address */
    frame[2] = 0xFF;
    frame[3] = 0xFF;
    frame[4] = 0xFF;
    frame[5] = 0xFF;
    /* PID */
    frame[6] = R307_PID_COMMAND;
    /* Length */
    write_u16_be(&frame[7], package_length);
    /* Content: Instruction Code */
    frame[9] = command;
    /* Content: Parameters */
    for (uint16_t i = 0; i < parameter_length; i++) {
        frame[10 + i] = parameters[i];
    }
    /* Checksum: PID + Length + Content */
    uint16_t csum = calc_checksum(&frame[6], (uint16_t)(3 + content_length));
    write_u16_be(&frame[10 + parameter_length], csum);

    /* Send out over UART1 */
    for (uint16_t i = 0; i < frame_len; i++) {
        uart1_putc(frame[i]);
    }

    return R307_RESULT_OK;
}

int r307_receive_packet(r307_packet_t *packet, uint32_t timeout_ms) {
    uint8_t raw[80];
    uint8_t c;

    /* Wait for start of header 0xEF */
    for (;;) {
        if (uart1_getc_timeout(&c, timeout_ms) != 0) {
            return R307_RESULT_TIMEOUT;
        }
        if (c == 0xEF) {
            break;
        }
    }
    raw[0] = c;

    /* Read header second byte (0x01) + address (4 bytes) + PID (1 byte) + Length (2 bytes) = 8 bytes */
    for (uint16_t i = 1; i < 9; i++) {
        if (uart1_getc_timeout(&raw[i], timeout_ms) != 0) {
            return R307_RESULT_TIMEOUT;
        }
    }

    /* Validate header second byte */
    if (raw[1] != 0x01) {
        return R307_RESULT_PACKET;
    }

    /* Validate address (0xFFFFFFFF) */
    if (raw[2] != 0xFF || raw[3] != 0xFF || raw[4] != 0xFF || raw[5] != 0xFF) {
        return R307_RESULT_PACKET;
    }

    uint16_t package_length = read_u16_be(&raw[7]);
    if (package_length < 2 || package_length > 66) {
        return R307_RESULT_PACKET;
    }

    uint16_t data_length = (uint16_t)(package_length - 2);

    /* Read data payload + 2 checksum bytes */
    for (uint16_t i = 0; i < package_length; i++) {
        if (uart1_getc_timeout(&raw[9 + i], timeout_ms) != 0) {
            return R307_RESULT_TIMEOUT;
        }
    }

    uint16_t received_sum = read_u16_be(&raw[9 + data_length]);
    uint16_t calculated_sum = calc_checksum(&raw[6], (uint16_t)(3 + data_length));

    if (received_sum != calculated_sum) {
        return R307_RESULT_CHECKSUM;
    }

    packet->pid = raw[6];
    packet->length = data_length;
    for (uint16_t i = 0; i < data_length; i++) {
        packet->data[i] = raw[9 + i];
    }

    return R307_RESULT_OK;
}

int r307_get_ack(r307_packet_t *packet, uint32_t timeout_ms) {
    int rc = r307_receive_packet(packet, timeout_ms);
    if (rc != R307_RESULT_OK) {
        return rc;
    }
    if (packet->pid != R307_PID_ACK || packet->length < 1) {
        return R307_RESULT_PACKET;
    }
    return (packet->data[0] == R307_ACK_OK) ? R307_RESULT_OK : (int)packet->data[0];
}

static int send_and_wait_ack(uint8_t cmd, const uint8_t *params, uint16_t param_len, r307_packet_t *ack) {
    uart1_flush_rx();
    int rc = r307_send_command(cmd, params, param_len);
    if (rc != R307_RESULT_OK) {
        return rc;
    }
    return r307_get_ack(ack, R307_PACKET_TIMEOUT_MS);
}

int r307_verify_password(uint32_t password) {
    uint8_t p[4];
    p[0] = (uint8_t)(password >> 24);
    p[1] = (uint8_t)(password >> 16);
    p[2] = (uint8_t)(password >> 8);
    p[3] = (uint8_t)(password);

    r307_packet_t ack;
    int rc = send_and_wait_ack(0x13, p, 4, &ack);
    if (rc == R307_ACK_WRONG_PWD && password == 0xFFFFFFFFUL) {
        /* Fallback: try default 0x00000000 */
        uint8_t p_zero[4] = {0, 0, 0, 0};
        rc = send_and_wait_ack(0x13, p_zero, 4, &ack);
    }
    return rc;
}

int r307_get_image(void) {
    r307_packet_t ack;
    return send_and_wait_ack(0x01, 0, 0, &ack);
}

int r307_image_to_tz(uint8_t buffer_id) {
    r307_packet_t ack;
    return send_and_wait_ack(0x02, &buffer_id, 1, &ack);
}

int r307_generate_template(void) {
    r307_packet_t ack;
    return send_and_wait_ack(0x05, 0, 0, &ack);
}

int r307_store_template(uint8_t buffer_id, uint16_t id) {
    uint8_t p[3];
    p[0] = buffer_id;
    p[1] = (uint8_t)(id >> 8);
    p[2] = (uint8_t)(id & 0xFF);
    r307_packet_t ack;
    return send_and_wait_ack(0x06, p, 3, &ack);
}

int r307_search(uint8_t buffer_id, uint16_t start_id, uint16_t count, uint16_t *matched_id, uint16_t *score) {
    uint8_t p[5];
    p[0] = buffer_id;
    p[1] = (uint8_t)(start_id >> 8);
    p[2] = (uint8_t)(start_id & 0xFF);
    p[3] = (uint8_t)(count >> 8);
    p[4] = (uint8_t)(count & 0xFF);

    r307_packet_t ack;
    int rc = send_and_wait_ack(0x04, p, 5, &ack);
    if (rc != R307_RESULT_OK) {
        return rc;
    }
    if (ack.length < 5) {
        return R307_RESULT_PACKET;
    }
    if (matched_id) {
        *matched_id = read_u16_be(&ack.data[1]);
    }
    if (score) {
        *score = read_u16_be(&ack.data[3]);
    }
    return R307_RESULT_OK;
}

int r307_delete(uint16_t id, uint16_t count) {
    uint8_t p[4];
    p[0] = (uint8_t)(id >> 8);
    p[1] = (uint8_t)(id & 0xFF);
    p[2] = (uint8_t)(count >> 8);
    p[3] = (uint8_t)(count & 0xFF);
    r307_packet_t ack;
    return send_and_wait_ack(0x0C, p, 4, &ack);
}

int r307_empty_database(void) {
    r307_packet_t ack;
    return send_and_wait_ack(0x0D, 0, 0, &ack);
}

int r307_read_system_parameters(uint16_t *capacity, uint16_t *baud_multiplier) {
    r307_packet_t ack;
    int rc = send_and_wait_ack(0x0F, 0, 0, &ack);
    if (rc != R307_RESULT_OK) {
        return rc;
    }
    if (ack.length < 17) {
        return R307_RESULT_PACKET;
    }
    if (capacity) {
        *capacity = read_u16_be(&ack.data[5]);
    }
    if (baud_multiplier) {
        *baud_multiplier = read_u16_be(&ack.data[15]);
    }
    return R307_RESULT_OK;
}

static int wait_for_finger_press(const char *prompt) {
    uint32_t start_ms = 0;
    kprintf("%s\n", prompt);
    while (start_ms < R307_FINGER_TIMEOUT_MS) {
        int rc = r307_get_image();
        if (rc == R307_ACK_OK) {
            kprintf("Finger detected\n");
            return R307_RESULT_OK;
        }
        if (rc != R307_ACK_NO_FINGER && rc != R307_RESULT_TIMEOUT) {
            return rc;
        }
        delay_ms(50);
        start_ms += 50;
    }
    return R307_RESULT_TIMEOUT;
}

static int wait_for_finger_release(void) {
    uint32_t start_ms = 0;
    kprintf("Remove finger\n");
    while (start_ms < R307_FINGER_TIMEOUT_MS) {
        int rc = r307_get_image();
        if (rc == R307_ACK_NO_FINGER) {
            return R307_RESULT_OK;
        }
        if (rc != R307_ACK_OK && rc != R307_RESULT_TIMEOUT) {
            return rc;
        }
        delay_ms(50);
        start_ms += 50;
    }
    return R307_RESULT_TIMEOUT;
}

int r307_enroll(uint16_t id) {
    int rc;

    /* Step 1: Wait for finger */
    rc = wait_for_finger_press("Place finger on sensor...");
    if (rc != R307_RESULT_OK) {
        kprintf("Enrollment failed: %s\n", r307_error_string(rc));
        return rc;
    }
    kprintf("Image captured\n");

    /* Step 2: Convert image to template buffer 1 */
    rc = r307_image_to_tz(1);
    if (rc != R307_RESULT_OK) {
        kprintf("Enrollment failed: %s\n", r307_error_string(rc));
        return rc;
    }

    /* Step 3: Wait for finger removal */
    rc = wait_for_finger_release();
    if (rc != R307_RESULT_OK) {
        kprintf("Enrollment failed: %s\n", r307_error_string(rc));
        return rc;
    }

    /* Step 4: Wait for finger again */
    rc = wait_for_finger_press("Place same finger again...");
    if (rc != R307_RESULT_OK) {
        kprintf("Enrollment failed: %s\n", r307_error_string(rc));
        return rc;
    }
    kprintf("Second image captured\n");

    /* Step 5: Convert image to template buffer 2 */
    rc = r307_image_to_tz(2);
    if (rc != R307_RESULT_OK) {
        kprintf("Enrollment failed: %s\n", r307_error_string(rc));
        return rc;
    }

    /* Step 6: Generate template */
    rc = r307_generate_template();
    if (rc != R307_RESULT_OK) {
        kprintf("Enrollment failed: %s\n", r307_error_string(rc));
        return rc;
    }
    kprintf("Template generated\n");

    /* Step 7: Store template at ID */
    rc = r307_store_template(1, id);
    if (rc != R307_RESULT_OK) {
        kprintf("Enrollment failed: %s\n", r307_error_string(rc));
        return rc;
    }
    kprintf("Fingerprint stored at ID %u\n", id);
    kprintf("Enrollment successful!\n");

    (void)wait_for_finger_release();
    return R307_RESULT_OK;
}

r307_verify_result_t r307_verify(uint16_t start_id, uint16_t count, uint16_t *matched_id, uint16_t *score) {
    int rc = wait_for_finger_press("Place finger to authenticate...");
    if (rc == R307_RESULT_TIMEOUT) {
        return R307_VERIFY_TIMEOUT;
    }
    if (rc != R307_RESULT_OK) {
        return R307_VERIFY_SENSOR_ERROR;
    }

    rc = r307_image_to_tz(1);
    if (rc != R307_RESULT_OK) {
        return R307_VERIFY_SENSOR_ERROR;
    }

    rc = r307_search(1, start_id, count, matched_id, score);
    (void)wait_for_finger_release();

    if (rc == R307_RESULT_OK) {
        return R307_VERIFY_MATCH;
    }
    if (rc == R307_ACK_NO_MATCH || rc == R307_ACK_NOT_MATCH) {
        return R307_VERIFY_NO_MATCH;
    }
    if (rc == R307_RESULT_TIMEOUT) {
        return R307_VERIFY_TIMEOUT;
    }
    return R307_VERIFY_SENSOR_ERROR;
}

const char *r307_error_string(int code) {
    switch (code) {
        case R307_RESULT_OK:        return "OK";
        case R307_RESULT_TIMEOUT:   return "UART1 timeout";
        case R307_RESULT_PACKET:    return "Invalid packet length or header";
        case R307_RESULT_CHECKSUM:  return "Checksum error";
        case R307_ACK_PACKET_ERR:   return "Sensor communication error";
        case R307_ACK_NO_FINGER:    return "Finger not found";
        case R307_ACK_ENROLL_FAIL:  return "Fail to enroll";
        case R307_ACK_DISORDER_IMG: return "Disorderly fingerprint image";
        case R307_ACK_LACK_POINTS:  return "Fingerprint image too small";
        case R307_ACK_NOT_MATCH:    return "Finger does not match";
        case R307_ACK_NO_MATCH:     return "No match";
        case R307_ACK_COMBINE_FAIL: return "Finger mismatch";
        case R307_ACK_BAD_PAGE_ID:  return "PageID out of range";
        case R307_ACK_READ_ERR:     return "Template read error";
        case R307_ACK_DELETE_FAIL:  return "Fail to delete template";
        case R307_ACK_CLEAR_FAIL:   return "Fail to clear database";
        case R307_ACK_WRONG_PWD:    return "Wrong password";
        case R307_ACK_FLASH_ERR:    return "Flash write error";
        default:                    return "Sensor ACK error";
    }
}

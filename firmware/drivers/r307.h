#ifndef R307_H
#define R307_H

#include <stdint.h>
#include <stdbool.h>

/** R307 Default Address & Baud Selection */
#define R307_DEFAULT_ADDRESS     0xFFFFFFFFUL
#define R307_BAUD_CODE           3 /* UART_BAUD_57600 */

/** R307 Packet Identifiers (PID) */
#define R307_PID_COMMAND         0x01
#define R307_PID_DATA            0x02
#define R307_PID_ACK             0x07
#define R307_PID_END_DATA        0x08

/** R307 Confirmation Codes (ACK byte 0) */
#define R307_ACK_OK              0x00
#define R307_ACK_PACKET_ERR      0x01
#define R307_ACK_NO_FINGER       0x02
#define R307_ACK_ENROLL_FAIL     0x03
#define R307_ACK_DISORDER_IMG    0x06
#define R307_ACK_LACK_POINTS     0x07
#define R307_ACK_NOT_MATCH       0x08
#define R307_ACK_NO_MATCH        0x09
#define R307_ACK_COMBINE_FAIL    0x0A  /* Finger mismatch */
#define R307_ACK_BAD_PAGE_ID     0x0B
#define R307_ACK_READ_ERR        0x0C
#define R307_ACK_DELETE_FAIL     0x10
#define R307_ACK_CLEAR_FAIL      0x11
#define R307_ACK_WRONG_PWD       0x13
#define R307_ACK_FLASH_ERR       0x18

/** Driver Result Codes */
typedef enum {
    R307_RESULT_OK        =  0,
    R307_RESULT_TIMEOUT   = -1,
    R307_RESULT_PACKET    = -2,
    R307_RESULT_CHECKSUM  = -3,
    R307_RESULT_ACK       = -4
} r307_result_t;

/** Verification Results */
typedef enum {
    R307_VERIFY_MATCH        = 0,
    R307_VERIFY_NO_MATCH     = 1,
    R307_VERIFY_SENSOR_ERROR = 2,
    R307_VERIFY_TIMEOUT      = 3
} r307_verify_result_t;

/** Packet Structure */
typedef struct {
    uint8_t  pid;
    uint16_t length;
    uint8_t  data[64];
} r307_packet_t;

/** Low-level Packet Protocol */
int r307_send_command(uint8_t command, const uint8_t *parameters, uint16_t parameter_length);
int r307_receive_packet(r307_packet_t *packet, uint32_t timeout_ms);
int r307_get_ack(r307_packet_t *packet, uint32_t timeout_ms);

/** Core R307 Commands */
int r307_verify_password(uint32_t password);
int r307_get_image(void);
int r307_image_to_tz(uint8_t buffer_id);
int r307_generate_template(void);
int r307_store_template(uint8_t buffer_id, uint16_t id);
int r307_search(uint8_t buffer_id, uint16_t start_id, uint16_t count, uint16_t *matched_id, uint16_t *score);
int r307_delete(uint16_t id, uint16_t count);
int r307_empty_database(void);
int r307_read_system_parameters(uint16_t *capacity, uint16_t *baud_multiplier);

/** High-level Operations */
int r307_enroll(uint16_t id);
r307_verify_result_t r307_verify(uint16_t start_id, uint16_t count, uint16_t *matched_id, uint16_t *score);

/** Diagnostic Utilities */
const char *r307_error_string(int code);

#endif /* R307_H */

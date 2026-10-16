/* ============================================================================
 * start.s -- Minimal Resident Bootloader Startup Code for Custom RV32I SoC
 *
 * Bootloader starts at 0x0000_0000 upon reset.
 * Sets the stack pointer to the top of 8 KB Data RAM (0x1000_1FFC) and jumps to main().
 * ============================================================================ */

    .section .text
    .global _start
    .type _start, @function

_start:
    /* Set stack pointer to top of Data RAM (0x1000_2000) */
    la   sp, 0x10001ffc
    call main

hang:
    j    hang

    .size _start, . - _start

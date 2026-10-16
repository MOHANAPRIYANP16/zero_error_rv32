/* ============================================================================
 * startup.S -- Bare-Metal Startup Code for Custom RV32I Processor
 *
 * Execution starts at 0x0000_0000 upon system reset.
 * 1. Sets stack pointer (SP) to top of 8 KB Data RAM (0x1000_2000).
 * 2. Clears the .bss segment.
 * 3. Copies initialized .data segment from ROM to RAM.
 * 4. Calls main().
 * 5. Traps into an infinite loop if main() ever returns.
 * ============================================================================ */

    .section .text.init
    .global _start
    .type _start, @function

_start:
    /* Disable interrupts / setup stack pointer at top of Data RAM */
    la   sp, _stack_top

    /* Zero out the .bss section */
    la   a0, _sbss
    la   a1, _ebss
    bge  a0, a1, 2f
1:
    sw   zero, 0(a0)
    addi a0, a0, 4
    blt  a0, a1, 1b
2:

    /* Copy initialized .data section from Code ROM (LMA) to Data RAM (VMA) */
    la   a0, _sdata
    la   a1, _edata
    la   a2, _sidata
    bge  a0, a1, 4f
3:
    lw   t0, 0(a2)
    sw   t0, 0(a0)
    addi a0, a0, 4
    addi a2, a2, 4
    blt  a0, a1, 3b
4:

    /* Call application entry point */
    call main

    /* Trap loop if main() exits */
hang:
    j    hang

    .size _start, . - _start

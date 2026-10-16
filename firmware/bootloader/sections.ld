/* ============================================================================
 * sections.ld -- Linker Script for Resident RV32I Bootloader
 *
 * Placed at the base of Instruction Memory (0x0000_0000).
 * Maximum size: 512 bytes (128 words).
 * The user application area begins immediately at 0x0000_0200.
 * ============================================================================ */

ENTRY(_start)

MEMORY
{
    ROM (rx) : ORIGIN = 0x00000000, LENGTH = 512
}

SECTIONS
{
    . = 0x00000000;

    .text : {
        . = ALIGN(4);
        *(.text*)
        *(.rodata*)
        . = ALIGN(4);
    } > ROM

    .data : {
        . = ALIGN(4);
        *(.data*)
        . = ALIGN(4);
    } > ROM

    .bss : {
        . = ALIGN(4);
        *(.bss*)
        *(COMMON)
        . = ALIGN(4);
    } > ROM

    /DISCARD/ : {
        *(.comment)
        *(.note*)
        *(.eh_frame*)
    }
}

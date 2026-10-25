/* ============================================================================
 * linker.ld -- Memory Linker Script for Custom RV32I SoC (16 KB Code RAM)
 *
 * Memory Map:
 *   ROM (Code RAM) : 0x0000_0000 to 0x0000_3FFF (16 KB, 4096 words)
 *   RAM (Data RAM) : 0x1000_0000 to 0x1000_1FFF (8 KB, 2048 words)
 * ============================================================================ */

ENTRY(_start)

MEMORY
{
    ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 16K
    RAM (rwx) : ORIGIN = 0x10000000, LENGTH = 8K
}

_stack_top = ORIGIN(RAM) + LENGTH(RAM);

SECTIONS
{
    .text : {
        . = ALIGN(4);
        KEEP(*(.text.init))
        *(.text*)
        *(.gnu.linkonce.t.*)
        . = ALIGN(4);
    } > ROM

    .rodata : {
        . = ALIGN(4);
        *(.rodata*)
        *(.gnu.linkonce.r.*)
        *(.srodata*)
        . = ALIGN(4);
    } > ROM

    _sidata = LOADADDR(.data);

    .data : {
        . = ALIGN(4);
        _sdata = .;
        *(.data*)
        *(.gnu.linkonce.d.*)
        *(.sdata*)
        . = ALIGN(4);
        _edata = .;
    } > RAM AT > ROM

    .bss (NOLOAD) : {
        . = ALIGN(4);
        _sbss = .;
        *(.bss*)
        *(.gnu.linkonce.b.*)
        *(.sbss*)
        *(COMMON)
        . = ALIGN(4);
        _ebss = .;
    } > RAM

    /DISCARD/ : {
        *(.comment)
        *(.note*)
        *(.eh_frame*)
    }
}

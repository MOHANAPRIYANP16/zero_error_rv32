/* ============================================================================
 * linker_boot_app.ld -- Linker Script for Applications Uploaded via Bootloader
 *
 * Placed in Instruction Memory starting at APP_BASE (0x0000_0200).
 * Maximum Code size: 3584 bytes (896 words).
 * Data RAM: 8 KB (0x1000_0000 to 0x1000_1FFF).
 * ============================================================================ */

ENTRY(_start)

MEMORY
{
    ROM (rx)  : ORIGIN = 0x00000200, LENGTH = 3584
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

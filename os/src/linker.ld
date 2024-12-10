__stack_size = 4K;
ENTRY(_start)

SECTIONS
{
    .text : ALIGN(16) {
        *(.text)
    }

    .rodata ALIGN(16) :
    {
        *(.rodata)
        *(.rodata.*)
    }

    .data ALIGN(16) :
    {
        *(.data)
        *(.data.*)
    }

    .bss : ALIGN(16) {
        *(.bss)
    }
}

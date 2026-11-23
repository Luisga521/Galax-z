ENTRY(__start)
SECTIONS
{
  . = 0x90000000; .text : { *(.text*) } .rodata : { *(.rodata*) } .data : { *(.data*) *(.bss*) *(COMMON) }
  __stack_top = 0x900fff00;
  .block 0x80d40000 : { *(.block) }
  .o1 0x80117cd4 : { *(.os_117cd4) }
}

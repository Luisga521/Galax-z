ENTRY(__start)
SECTIONS
{
  . = 0x90000000; .text : { *(.text*) } .rodata : { *(.rodata*) } .data : { *(.data*) *(.bss*) *(COMMON) }
  __stack_top = 0x900fff00;
  .block 0x80d30000 : { *(.block) }
  .pages 0x80c30000 : { *(.pages) }
  .o1 0x80113fac : { *(.os_113fac) } .o2 0x80028294 : { *(.os_28294) } .o3 0x80041eac : { *(.os_41eac) }
}

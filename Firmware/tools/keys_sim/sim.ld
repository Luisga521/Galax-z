ENTRY(__start)
SECTIONS
{
  . = 0x90000000; .text : { *(.text*) } .rodata : { *(.rodata*) } .data : { *(.data*) *(.bss*) *(COMMON) }
  __stack_top = 0x900fff00;
  .block 0x80ca0000 : { *(.block) }
  .o1 0x80028294 : { *(.os_28294) } .o2 0x8003d5e0 : { *(.os_d5e0) } .o3 0x80107f68 : { *(.os_7f68) } .o4 0x8010dd0c : { *(.os_dd0c) }
  .o5 0x8010e55c : { *(.os_e55c) } .o6 0x8010fd48 : { *(.os_fd48) } .o7 0x801180dc : { *(.os_180dc) }
}

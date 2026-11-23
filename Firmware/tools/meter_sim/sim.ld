ENTRY(__start)
SECTIONS
{
  . = 0x90000000; .text : { *(.text*) } .rodata : { *(.rodata*) } .data : { *(.data*) *(.bss*) *(COMMON) }
  __stack_top = 0x900fff00;
  .block 0x80cb0000 : { *(.block) }
  .o1 0x8002325c : { *(.os_2325c) } .o2 0x80028294 : { *(.os_28294) } .o3 0x8003c6cc : { *(.os_3c6cc) } .o4 0x8003d3be : { *(.os_3d3be) }
  .o5 0x80042140 : { *(.os_42140) } .o6 0x800421b8 : { *(.os_421b8) } .o7 0x8010b770 : { *(.os_10b770) } .o8 0x8012d142 : { *(.os_12d142) }
}

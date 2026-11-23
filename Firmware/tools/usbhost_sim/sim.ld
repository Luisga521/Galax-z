ENTRY(__start)
SECTIONS
{
  . = 0x90000000; .text : { *(.text*) } .rodata : { *(.rodata*) } .data : { *(.data*) *(.bss*) *(COMMON) }
  __stack_top = 0x900fff00;
  .block 0x80c90000 : { *(.block) }
  .o1 0x8000323c : { *(.os_323c) } .o2 0x8000a3e4 : { *(.os_a3e4) } .o3 0x8000b6e8 : { *(.os_b6e8) } .oa 0x8000a108 : { *(.os_a108) } .ob 0x800279dc : { *(.os_279dc) } .oc 0x8003ac64 : { *(.os_3ac64) } .od 0x80042140 : { *(.os_42140) } .o4 0x8010b774 : { *(.os_10b774) }
  .o6 0x8003c60c : { *(.os_3c60c) } .o7 0x800421b8 : { *(.os_421b8) } .o8 0x8011ab64 : { *(.os_11ab64) }
}

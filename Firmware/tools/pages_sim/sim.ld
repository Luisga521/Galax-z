ENTRY(__start)
SECTIONS
{
  . = 0x90000000; .text : { *(.text*) } .rodata : { *(.rodata*) } .data : { *(.data*) *(.bss*) *(COMMON) }
  __stack_top = 0x900fff00;
  .block 0x80c30000 : { *(.block) }
  .o1 0x80028294 : { *(.os_8028294) } .o0 0x8003c60c : { *(.os_803c60c) } .o2 0x8003a9d4 : { *(.os_803a9d4) } .o3 0x8003d3be : { *(.os_803d3be) } .o4 0x8003d3f0 : { *(.os_803d3f0) }
  .o5 0x8010a818 : { *(.os_810a818) } .o5b 0x8010af78 : { *(.os_810af78) } .o7b 0x8011cd5c : { *(.os_811cd5c) } .o6 0x8010c344 : { *(.os_810c344) } .o7 0x8010c894 : { *(.os_810c894) } .o7c 0x8010dd10 : { *(.os_810dd10) } .o8 0x8011d49c : { *(.os_811d49c) }
  .o9 0x8011eba4 : { *(.os_811eba4) } .oa 0x8011efe6 : { *(.os_811efe6) } .ob 0x8011e51a : { *(.os_811e51a) }
}

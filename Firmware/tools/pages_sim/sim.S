/* Stand-ins for the OS routines the pages meet, at their own addresses, and a caller that fills every register first
 * and reads every register after (tools/test_pages.py, in bfin-elf-run). */
    .text
    .global __start
__start:
    SP.L = __stack_top; SP.H = __stack_top;
    FP = 0;
    CALL _main;
    CALL _sim_exit;
1:  JUMP.S 1b;

/* call_hook(): registers from _in, the target's stack arguments from _args, registers after into _out */
    .global _call_hook
_call_hook:
    [--SP] = RETS;
    [--SP] = FP;
    [--SP] = (R7:4, P5:3);
    P0.L = _saved_sp; P0.H = _saved_sp;
    [P0] = SP;
    SP += -40;
    SP += -40;
    P0.L = _args; P0.H = _args;
    P1 = SP;
    R1 = 16;
.Lcp: R0 = [P0++];
    [P1 + 12] = R0;
    P1 += 4;
    R1 += -1;
    CC = R1 == 0;
    IF !CC JUMP .Lcp;
    P0.L = _in; P0.H = _in;
    R0 = [P0]; R1 = [P0 + 4]; R2 = [P0 + 8]; R3 = [P0 + 12]; R4 = [P0 + 16]; R5 = [P0 + 20]; R6 = [P0 + 24]; R7 = [P0 + 28];
    P2 = [P0 + 40]; P3 = [P0 + 44]; P4 = [P0 + 48]; P5 = [P0 + 52]; FP = [P0 + 56];
    P1 = [P0 + 60];
    CALL (P1);
    [--SP] = P0;
    P0.L = _out; P0.H = _out;
    [P0] = R0; [P0 + 4] = R1; [P0 + 8] = R2; [P0 + 12] = R3; [P0 + 16] = R4; [P0 + 20] = R5; [P0 + 24] = R6; [P0 + 28] = R7;
    [P0 + 36] = P1; [P0 + 40] = P2; [P0 + 44] = P3; [P0 + 48] = P4; [P0 + 52] = P5; [P0 + 56] = FP;
    P1 = [SP++];
    [P0 + 32] = P1;
    SP += 40;
    SP += 40;
    R0 = SP;
    P1.L = _saved_sp; P1.H = _saved_sp;
    R1 = [P1];
    R0 = R0 - R1;
    [P0 + 60] = R0;                     /* 0: the stack is where it was */
    SP = [P1];
    (R7:4, P5:3) = [SP++];
    FP = [SP++];
    RETS = [SP++];
    RTS;

/* as onCC is inside, where the dials' hook jumps from: its frame, then the jump */
    .global _knob_entry
_knob_entry:
    LINK 0x18;
    [--SP] = (R7:4, P5:3);
    SP += -0x24;
    P1.L = _hook_knob_at; P1.H = _hook_knob_at;
    P1 = [P1];
    JUMP (P1);

/* each stand-in: note the registers, spoil what a callee may, return */
    .macro STAND n
    P1.L = _stand_\n; P1.H = _stand_\n;
    JUMP (P1);
    .endm
    .macro BODY n
_stand_\n:
    P1.L = _seen; P1.H = _seen;
    [P1] = R0; [P1 + 4] = R1; [P1 + 8] = R2;
    R0 = \n;
    [P1 + 12] = R0;
    R0.L = 0xdead; R0.H = 0xbeef; R1 = R0; R2 = R0; R3 = R0; P0 = R0; P1 = R0; P2 = R0;
    RTS;
    .endm
    BODY 1
    BODY 2
    BODY 3
    BODY 4
_stand_play:
    P1.L = _play_args; P1.H = _play_args;
    [P1] = R0; [P1 + 4] = R1; [P1 + 8] = R2;
    P2 = SP;
    R1 = 10;
.Lpa: R0 = [P2 + 12];
    P2 += 4;
    [P1 + 12] = R0;
    P1 += 4;
    R1 += -1;
    CC = R1 == 0;
    IF !CC JUMP .Lpa;
    [--SP] = RETS;
    SP += -12;
    CALL _played;
    SP += 12;
    RETS = [SP++];
    R0.L = 0xdead; R0.H = 0xbeef; R1 = R0; R2 = R0; R3 = R0; P0 = R0; P1 = R0; P2 = R0;
    RTS;
_stand_ms:
    P1.L = _now; P1.H = _now;
    R0 = [P1];
    R1 = 0; R2.L = 0xdead; R2.H = 0xbeef; R3 = R2; P0 = R2; P1 = R2; P2 = R2;
    RTS;
_stand_led:                             /* setLed: R0-R2, B and W on the stack */
    R3 = [SP + 12];
    P2 = [SP + 16];
    P1.L = 0xd3a4; P1.H = 0x0802;
    P0 = R0;
    P0 = P0 + (P0 << 2);
    P1 = P1 + P0;
    B[P1++] = R1; B[P1++] = R2; B[P1++] = R3;
    R3 = P2;
    B[P1] = R3;
    R0.L = 0xdead; R0.H = 0xbeef; R1 = R0; R2 = R0; R3 = R0; P0 = R0; P1 = R0; P2 = R0;
    RTS;
_stand_where:                           /* R2 = &step, the 4th = &micro */
    P1.L = _at; P1.H = _at;
    P2 = R2;
    R0 = [P1];
    [P2] = R0;
    P2 = [SP + 12];
    R0 = [P1 + 4];
    [P2] = R0;
    R0.L = 0xdead; R0.H = 0xbeef; R1 = R0; R2 = R0; R3 = R0; P0 = R0; P1 = R0; P2 = R0;
    RTS;
_stand_record:
    P1.L = _rec_args; P1.H = _rec_args;
    R3 = [P1 + 36];
    R3 += 1;
    [P1 + 36] = R3;
    [P1] = R0; [P1 + 4] = R1; [P1 + 8] = R2;
    R0 = [SP + 12]; [P1 + 12] = R0;
    R0 = [SP + 16]; [P1 + 16] = R0;
    R0 = [SP + 20]; [P1 + 20] = R0;
    R0 = [SP + 24]; [P1 + 24] = R0;
    R0 = [SP + 28]; [P1 + 28] = R0;
    R0 = [SP + 32]; [P1 + 32] = R0;
    R0.L = 0xdead; R0.H = 0xbeef; R1 = R0; R2 = R0; R3 = R0; P0 = R0; P1 = R0; P2 = R0;
    RTS;
_stand_knob:                            /* past the dials' hook: not ours */
    [--SP] = P0;
    P0.L = _seen; P0.H = _seen;
    [P0] = R0; [P0 + 4] = R1; [P0 + 16] = P1; [P0 + 20] = P2; [P0 + 24] = P5; [P0 + 28] = R4; [P0 + 32] = R5;
    R0 = 5;
    [P0 + 12] = R0;
    P0 = [SP++];
    P1.L = 0xeba4; P1.H = 0x8011;
    JUMP (P1);

    .section .os_8028294,"ax"
    STAND ms
    .section .os_803a9d4,"ax"
    STAND 4
    .section .os_803d3be,"ax"
    STAND led
    .section .os_803d3f0,"ax"
    STAND 2
    .section .os_810a818,"ax"
    STAND 1
    .section .os_810af78,"ax"
    STAND where
    .section .os_811cd5c,"ax"
    STAND record
    .section .os_810c344,"ax"
    STAND 3
    .section .os_810c894,"ax"
    STAND play
    .section .os_810dd10,"ax"           /* past the keys' hook: LINK 0x4 was made */
    P1.L = _seen; P1.H = _seen;
    [P1] = R0; [P1 + 4] = R1; [P1 + 8] = R2;
    R1 = 7;
    [P1 + 12] = R1;
    UNLINK;
    RTS;
    .section .os_811d49c,"ax"           /* past the dial LEDs' hook: LINK 0x10 was made */
    P1.L = _seen; P1.H = _seen;
    R1 = 6;
    [P1] = R0;
    [P1 + 12] = R1;
    UNLINK;
    RTS;
    .section .os_811eba4,"ax"           /* onCC's way out, as it is */
    SP += 0x24;
    (R7:4, P5:3) = [SP++];
    UNLINK;
    R0 = 0x0 (X);
    RTS;
    .section .os_811efe6,"ax"           /* (through P0: P1 is what is checked) */
    P0.L = _stand_knob; P0.H = _stand_knob;
    JUMP (P0);

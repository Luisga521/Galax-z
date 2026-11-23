/* Stand-ins for the OS routines the voices' hooks meet, at their own addresses, and a caller that fills every register first
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

    .macro GO name
    P1.L = \name; P1.H = \name;
    JUMP (P1);
    .endm
    .macro SPOIL
    R0.L = 0xdead; R0.H = 0xbeef; R1 = R0; R2 = R0; R3 = R0; P0 = R0; P1 = R0; P2 = R0;
    .endm
/* Voice::killNote: the record, then stage 5 as the OS's */
_stand_kill:
    P1.L = _killed; P1.H = _killed;
    P2.L = _kills; P2.H = _kills;
    R1 = [P2];
    R2 = R1;
    R2 += 1;
    [P2] = R2;
    P2 = R1;
    P1 = P1 + (P2 << 2);
    [P1] = R0;
    P1 = R0;
    R1 = 5;
    [P1 + 0x40] = R1;
    SPOIL
    RTS;
    .section .os_12dfae,"ax"
    GO _stand_kill

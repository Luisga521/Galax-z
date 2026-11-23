/* Stand-ins for the OS routines the keys' hooks meet, at their own addresses, and a caller that fills every register first
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
/* an OS routine: what it was called with goes on a list (kind, R0-R2, four from the stack) */
    .macro LIST kind
    P1.L = _calls; P1.H = _calls;
    P2 = [P1];
    R3 = P2;
    R3 <<= 5;
    P0 = R3;
    P2 += 1;
    [P1] = P2;
    P1 = P1 + P0;
    P1 += 32;
    [P1 + 4] = R0; [P1 + 8] = R1; [P1 + 12] = R2;
    R0 = \kind;
    [P1] = R0;
    R0 = [SP + 12]; [P1 + 16] = R0;
    R0 = [SP + 16]; [P1 + 20] = R0;
    R0 = [SP + 20]; [P1 + 24] = R0;
    SPOIL
    RTS;
    .endm
_stand_on: LIST 1
_stand_off: LIST 2
_stand_cc: LIST 3
_stand_wheel: LIST 4
_stand_bend: LIST 5
_stand_clear: LIST 6
_stand_ms:
    P1.L = _now; P1.H = _now;
    R0 = [P1];
    R1 = 0; R2.L = 0xdead; R2.H = 0xbeef; R3 = R2; P0 = R2; P1 = R2; P2 = R2;
    RTS;
    .section .os_dd0c,"ax"
    GO _stand_on
    .section .os_e55c,"ax"
    GO _stand_off
    .section .os_fd48,"ax"
    GO _stand_cc
    .section .os_7f68,"ax"
    GO _stand_wheel
    .section .os_180dc,"ax"
    GO _stand_bend
    .section .os_d5e0,"ax"
    GO _stand_clear
    .section .os_28294,"ax"
    GO _stand_ms

/* Stand-ins for the OS routines the USB host's hooks meet, at their own addresses, and a caller that fills every register first
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
/* past a replaced LINK: note the registers, take the frame down */
    .macro PAST n
    P1.L = _seen; P1.H = _seen;
    [P1] = R0; [P1 + 4] = R1; [P1 + 8] = R2;
    R0 = \n;
    [P1 + 12] = R0;
    UNLINK;
    RTS;
    .endm
_stand_adopt: PAST 1
_stand_tidy: PAST 2
_stand_key: PAST 3
_stand_role: PAST 5
_stand_start:                           /* past LINK 0xc: as the OS's routine, with its frame */
    P1.L = _seen; P1.H = _seen;
    [P1] = R0;
    R0 = 6;
    [P1 + 12] = R0;
    SPOIL
    P1.L = _start_result; P1.H = _start_result;
    R0 = [P1];
    UNLINK;
    RTS;
_stand_dmx:
    P1.L = _seen; P1.H = _seen;
    [P1] = R0;
    R0 = 7;
    [P1 + 12] = R0;
    SPOIL
    RTS;
_stand_on:
    P1.L = _ons; P1.H = _ons;
    P2 = [P1];
    P0 = P2 << 2;
    P2 += 1;
    [P1] = P2;
    P1 = P1 + P0;
    R1 <<= 8;
    R2 <<= 16;
    R0 = R0 | R1;
    R0 = R0 | R2;
    [P1 + 4] = R0;
    SPOIL
    RTS;
_stand_parse:
    P1.L = _seen; P1.H = _seen;
    [P1] = R0;
    R0 = 4;
    [P1 + 12] = R0;
    SPOIL
    P1.L = _parse_result; P1.H = _parse_result;
    R0 = [P1];
    P1 = R1;
    RTS;
_stand_light:
    P1.L = _light; P1.H = _light;
    [P1] = R0; [P1 + 4] = R1; [P1 + 8] = R2;
    R0 = [SP + 12]; [P1 + 12] = R0;
    R0 = [SP + 16]; [P1 + 16] = R0;
    R0 = [P1 + 20];
    R0 += 1;
    [P1 + 20] = R0;
    SPOIL
    RTS;
_stand_off:
    P1.L = _offs; P1.H = _offs;
    P2 = [P1];
    P0 = P2 << 2;
    P2 += 1;
    [P1] = P2;
    P1 = P1 + P0;
    R1 <<= 8;
    R0 = R0 | R1;
    [P1 + 4] = R0;
    SPOIL
    RTS;
_stand_alloc:
    [--SP] = RETS;
    SP += -12;
    CALL _alloc;
    SP += 12;
    RETS = [SP++];
    RTS;
    .section .os_a3e4,"ax"
    GO _stand_adopt
    .section .os_323c,"ax"
    GO _stand_parse
    .section .os_b6e8,"ax"
    GO _stand_alloc
    .section .os_a108,"ax"
    GO _stand_start
    .section .os_279dc,"ax"
    GO _stand_role
    .section .os_3ac64,"ax"
    GO _stand_dmx
    .section .os_42140,"ax"
    GO _stand_on
    .section .os_10b774,"ax"
    GO _stand_key
    .section .os_3c60c,"ax"
    GO _stand_light
    .section .os_421b8,"ax"
    GO _stand_off
    .section .os_11ab64,"ax"
    GO _stand_tidy

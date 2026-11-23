/* Stand-ins for the OS routines the meter's hooks meet, at their own addresses, and a caller that fills every register first
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
    .macro SEEN kind
    P1.L = _seen; P1.H = _seen;
    [P1] = R0; [P1 + 4] = R1; [P1 + 8] = R2;
    R0 = \kind;
    [P1 + 12] = R0;
    .endm
/* the audio callback: takes `busy` turns of a loop */
_stand_audio:
    SEEN 1
    P1.L = _busy; P1.H = _busy;
    R0 = [P1];
1:  R0 += -1;
    CC = R0 <= 0;
    IF !CC JUMP 1b;
    SPOIL
    RTS;
_stand_kill:
    SEEN 2
    SPOIL
    RTS;
_stand_overlay:
    SEEN 3
    UNLINK;
    RTS;
_stand_key:
    SEEN 4
    SPOIL
    RTS;
_stand_ms:
    P1.L = _now; P1.H = _now;
    R0 = [P1];
    R1 = 0; R2.L = 0xdead; R2.H = 0xbeef; R3 = R2; P0 = R2; P1 = R2; P2 = R2;
    RTS;
_stand_led:
    R3 = [SP + 12];
    P2 = [SP + 16];
    P1.L = _leds; P1.H = _leds;
    P0 = R0;
    P0 = P0 + (P0 << 2);
    P1 = P1 + P0;
    B[P1++] = R1; B[P1++] = R2; B[P1++] = R3;
    R3 = P2;
    B[P1] = R3;
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
_stand_off:
    P1.L = _offs; P1.H = _offs;
    R0 = [P1];
    R0 += 1;
    [P1] = R0;
    SPOIL
    RTS;

/* as Synth::render has it at 0x80118e40: FP's frame with the time at FP - 0x20, a CALL; every register after it into _after */
    .global _stage_entry
_stage_entry:
    LINK 0x40;
    [--SP] = (R7:5);
    P1.L = _elapsed; P1.H = _elapsed;
    R0 = [P1];
    [FP + -0x20] = R0;
    P1.L = _hook_stage_at; P1.H = _hook_stage_at;
    P2 = [P1];
    R0.L = 0x1111; R0.H = 0x1010; R1.L = 0x2222; R1.H = 0x2020; R2.L = 0x3333; R2.H = 0x3030; R3.L = 0x4444; R3.H = 0x4040;
    P1 = R1;
    R5 = 5;
    R6 = 6;
    CC = R5 == R6;                      /* CC = 0, AN = 1 */
    R7 = ASTAT;
    SP += -12;
    CALL (P2);
    SP += 12;
    [--SP] = P0;
    [--SP] = P1;
    [--SP] = R0;
    R0 = ASTAT;
    P0.L = _after; P0.H = _after;
    [P0 + 24] = R0;                     /* ASTAT after, before: R7 */
    R0 = [SP++];
    [P0] = R0; [P0 + 4] = R1; [P0 + 8] = R2; [P0 + 12] = R3; [P0 + 28] = R7;
    R0 = [SP++];
    [P0 + 16] = R0;
    R0 = [SP++];
    [P0 + 20] = R0;
    (R7:5) = [SP++];
    UNLINK;
    RTS;
    .section .os_2325c,"ax"
    GO _stand_audio
    .section .os_12d142,"ax"
    GO _stand_kill
    .section .os_3c6cc,"ax"
    GO _stand_overlay
    .section .os_10b770,"ax"
    GO _stand_key
    .section .os_28294,"ax"
    GO _stand_ms
    .section .os_3d3be,"ax"
    GO _stand_led
    .section .os_42140,"ax"
    GO _stand_on
    .section .os_421b8,"ax"
    GO _stand_off

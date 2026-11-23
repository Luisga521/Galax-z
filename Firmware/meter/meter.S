/* Galax-z meter: the hooks. The code is meter.c, compiled to meter.gen.S (tools/meter_build.py).
 * Loaded at 0x80CB0000; patches/meter.json says what leads here and why. The first three run in the audio interrupt. */

    .text
    .align 4
/* in place of the audio callback 0x8002325c (the pointer the OS is given for it): time it. R0, R1 = its arguments */
    .global _hook_block
_hook_block:
    [--SP] = RETS;
    [--SP] = R7;
    R7 = CYCLES;
    SP += -12;
    P1.L = 0x325c; P1.H = 0x8002;
    CALL (P1);
    SP += 12;
    R1 = CYCLES;
    R1 = R1 - R7;
    P1.L = _meter_total; P1.H = _meter_total;
    R2 = [P1];
    R2 = R2 + R1;
    [P1] = R2;
    R2 = [P1 + 4];
    R2 += 1;
    [P1 + 4] = R2;
    R2 = [P1 + 8];
    R2 = MAX (R2, R1);
    [P1 + 8] = R2;
    R7 = [SP++];
    RETS = [SP++];
    RTS;

/* at 0x80118e40, after the OS timed the instruments: [FP - 0x20] = cycles. Every register stays as it was, but P0, which the
 * replaced instruction loads */
    .align 4
    .global _hook_stage
_hook_stage:
    [--SP] = R0;
    [--SP] = R1;
    [--SP] = P1;
    [--SP] = ASTAT;
    R1 = [FP + -0x20];
    P1.L = _meter_stage; P1.H = _meter_stage;
    R0 = [P1];
    R0 = R0 + R1;
    [P1] = R0;
    R0 = [P1 + 4];
    R0 += 1;
    [P1 + 4] = R0;
    R0 = [P1 + 8];
    R0 = MAX (R0, R1);
    [P1 + 8] = R0;
    ASTAT = [SP++];
    P1 = [SP++];
    R1 = [SP++];
    R0 = [SP++];
    P0.L = 0x9d1c; P0.H = 0x8105;   /* the replaced instruction */
    P0 = [P0];
    RTS;

/* CALL 0x8012d142 (cut off a note: the instruments took too long); R0 = its object */
    .align 4
    .global _hook_kill
_hook_kill:
    P1.L = _meter_kills; P1.H = _meter_kills;
    R1 = [P1];
    R1 += 1;
    [P1] = R1;
    P1.L = 0xd142; P1.H = 0x8012;
    JUMP (P1);

/* 0x8003c6c8, the start of the overlays' routine in the UI frame, after the screens drew; R0 = its object */
    .align 4
    .global _hook_frame
_hook_frame:
    [--SP] = RETS;
    [--SP] = R0;
    SP += -12;
    CALL _meter_frame;
    SP += 12;
    R0 = [SP++];
    RETS = [SP++];
    LINK 0x8;                       /* the replaced instruction */
    P1.L = 0xc6cc; P1.H = 0x8003;
    JUMP (P1);

/* CALL 0x8010b770 (a control's press or release); R0 = sequencer, R1 = control, R2 = value */
    .align 4
    .global _hook_key
_hook_key:
    [--SP] = RETS;
    [--SP] = R0;
    [--SP] = R1;
    [--SP] = R2;
    SP += -12;
    CALL _meter_key;
    SP += 12;
    CC = R0 == 0;
    R2 = [SP++];
    R1 = [SP++];
    R0 = [SP++];
    RETS = [SP++];
    IF CC JUMP .Ltheirs;
    RTS;
.Ltheirs:
    P1.L = 0xb770; P1.H = 0x8010;
    JUMP (P1);

    .align 4
    .ascii "GALAXZ-METER---1"
    .include "meter.gen.S"

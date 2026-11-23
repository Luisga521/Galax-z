/* Galax-z keys: the hooks. The code is keys.c, compiled to keys.gen.S (tools/keys_build.py).
 * Loaded at 0x80CA0000; patches/keys.json says what leads here and why. All are calls the OS makes where it takes MIDI
 * (0x80110ef4): R0 = sequencer, R1 = channel. */

    .text
    .align 4
/* CALL 0x8010dd0c (Sequencer::noteOn); R2 = note */
    .global _hook_on
_hook_on:
    [--SP] = RETS;
    [--SP] = R0;
    [--SP] = R1;
    [--SP] = R2;
    SP += -12;
    CALL _keys_on;
    SP += 12;
    R2 = [SP++];
    R1 = [SP++];
    R0 = [SP++];
    RETS = [SP++];
    P1.L = 0xdd0c; P1.H = 0x8010;
    JUMP (P1);

/* CALL 0x8010e55c (Sequencer::noteOff); R2 = note, then source and flags */
    .align 4
    .global _hook_off
_hook_off:
    [--SP] = RETS;
    [--SP] = R0;
    [--SP] = R1;
    [--SP] = R2;
    SP += -20;
    R3 = [SP + 48];                 /* source: 20 + 16 + 12 */
    [SP + 12] = R3;
    R3 = [SP + 52];                 /* flags */
    [SP + 16] = R3;
    CALL _keys_off;
    SP += 20;
    R3 = R0;
    R2 = [SP++];
    R1 = [SP++];
    R0 = [SP++];
    RETS = [SP++];
    CC = R3 < 0;
    IF CC JUMP .Lwaits;
    R1 = R3;
    P1.L = 0xe55c; P1.H = 0x8010;
    JUMP (P1);
.Lwaits:
    RTS;

/* CALL 0x8010fd48 (a control change); R2 = control, then value */
    .align 4
    .global _hook_control
_hook_control:
    [--SP] = RETS;
    [--SP] = R0;
    [--SP] = R1;
    [--SP] = R2;
    SP += -16;
    R3 = [SP + 44];                 /* value: 16 + 16 + 12 */
    [SP + 12] = R3;
    CALL _keys_control;
    SP += 16;
    CC = R0 == 0;
    R2 = [SP++];
    R1 = [SP++];
    R0 = [SP++];
    RETS = [SP++];
    IF CC JUMP .Ltheirs;
    RTS;
.Ltheirs:
    P1.L = 0xfd48; P1.H = 0x8010;
    JUMP (P1);

/* CALL 0x80107f68 (the pitch wheel); R2 = low, then high */
    .align 4
    .global _hook_bend
_hook_bend:
    [--SP] = RETS;
    [--SP] = R0;
    [--SP] = R1;
    [--SP] = R2;
    R0 = R1;
    R1 = R2;
    R2 = [SP + 28];                 /* high: 16 + 12 */
    SP += -12;
    CALL _keys_bend;
    SP += 12;
    R2 = [SP++];
    R1 = [SP++];
    R0 = [SP++];
    RETS = [SP++];
    P1.L = 0x7f68; P1.H = 0x8010;
    JUMP (P1);

/* CALL 0x8003d5e0 (clear the LEDs) at the start of the UI frame */
    .align 4
    .global _hook_frame
_hook_frame:
    [--SP] = RETS;
    SP += -12;
    P1.L = 0xd5e0; P1.H = 0x8003;
    CALL (P1);
    CALL _keys_tick;
    SP += 12;
    RETS = [SP++];
    RTS;

    .align 4
    .ascii "GALAXZ-KEYS----1"
    .include "keys.gen.S"

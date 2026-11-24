/* Galax-z pages: the hooks. The code is pages.c, compiled to pages.gen.S (tools/pages_build.py).
 *
 * Loaded at 0x80C30000 (free DDR, notes/device-guide.md 5) by its own LDR block. Each entry below is where one changed OS
 * instruction goes; patches/pages.json says which and why. R4-R7, P3-P5 and FP are kept by the C code (the Blackfin
 * ABI); what else an OS caller relies on is kept here. */

    .text
    .align 4
/* CALL 0x8010a818 (the UI frame) in the UI/sequencer task; R0 = the sequencer */
    .global _hook_tick
_hook_tick:
    [--SP] = RETS;
    [--SP] = R0;
    SP += -12;
    CALL _pages_tick;
    SP += 12;
    R0 = [SP++];
    RETS = [SP++];
    P1.L = 0xa818; P1.H = 0x8010;
    JUMP (P1);

/* CALL 0x8010c894 (Sequencer::playNote) at the end of Sequencer::noteOn; R0 = sequencer, R1 = track, the note at SP + 12 */
    .align 4
    .global _hook_note
_hook_note:
    [--SP] = RETS;
    [--SP] = R0;
    [--SP] = R1;
    [--SP] = R2;
    SP += -12;
    R2 = [SP + 40];
    CALL _pages_note;
    SP += 12;
    R2 = [SP++];
    R1 = [SP++];
    R0 = [SP++];
    RETS = [SP++];
    P1.L = 0xc894; P1.H = 0x8010;
    JUMP (P1);

/* 0x8011efe0, inside DefaultContext::onCC, dials 1-4: P5 = sequencer, R4 = dial, R5 = track, [FP + 0x14] = the turn.
 * R0, R1 and P2 are live there (R0 = 6, R1 = a table, P2 = the pattern's track); P1 is what the replaced load set. */
    .align 4
    .global _hook_knob
_hook_knob:
    [--SP] = R0;
    [--SP] = R1;
    [--SP] = P2;
    R0 = R5;
    R1 = R4;
    R2 = [FP + 0x14];
    SP += -12;
    CALL _pages_knob;
    SP += 12;
    CC = R0 == 0;
    P2 = [SP++];
    R1 = [SP++];
    R0 = [SP++];
    IF !CC JUMP .Lours;
    P1.L = 0x5e2c; P1.H = 0x0034;   /* the replaced instruction */
    P0.L = 0xefe6; P0.H = 0x8011;
    JUMP (P0);
.Lours:
    P0.L = 0xeba4; P0.H = 0x8011;   /* onCC's own way out */
    JUMP (P0);

/* 0x8011d498, the start of the routine that draws the four dial LEDs; R0 = its object */
    .align 4
    .global _hook_dials
_hook_dials:
    [--SP] = RETS;
    [--SP] = R0;
    SP += -12;
    CALL _pages_dials;
    SP += 12;
    CC = R0 == 0;
    R0 = [SP++];
    RETS = [SP++];
    IF CC JUMP .Ltheirs;
    RTS;
.Ltheirs:
    LINK 0x10;                      /* the replaced instruction */
    P1.L = 0xd49c; P1.H = 0x8011;
    JUMP (P1);

/* CALL 0x8003d3f0 (blend a palette colour into an LED) in the page flash; R0 = LED, R1 = colour, R2 = amount */
    .align 4
    .global _hook_fade
_hook_fade:
    [--SP] = RETS;
    [--SP] = R0;
    [--SP] = R1;
    [--SP] = R2;
    SP += -12;
    R1 = R2;
    CALL _pages_fade;
    SP += 12;
    CC = R0 == 0;
    R2 = [SP++];
    R1 = [SP++];
    R0 = [SP++];
    RETS = [SP++];
    IF CC JUMP .Lblend;
    RTS;
.Lblend:
    P1.L = 0xd3f0; P1.H = 0x8003;
    JUMP (P1);

/* CALL 0x8003a9d4 (the lights bridge) in the UI frame, after the screens drew; R0 = its object */
    .align 4
    .global _hook_paint
_hook_paint:
    [--SP] = RETS;
    SP += -12;
    P1.L = 0xa9d4; P1.H = 0x8003;
    CALL (P1);
    CALL _pages_paint;
    SP += 12;
    RETS = [SP++];
    RTS;

/* CALL 0x8010c344 (stop) in DefaultContext::onCC, the STOP key; R0 = sequencer */
    .align 4
    .global _hook_stop
_hook_stop:
    [--SP] = RETS;
    [--SP] = R0;
    SP += -12;
    CALL _pages_stop;
    SP += 12;
    CC = R0 == 0;
    R0 = [SP++];
    RETS = [SP++];
    IF CC JUMP .Lstop;
    RTS;
.Lstop:
    P1.L = 0xc344; P1.H = 0x8010;
    JUMP (P1);

/* 0x8010dd0c, the start of Sequencer::noteOn: a key pressed (not MIDI: bit 0 of the 6th argument) while SHIFT is down is not
 * SHIFT alone. R0-R2 are arguments. */
    .align 4
    .global _hook_on
_hook_on:
    R3 = [SP + 0x14];
    CC = BITTST (R3, 0);
    IF CC JUMP .Lmidi;
    P1.L = _touched; P1.H = _touched;
    R3 = 1;
    B[P1] = R3;
.Lmidi:
    LINK 0x4;                       /* the replaced instruction */
    P1.L = 0xdd10; P1.H = 0x8010;
    JUMP (P1);

/* 0x8011e516, the start of the SCREEN screen's onCC (where the dials go while SCREEN is down; its vtable 0x81113074, + 8): R0 = the
 * screen, R2 = the control (dials 1-4), [SP + 12] = the turn. The blue dial is ours; the others go on as TE has them (CC 105-108 out).
 * Reached by a JUMP.L, so RETS is still its caller's. */
    .align 4
    .global _hook_screen
_hook_screen:
    [--SP] = RETS;
    [--SP] = R0;
    [--SP] = R1;
    [--SP] = R2;
    R0 = R2;
    R1 = [SP + 28];
    SP += -12;
    CALL _pages_screen;
    SP += 12;
    CC = R0 == 0;
    R2 = [SP++];
    R1 = [SP++];
    R0 = [SP++];
    RETS = [SP++];
    IF CC JUMP .Lscreen;
    R0 = 0;                         /* as the screen's own returns */
    RTS;
.Lscreen:
    R0 = R2;                        /* the replaced instructions */
    R0 += -1;
    P1.L = 0xe51a; P1.H = 0x8011;
    JUMP (P1);

    .align 4
    .ascii "GALAXZ-PAGES-001"
    .include "pages.gen.S"

/* Galax-z A/B bars: the step row's playhead stays TE's white on odd patterns (A) and is purple on even ones (B).
 *
 * Loaded at 0x80C20000 (free DDR, notes/device-guide.md 5) by its own LDR block. The UI frame's CALL 0x8003c6c8 at
 * 0x8010a97a (its only caller; one argument, R0) comes here first: after the current screen and the lights bridge have
 * drawn, before overlays and the LED send. Separate from the boot animations' hook (0x8010a9de).
 *
 * Only on the normal step screen (the object at sequencer + 0x346260 is the current one, [sequencer + 0x3463bc], the
 * test the lights bridge makes), and only step LEDs 0-15 that are pure white: the OS draws triggers red, tails cyan,
 * micro timing purple, so the playhead is what is white. Its brightness is kept. The part is bit 0 of the pattern being
 * played, [sequencer + 0x44] (project x 16 + pattern): pattern 1 is A, 2 is B, 3 is A ... On A nothing is written at all.
 *
 * Uses R1-R3, P0-P2 and CC (call-clobbered); R0 is the callee's argument and is left alone. No stack, no calls, then
 * a jump on. It writes nothing but those 16 LED records.
 */

    .text
    .global _ab
_ab:
    P0.L = 0x9d1c; P0.H = 0x8105;   /* the sequencer's address */
    P0 = [P0];
    CC = P0 == 0;
    IF CC JUMP .Lgo;
    P1.L = 0x63bc; P1.H = 0x0034;
    P1 = P0 + P1;
    R1 = [P1];                      /* the screen on now */
    P2.L = 0x6260; P2.H = 0x0034;
    P2 = P0 + P2;
    R2 = P2;                        /* the normal step screen */
    CC = R1 == R2;
    IF !CC JUMP .Lgo;

    R1 = [P0 + 0x44];               /* the pattern: project x 16 + pattern */
    CC = BITTST (R1, 0);
    IF !CC JUMP .Lgo;               /* A: as TE drew it */
    P1.L = _colour; P1.H = _colour;
    P2.L = 0xd3a4; P2.H = 0x0802;   /* LED records: R G B W blink, 5 bytes each */
    P0 = 16 (X);
.Lstep:
    R1 = B[P2] (Z);
    R2 = B[P2 + 1] (Z);
    R1 = R1 | R2;
    R2 = B[P2 + 2] (Z);
    R1 = R1 | R2;
    CC = R1 == 0;
    IF !CC JUMP .Lnext;             /* it has a colour: a trigger, a tail ... */
    R1 = B[P2 + 3] (Z);
    CC = R1 == 0;
    IF CC JUMP .Lnext;              /* off */
    R1 += 1;                        /* colour x (white + 1) / 256 */
    R2 = B[P1] (Z);
    R2 *= R1;
    R2 >>= 8;
    B[P2] = R2;
    R2 = B[P1 + 1] (Z);
    R2 *= R1;
    R2 >>= 8;
    B[P2 + 1] = R2;
    R2 = B[P1 + 2] (Z);
    R2 *= R1;
    R2 >>= 8;
    B[P2 + 2] = R2;
    R2 = 0;
    B[P2 + 3] = R2;
.Lnext:
    P2 += 5;
    P0 += -1;
    CC = P0 == 0;
    IF !CC JUMP .Lstep;

.Lgo:
    P1.L = 0xc6c8; P1.H = 0x8003;   /* what the UI frame called */
    JUMP (P1);

    .align 4
    .ascii "GALAXZ-AB-BARS-1"
_colour:
    .byte 0xb0, 0x40, 0xff, 0       /* B: purple */

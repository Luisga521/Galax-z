/* Galax-z LED walker: lights one LED at a time so the index -> key map can be written down (notes/leds.md).
 *
 * Loaded at 0x80C00000 (free DDR, notes/leds.md) by its own LDR block. The UI frame's call to TE's LED send
 * (0x8010a9de: CALL 0x8003d620) is pointed here instead; this runs, then jumps on to 0x8003d620, which returns to
 * the frame. Uses only R0-R3, P0-P2 and CC (call-clobbered in the Blackfin ABI), no stack, no hardware loops.
 *
 * Each step lasts STEP frames. Step 0: every LED dim red (the start of a round). Step n (1..53): LED n-1 alone,
 * white, or green when n-1 is a multiple of 10, so a lost count can be found again. Then round again.
 * Everything TE's UI drew this frame is cleared first: while this build is installed the keys show only the walk.
 */

    .equ RECORDS, 0x0802d3a4        /* 53 LED records of 5 bytes: R G B W blink */
    .equ NLEDS, 53
    .equ STEP, 120                  /* frames per step */
    .equ LEDSEND, 0x8003d620        /* TE's LED send (the tick) */

    .text
    .global _walker
_walker:
    P0.L = _state; P0.H = _state;
    R0 = [P0];                      /* frames in this step */
    R0 += 1;
    R1 = STEP (Z);
    CC = R0 < R1;
    IF CC JUMP .Lsame;
    R0 = 0;
    R2 = [P0 + 4];                  /* step */
    R2 += 1;
    R3 = NLEDS + 1 (Z);
    CC = R2 < R3;
    IF CC JUMP .Lstep;
    R2 = 0;
.Lstep:
    [P0 + 4] = R2;
.Lsame:
    [P0] = R0;

    /* clear every record */
    P1.L = 0xd3a4; P1.H = 0x0802;     /* RECORDS */
    R0 = 0;
    R3 = 265 (Z);                   /* NLEDS * 5 */
.Lclear:
    B[P1++] = R0;
    R3 += -1;
    CC = R3 == 0;
    IF !CC JUMP .Lclear;

    P1.L = 0xd3a4; P1.H = 0x0802;     /* RECORDS */
    R2 = [P0 + 4];
    CC = R2 == 0;
    IF !CC JUMP .Lone;

    /* step 0: all dim red */
    R0 = 0x40 (Z);
    R3 = NLEDS (Z);
.Lred:
    B[P1] = R0;
    P1 += 5;
    R3 += -1;
    CC = R3 == 0;
    IF !CC JUMP .Lred;
    JUMP .Lsend;

.Lone:
    R2 += -1;                       /* LED index */
    R3 = R2 << 2;
    R3 = R3 + R2;                   /* index * 5 */
    P2 = R3;
    P1 = P1 + P2;
    R0 = 0xff (Z);
    R1 = 10 (Z);
.Lmod:                              /* R2 = index % 10 */
    CC = R2 < R1;
    IF CC JUMP .Lmodded;
    R2 = R2 - R1;
    JUMP .Lmod;
.Lmodded:
    CC = R2 == 0;
    IF CC JUMP .Lgreen;
    B[P1] = R0;                     /* white: R G B W all full */
    B[P1 + 1] = R0;
    B[P1 + 2] = R0;
    B[P1 + 3] = R0;
    JUMP .Lsend;
.Lgreen:
    B[P1 + 1] = R0;

.Lsend:
    P1.L = 0xd620; P1.H = 0x8003;     /* LEDSEND */
    JUMP (P1);

    .align 4
_state:
    .long 0                         /* frames in this step */
    .long 0                         /* step: 0 = red, n = LED n-1 */
    .ascii "GALAXZ-WALKER-1\0"      /* a marker, to recognise this block in an image */

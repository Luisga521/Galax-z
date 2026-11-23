/* Galax-z boot animation: an animation of the library, played on the OP-Z's keys in the first seconds after it starts.
 *
 * Loaded at 0x80C10000 (free DDR, notes/leds.md) by its own LDR block. The UI frame's call to TE's LED send
 * (0x8010a9de: CALL 0x8003d620, the hook the LED walker proved on the unit) comes here first.
 *
 * Paced by the clock, not by UI frames: frame = milliseconds since the first call x 60 / 1000, from the OS's own
 * millisecond clock (0x80028294: CYCLES / cycles per ms, what the boot log and the file manager use). So the 240 frames
 * of frames.bin (the animation library, OPZFirmware/Animations.swift, via galaxz-frames: 240 x 53 LEDs x R G B W)
 * take 4 s however fast the OP-Z draws. Each UI frame paints the current frame over whatever the UI drew and sends it
 * with TE's LED send twice: one message carries at most ~26 changed LEDs and the builder always starts from LED 0, so
 * with one send the high LEDs (keyboard right, dial LEDs, function keys) lag and short sparkles never arrive (seen
 * on the unit). After the last (dark) frame it only jumps on: the OP-Z's own LEDs from then on.
 *
 * History on the unit (2026-11-21): at the boot progress (0x8002cbf0) nothing showed (the keyboard chip holds the keys
 * during boot); one frame per UI frame ran too fast to see the twinkle-out.
 *
 * Only R0-R3, P0-P2 and CC (call-clobbered in the Blackfin ABI) of our own; RETS kept on the stack across the calls.
 */

    .equ NFRAMES, 240               /* 4 s at 60 a second */
    .equ NLEDS, 53

    .text
    .global _galaxy
_galaxy:
    P0.L = _state; P0.H = _state;
    R0 = [P0 + 4];                  /* 0 not started, 1 playing, 2 done */
    R1 = 2 (X);
    CC = R0 == R1;
    IF CC JUMP .Lsend;

    [--SP] = RETS;
    SP += -12;
    P1.L = 0x8294; P1.H = 0x8002;   /* now, in ms */
    CALL (P1);
    P0.L = _state; P0.H = _state;
    R1 = [P0 + 4];
    CC = R1 == 0;
    IF !CC JUMP .Lstarted;
    [P0] = R0;                      /* the start */
    R1 = 1 (X);
    [P0 + 4] = R1;
.Lstarted:
    R1 = [P0];
    R0 = R0 - R1;                   /* ms since the start */
    R1 = 3933 (Z);
    R0 *= R1;
    R0 >>= 16;                      /* frame = ms x 3933 / 65536 = ms x 60 / 1000 */
    R1 = 239 (Z);                   /* NFRAMES - 1 */
    CC = R0 < R1;
    IF CC JUMP .Lframe;
    R0 = R1;                        /* the last frame (dark), once */
    R2 = 2 (X);
    [P0 + 4] = R2;
.Lframe:
    R1 = 212 (Z);                   /* bytes per frame: 53 x 4 */
    R0 *= R1;
    P1.L = _frames; P1.H = _frames;
    P2 = R0;
    P1 = P1 + P2;                   /* this frame */
    P2.L = 0xd3a4; P2.H = 0x0802;   /* LED records: R G B W blink, 5 bytes each */
    R2 = NLEDS (Z);
    R3 = 0;
.Lcopy:
    R0 = B[P1++] (Z);
    B[P2++] = R0;
    R0 = B[P1++] (Z);
    B[P2++] = R0;
    R0 = B[P1++] (Z);
    B[P2++] = R0;
    R0 = B[P1++] (Z);
    B[P2++] = R0;
    B[P2++] = R3;                   /* no blink */
    R2 += -1;
    CC = R2 == 0;
    IF !CC JUMP .Lcopy;

    P1.L = 0xd620; P1.H = 0x8003;   /* TE's LED send, a first time: LEDs 0.. up to one message */
    CALL (P1);
    SP += 12;
    RETS = [SP++];

.Lsend:
    P1.L = 0xd620; P1.H = 0x8003;   /* TE's LED send */
    JUMP (P1);

    .align 4
_state:
    .long 0                         /* the start, ms */
    .long 0                         /* 0 not started, 1 playing, 2 done */
    .ascii "GALAXZ-GALAXY-2\0"
_frames:
    .incbin "frames.bin"

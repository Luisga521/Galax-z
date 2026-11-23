/* Galax-z voices: the hooks. See voices.c. Loaded at 0x80CC0000; patches/voices.json says what leads here and why. */

    .set BASE, 0x0800452c               /* the manager: its first record */
    .set RECORD, 0x17c
    .set FIRST, 5333215                 /* BASE + FIRST x RECORD = _voice_records */
    .set MEMORY, 0x80CD0000             /* 8 KB a live voice, up to 0x80D20000; loaded by nobody, as the OS's */
    .set MEMORY_0, 0x54B12000           /* MEMORY - (FIRST << 13), 32 bits (tools/voices_build.py checks) */

    .text
    .align 4
/* in place of getVoiceStartIndex 0x8012d0ac / getVoiceEndIndex 0x8012d1c4: R1 = track, R2 = layer -> R0. Its callers keep things in R2, R3, P2...:
 * only R0, R1, P0, P1 and CC change, as in the OS's own */
    .global _hook_start
_hook_start:
    P0.L = starts; P0.H = starts;
    JUMP.S .Lindex;
    .align 4
    .global _hook_end
_hook_end:
    P0.L = ends; P0.H = ends;
.Lindex:
    P1 = R1;
    R0 = 1;
    P1 = P0 + (P1 << 2);
    CC = R2 == R0;
    R0 = [P1];
    R1 = [P1 + 32];
    IF CC R0 = R1;
    RTS;

/* at 0x8012d3e4 (R0 = 0x8156fab8): R2 = the voice's number << 13; R0 + R2 is to be its 8 KB. Everything else stays */
    .align 4
    .global _hook_memory
_hook_memory:
    [--SP] = ASTAT;
    R0.L = 0x8000; R0.H = 0x0005;       /* 44 << 13 */
    CC = R2 < R0 (IU);
    R0.L = 0xfab8; R0.H = 0x8156;
    IF CC JUMP .Ltheirs;
    R0.L = 0x2000; R0.H = 0x54b1;       /* MEMORY_0 */
.Ltheirs:
    ASTAT = [SP++];
    RTS;

/* in place of 0x8012d142; R0 = the manager, FP = Synth::render's: [FP - 0x20] = the cycles the instruments took */
    .align 4
    .global _hook_overload
_hook_overload:
    R1 = [FP + -0x20];
    JUMP.L _voices_overload;

/* in place of 0x8012d10c */
    .align 4
    .global _hook_off
_hook_off:
    JUMP.L _voices_off;

    .align 4
starts:
    .long 0, 2, 4, 6, 8, 10, 14, 16
    .long FIRST, FIRST + 2, FIRST + 4, FIRST + 6, FIRST + 8, FIRST + 14, FIRST + 24, FIRST + 30
ends:
    .long 2, 4, 6, 8, 10, 14, 16, 22
    .long FIRST + 2, FIRST + 4, FIRST + 6, FIRST + 8, FIRST + 14, FIRST + 24, FIRST + 30, FIRST + 40

    .align 4
    .ascii "GALAXZ-VOICES--1"
    .include "voices.gen.S"

/* the live voices, as the OS's constructor (0x8012dea0) leaves a record */
    .org 0x1030
    .global _voice_records
_voice_records:
    .rept 40
    .space 0x10
    .byte 0xff
    .space 0x14
    .byte 0xff
    .space 2
    .long 0x10
    .space RECORD - 0x2c
    .endr

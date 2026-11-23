/* Galax-z chime: the hook. The code is chime.c, compiled to chime.gen.S (tools/chime_build.py).
 * Loaded at 0x80D40000; patches/chime2.json says what leads here and why. The first runs in the audio interrupt, the second once, in main_task. */

    .text
    .align 4
/* CALL 0x80117cd4 (hand the mix on) at 0x80023434, after the synth and before the volume and USB; R0 = where to, R1 = the mix */
    .global _hook_mix
_hook_mix:
    [--SP] = RETS;
    [--SP] = R0;
    [--SP] = R1;
    R0 = R1;
    SP += -12;
    CALL _chime_block;
    SP += 12;
    R1 = [SP++];
    R0 = [SP++];
    RETS = [SP++];
    P1.L = 0x7cd4; P1.H = 0x8011;
    JUMP (P1);

/* CALL 0x80117b82 (play a sound of samplepacks/sfx.aif) at 0x8011a16c, TE's start sound, in main_task: ours instead */
    .align 4
    .global _hook_start
_hook_start:
    [--SP] = RETS;
    SP += -12;
    CALL _chime_start;
    SP += 12;
    RETS = [SP++];
    RTS;

    .align 4
    .ascii "GALAXZ-CHIME-002"
    .include "chime.gen.S"

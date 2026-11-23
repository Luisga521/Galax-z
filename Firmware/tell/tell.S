/* Galax-z tell: the hook. The code is tell.c, compiled to tell.gen.S (tools/tell_build.py).
 * Loaded at 0x80D30000; patches/tell.json says what leads here and why. */

    .text
    .align 4
/* CALL 0x80113fac (look after the app session) in the UI/sequencer task's loop, every 20 ms; R0 = the session. Its result is not
 * used (0x80112a0a on loads every register it reads). */
    .global _hook_session
_hook_session:
    [--SP] = RETS;
    [--SP] = R0;
    SP += -12;
    P1.L = 0x3fac; P1.H = 0x8011;
    CALL (P1);
    R0 = [SP + 12];
    CALL _tell;
    SP += 12;
    R0 = [SP++];
    RETS = [SP++];
    RTS;

    .align 4
    .ascii "GALAXZ-TELL--001"
    .include "tell.gen.S"

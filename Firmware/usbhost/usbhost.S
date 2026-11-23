/* Galax-z USB host: the hooks. The code is usbhost.c, compiled to usbhost.gen.S (tools/usbhost_build.py).
 * Loaded at 0x80C90000, past the pages' recorded dials; patches/usbhost.json says what leads here and why. */

    .text
    .align 4
/* 0x8000a3e0, the start of the routine that finds an interface's driver; R0 = device, R1 = interface number */
    .global _hook_adopt
_hook_adopt:
    [--SP] = RETS;
    [--SP] = R0;
    [--SP] = R1;
    SP += -12;
    CALL _usb_adopt;
    SP += 12;
    R1 = [SP++];
    R0 = [SP++];
    RETS = [SP++];
    LINK 0x30;                      /* the replaced instruction */
    P1.L = 0xa3e4; P1.H = 0x8000;
    JUMP (P1);

/* CALL 0x8000323c (read a MIDI interface) in the audio/MIDI driver's probe; R0 = its device, the result in R0 */
    .align 4
    .global _hook_endpoints
_hook_endpoints:
    [--SP] = RETS;
    [--SP] = R0;
    SP += -12;
    P1.L = 0x323c; P1.H = 0x8000;
    CALL (P1);
    SP += 12;
    R1 = R0;
    R0 = [SP++];
    SP += -12;
    CALL _usb_endpoints;
    SP += 12;
    RETS = [SP++];
    RTS;

/* 0x8011ab60, the start of the routine that reads USB MIDI; R0 = who, R1 = the packet, R2 = its length */
    .align 4
    .global _hook_tidy
_hook_tidy:
    [--SP] = RETS;
    [--SP] = R0;
    [--SP] = R1;
    R0 = R1;
    R1 = R2;
    SP += -12;
    CALL _usb_tidy;
    SP += 12;
    R2 = R0;
    R1 = [SP++];
    R0 = [SP++];
    RETS = [SP++];
    LINK 0x8;                       /* the replaced instruction */
    P1.L = 0xab64; P1.H = 0x8011;
    JUMP (P1);

/* 0x8010b770, the start of the routine that takes every control's press and release; R0 = sequencer, R1 = control, R2 = value */
    .align 4
    .global _hook_key
_hook_key:
    [--SP] = RETS;
    [--SP] = R0;
    [--SP] = R1;
    [--SP] = R2;
    SP += -12;
    CALL _host_key;
    SP += 12;
    CC = R0 == 0;
    R2 = [SP++];
    R1 = [SP++];
    R0 = [SP++];
    RETS = [SP++];
    IF CC JUMP .Ltheirs;
    RTS;
.Ltheirs:
    LINK 0x0;                       /* the replaced instruction */
    P1.L = 0xb774; P1.H = 0x8010;
    JUMP (P1);

/* 0x8000a104, the start of the routine that starts a device (address, descriptors, drivers); R0 = device, the result in R0 */
    .align 4
    .global _hook_new
_hook_new:
    [--SP] = RETS;
    [--SP] = R0;
    SP += -12;
    CALL _usb_new;
    SP += 12;
    R0 = [SP];
    SP += -12;
    CALL .Lstart;
    SP += 12;
    R1 = R0;
    R0 = [SP++];
    [--SP] = R1;
    SP += -12;
    CALL _usb_started;
    SP += 12;
    R0 = [SP++];
    RETS = [SP++];
    RTS;
.Lstart:
    LINK 0xc;                       /* the replaced instruction */
    P1.L = 0xa108; P1.H = 0x8000;
    JUMP (P1);

/* 0x800279d8, the start of the routine the keyboard chip's USB-C messages come to; R0 = its object, R1 = the message */
    .align 4
    .global _hook_role
_hook_role:
    [--SP] = RETS;
    [--SP] = R0;
    [--SP] = R1;
    R0 = R1;
    SP += -12;
    CALL _usb_role;
    SP += 12;
    R1 = [SP++];
    R0 = [SP++];
    RETS = [SP++];
    LINK 0x0;                       /* the replaced instruction */
    P1.L = 0x79dc; P1.H = 0x8002;
    JUMP (P1);

/* CALL 0x8003ac64 (DMX) in the UI frame; R0 = its object */
    .align 4
    .global _hook_frame
_hook_frame:
    [--SP] = RETS;
    [--SP] = R0;
    SP += -12;
    CALL _host_tick;
    SP += 12;
    R0 = [SP++];
    RETS = [SP++];
    P1.L = 0xac64; P1.H = 0x8003;
    JUMP (P1);

    .align 4
    .ascii "GALAXZ-USBHOST-3"
    .include "usbhost.gen.S"

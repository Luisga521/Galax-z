/* Galax-z USB host: older keyboards (Yamaha Motif and the like), and a switch for which way MIDI goes.
 *
 * The OP-Z's USB host (smxUSBH) takes an interface only if it says it is Audio Control or MIDI Streaming (class 1). Keyboards of
 * the Motif's time say "vendor specific" (class 0xFF) and came with a driver, but speak ordinary USB-MIDI: Linux drives them with
 * the standard code once it knows them (sound/usb: QUIRK_MIDI_YAMAHA, create_yamaha_midi_quirk; a Motif 6 is 0499:1005,
 * class ff/00/ff, jacks named, two bulk endpoints with nothing after them, notes on port 1: read on the Mac, 2026-11-22).
 * Three things are needed:
 *  1. usb_adopt: before the OS looks for a driver, an interface that is such a keyboard's gets class 1, subclass 3 in the OS's
 *     copy of its descriptors, and what follows them is hidden: the OS copies those by their own length into fixed buffers, and
 *     the Motif's are not made to the standard.
 *  2. usb_endpoints: the OS reads how many ports an endpoint has through a pointer it does not check; where the keyboard gave
 *     none, it gets one that says 16.
 *  3. usb_tidy: the OS stops reading a packet at the first event that is not from port 1, and logs each empty one; those
 *     are taken out first.
 * A device that was taken before is taken as before; 2 and 3 only make it safer.
 *
 * SHIFT held, then P (PROJECT, the first key on the top): INSTRUMENT, the step row flashes blue: the OP-Z sends no MIDI, takes what
 * comes in and plays channel 1 on the selected track. Again: HOST, green: as its MIDI settings had it. It starts as HOST. That press
 * of PROJECT is ours alone (TE's screen does not open); PROJECT first, then SHIFT, is TE's copy as before.
 *
 * What happens on the USB port is written down (struct Report): the cable's role, each device and its descriptors, what was made of
 * it, its first events. SHIFT held, then MIXER, sends it out as notes, a nibble each (tools/usb_report.py reads them on the Mac; the
 * OP-Z must stay on from the keyboard to the Mac).
 *
 * usb_* run in the OS's USB tasks, host_key in the UI/sequencer task. Compiled by tools/usbhost_build.py. */

typedef signed int i32;
typedef unsigned int u32;
typedef unsigned short u16;
typedef unsigned char u8;

static inline void os_note_on(i32 track, i32 note, i32 vel)     /* the OS's MIDI note on, as playNote has it (0x8010ca7a) */
{
    ((void (*)(i32, i32, i32, i32, i32, i32, i32))0x80042140)(track, note, vel, -1, 0x2000, 1, ((u8 *)0x819c2a94)[track]);
}
static inline u8 *os_midi(void) { return (u8 *)0x819c2bb4; }    /* the MIDI settings, a bit each (midi.json) */
static inline void os_light(i32 colour)     /* the 16 steps in a palette colour, fading: the OS's own, as REC's modes flash (0x8011ed90) */
{
    ((void (*)(u8 *, i32, i32, i32, i32, i32, i32))0x8003c60c)(*(u8 **)0x81015e9c, 3, 600, 0, colour, 0, 0);
}
static inline void os_note_off(i32 track, i32 note)     /* the OS's MIDI note off, as 0x8010c630 has it */
{
    ((void (*)(i32, i32, i32, i32, i32, i32))0x800421b8)(track, note, -1, 0x2000, 1, ((u8 *)0x819c2a94)[track]);
}
static inline u8 *os_alloc(i32 size) { return ((u8 *(*)(i32))0x8000b6e8)(size); }   /* the USB host's heap: it frees what we give */
#define STATE __attribute__((section(".data")))      /* in the block: there is no .bss to be cleared */
#define PTR(p, off) (*(u8 **)((p) + (off)))
#define WORD(p, off) (*(i32 *)((p) + (off)))

/* ---- what happened ---- */

typedef struct {
    u8 magic[4];                    /* GZU1 */
    u8 roles, devices, asked, adopted, probed, probe_result, host, spare;       /* how often each happened */
    u16 packets, bytes;             /* MIDI packets since the last device */
    u8 role[8][4];                  /* what the keyboard chip said of the cable: connected, side, role, more; the last eight */
    u8 result;                      /* what the OS's start of the last device came to: 0 good, 255 not */
    u8 speed, interface_class, interface_subclass;
    u8 device[18];                  /* its device descriptor */
    u16 length;                     /* its configuration's, all of it */
    u8 config[256];
    u8 event[8][4];                 /* the first events */
    u8 end, sum;
} Report;

Report STATE report = { .magic = { 'G', 'Z', 'U', '1' } };
static u8 STATE fold = 0;           /* the device is one of ours: every port of it is heard */

void usb_role(const u8 *message)    /* the keyboard chip tells of the USB-C port */
{
    if (!message) return;
    u8 *to = report.role[report.roles++ & 7];
    for (i32 i = 0; i < 4; i++) to[i] = message[0xc + i];
}

void usb_new(void)                  /* a device is there */
{
    report.devices++;
    report.packets = report.bytes = 0;
    report.host = *(u8 *)0x810048dc;
    fold = 0;
}

void usb_started(const u8 *dev, i32 result)     /* what came of it: its descriptors, if they were read */
{
    report.result = (u8)result;
    if (!dev) return;
    report.speed = dev[0];
    for (i32 i = 0; i < 18; i++) report.device[i] = dev[0x5c + i];
    const u8 *config = *(u8 *const *)(dev + 0x74), *const *raw = *(const u8 *const *const *)(dev + 0x78);
    report.length = 0;
    if (!raw || !raw[0] || !config) return;
    u32 n = *(const u16 *)(config + 2);
    report.length = (u16)n;
    for (u32 i = 0; i < 256; i++) report.config[i] = i < n ? raw[0][i] : 0;
}

/* ---- 1. older keyboards ---- */

#define CLASS 5                     /* an interface descriptor: what it says it is */
#define SUBCLASS 6
#define PROTOCOL 7
#define DEV_VENDOR 0x64             /* u16 */
#define DEV_CONFIG 0x74             /* -> the configuration: + 4 the number of interfaces, + 0xc -> them, 0x18 each */
#define ALT 0x18                    /* a setting of an interface: its descriptor, + 0xc -> its endpoints, + 0x10 -> what follows it */
#define EP 0x10                     /* an endpoint: its descriptor, + 8 -> what follows it, + 0xc how long */
#define YAMAHA 0x0499
#define ROLAND 0x0582

/* what follows an interface: does it name MIDI jacks, or is it Roland's mark? */
static i32 names_midi(const u8 *p, i32 n, i32 vendor)
{
    while (n >= 3 && p[0] >= 3 && p[0] <= n) {
        if (p[1] == 0x24) {
            if (vendor == YAMAHA && (p[2] == 2 || p[2] == 3)) return 1;
            if (vendor == ROLAND && p[2] == 0xf1 && p[0] >= 6 && p[3] == 2) return 1;
        }
        n -= p[0]; p += p[0];
    }
    return 0;
}

static i32 adopt(u8 *alt, i32 vendor)
{
    i32 in = 0, out = 0, general = 0, n = alt[4];
    u8 *eps = PTR(alt, 0xc);
    if (alt[CLASS] != 0xff || alt[0] < 9 || n > 8 || !eps) return 0;
    for (i32 i = 0; i < n; i++) {
        const u8 *e = eps + i * EP, *x = PTR(e, 8);
        i32 type = e[3] & 3, left = WORD(e, 0xc);
        if (type != 2 && type != 3) continue;
        if (e[2] & 0x80) in = 1; else out = 1;
        if (x && left >= 4 && x[1] == 0x25 && x[2] == 1) general = 1;       /* MIDI Streaming, general: other makers' */
    }
    if (!in || !out) return 0;                      /* the OS reads both ways without asking whether they are there */
    const u8 *x = PTR(alt, 0x10);
    if (!general && !(x && names_midi(x, WORD(alt, 0x14), vendor))) return 0;
    alt[CLASS] = 1; alt[SUBCLASS] = 3; alt[PROTOCOL] = 0;
    WORD(alt, 0x14) = 0;
    for (i32 i = 0; i < n; i++) WORD(eps + i * EP, 0xc) = 0;
    return 1;
}

void usb_adopt(u8 *dev, u32 number)                 /* the OS is about to look for interface `number`'s driver */
{
    if (!dev) return;
    u8 *config = PTR(dev, DEV_CONFIG);
    if (!config || number >= config[4]) return;
    u8 *list = PTR(config, 0xc);
    if (!list) return;
    u8 *interface = list + number * ALT, *alts = PTR(interface, 0);
    i32 n = WORD(interface, 8);
    if (!alts || n < 1 || n > 8) return;
    report.asked++;
    report.interface_class = alts[CLASS]; report.interface_subclass = alts[SUBCLASS];
    for (i32 i = 0; i < n; i++)
        if (adopt(alts + i * ALT, *(u16 *)(dev + DEV_VENDOR))) { report.adopted++; fold = 1; }
}

/* ---- 2. an endpoint's number of ports ---- */

static void ports(u8 *midi, i32 endpoint, i32 general)
{
    if (!PTR(midi, endpoint) || PTR(midi, general)) return;
    u8 *g = os_alloc(0x14);
    if (!g) return;
    for (i32 i = 0; i < 0x14; i++) g[i] = 0;
    g[0] = 0x14; g[1] = 0x25; g[2] = 1; g[3] = 16;
    PTR(midi, general) = g;
}

i32 usb_endpoints(u8 *device, i32 result)           /* the OS has read a MIDI interface; `result` is what it made of it */
{
    u8 *midi = device && !result ? PTR(device, 0x60) : 0;
    report.probed++;
    report.probe_result = (u8)result;
    if (!midi) return result;
    ports(midi, 0x104, 0x108);
    ports(midi, 0x10c, 0x110);
    /* without memory for the first there is no way to read this device safely: not taken */
    return PTR(midi, 0x104) && !PTR(midi, 0x108) ? -1 : result;
}

/* ---- 3. the events of a packet ---- */

i32 usb_tidy(u8 *p, i32 n)          /* what is left of it, in place: port 1's (every port's of ours), without the empty ones */
{
    i32 out = 0;
    if (!p || n <= 0 || n & 3) return n;            /* the OS has its own answer to these */
    for (i32 i = 0; i < n && i < 32; i += 4)
        if (report.packets + (i >> 2) < 8) for (i32 k = 0; k < 4; k++) report.event[report.packets + (i >> 2)][k] = p[i + k];
    report.packets++;
    report.bytes += (u16)n;
    for (i32 i = 0; i < n; i += 4) {
        if (fold) p[i] &= 15;
        if (p[i] >> 4 || p[i] < 2) continue;
        if (out != i) for (i32 k = 0; k < 4; k++) p[out + k] = p[i + k];
        out += 4;
    }
    return out;
}

/* ---- the switch ---- */

#define SEQ_SHIFT_KEY 0x22          /* byte: SHIFT is down */
#define PROJECT 5                   /* a control's number */
#define PRESSED -1
#define SEQ_NOTES 0x114             /* what sounds: 0x1c each, + 0x10 track, + 0x12 note, + 0x16 not if 0 */
#define SEQ_SOUNDING 0x68c
#define CHANNEL_ONE_TO_ACTIVE 1     /* os_midi's bits */
#define INCOMING 2
#define OUTGOING 4
#define CLOCK_OUT 16
#define ECHO 64
#define OURS (CHANNEL_ONE_TO_ACTIVE | INCOMING | OUTGOING | CLOCK_OUT | ECHO)

static u8 STATE instrument = 0, STATE before = 0;

static void turn(u8 *seq)
{
    u8 *midi = os_midi();
    if (instrument) {
        *midi = (u8)((*midi & ~OURS) | (before & OURS));
        instrument = 0;
        os_light(0x1f);             /* green */
        return;
    }
    i32 n = *(i32 *)(seq + SEQ_SOUNDING);
    for (i32 i = 0; i < n && i < 50; i++) {         /* nothing is left hanging on what is connected */
        const u8 *note = seq + SEQ_NOTES + i * 0x1c;
        if (note[0x10] < 16 && note[0x12] < 128) os_note_off(note[0x10], note[0x12]);
    }
    before = *midi;
    *midi = (u8)((*midi | CHANNEL_ONE_TO_ACTIVE | INCOMING) & ~(OUTGOING | CLOCK_OUT | ECHO));
    instrument = 1;
    os_light(0x2f);                 /* blue */
}

#define MIXER 6
static i32 STATE telling = -1;      /* the next nibble of the report, -1 = none */

i32 host_key(u8 *seq, i32 control, i32 value)       /* a control was pressed or let go. 1: it was ours, and that was all */
{
    if (value != PRESSED || !seq || !seq[SEQ_SHIFT_KEY]) return 0;
    if (control == PROJECT) { turn(seq); return 1; }
    if (control == MIXER) {
        u8 sum = 0;
        for (u32 i = 0; i < sizeof report - 1; i++) sum += ((u8 *)&report)[i];
        report.sum = sum;
        telling = 0;
        return 1;
    }
    return 0;
}

void host_tick(void)                /* every UI frame: the report, a nibble a frame */
{
    if (telling < 0) return;
    if (telling) os_note_off(0, 24 + ((telling - 1) & 63));
    if (telling >= (i32)sizeof report * 2) { telling = -1; return; }
    u8 b = ((u8 *)&report)[telling >> 1];
    os_note_on(0, 24 + (telling & 63), 1 + (telling & 1 ? b & 15 : b >> 4));
    telling++;
}

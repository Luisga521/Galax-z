/* Galax-z keys: what a keyboard plugged in sends besides notes.
 *
 * Sustain (CC 64, 64 and up = down): a note let go while the pedal is down goes on until it comes up. Per MIDI channel, at most 64
 * notes wait; a note played again while it waits is ended first. Both in HOST and INSTRUMENT.
 *
 * Modulation (CC 1), in INSTRUMENT (the OP-Z's MIDI settings: channel 1 to the selected track, nothing sent): vibrato, 5.5 times a
 * second, up to half a semitone either way at the top, on the pitch wheel's value. In HOST CC 1 is P1, as TE has it.
 *
 * A key of channel 1 ends on the track it began on, also when another track has been selected since (TE ends it on the selected one,
 * and the first goes on). What waits is ended when HOST and INSTRUMENT are switched.
 *
 * Everything runs in the OS's UI/sequencer task, where it takes MIDI (0x80110ef4). Compiled by tools/keys_build.py. */

typedef signed int i32;
typedef unsigned int u32;
typedef unsigned char u8;

static inline u8 *os_seq(void) { return *(u8 *volatile *)0x81059d1c; }
static inline u32 os_ms(void) { return ((u32(*)(void))0x80028294)(); }
static inline u8 os_midi(void) { return *(volatile u8 *)0x819c2bb4; }           /* the MIDI settings, a bit each (midi.json) */
static inline void os_note_off(u8 *seq, i32 track, i32 note, i32 source, i32 flags)
{
    ((void (*)(u8 *, i32, i32, i32, i32, i32))0x8010e55c)(seq, track, note, source, flags, 0);  /* Sequencer::noteOff */
}
static inline void os_bend(i32 track, i32 bend)     /* Synth::pitchBend, Q31, +-200 cents: past MIDI, so nothing is sent or shown */
{
    ((void (*)(void *, i32, i32, i32))0x801180dc)(*(void **)0x11900000, track, bend, 0);
}
#define STATE __attribute__((section(".data")))
#define SEQ_TRACK 0x30
#define CHANNEL_ONE_TO_ACTIVE 1
#define OUTGOING 4
#define MIDI 1                      /* a flag of a note: it came in by MIDI */

typedef struct { i32 source, flags; u8 channel, track, note, pad; } Wait;
#define WAITS 64
static Wait STATE waits[WAITS] = { { 0 } };
static i32 STATE nwaits = 0;
static u8 STATE pedal[16] = { 0 };
static u8 STATE began[128] = { 0 };     /* the track a key of channel 1 began on, + 1 */
static u8 STATE wheel = 0, STATE shaken = 0, STATE was_instrument = 0;
static i32 STATE bend[16] = { 0 };      /* the pitch wheel, -8192..8191, by channel */
static u32 STATE wheel_ms = 0;

static i32 instrument(void) { u8 m = os_midi(); return m & CHANNEL_ONE_TO_ACTIVE && !(m & OUTGOING); }

static i32 track_now(const u8 *seq) { return *(const i32 *)(seq + SEQ_TRACK); }

static void let_go(u8 *seq, i32 channel, i32 note)      /* what waits, of a channel (-1 all) and a note (-1 all), ends */
{
    i32 left = 0, n = nwaits;
    for (i32 i = 0; i < n; i++) {
        Wait w = waits[i];
        if ((channel < 0 || w.channel == channel) && (note < 0 || w.note == note)) os_note_off(seq, w.track, w.note, w.source, w.flags);
        else waits[left++] = w;
    }
    nwaits = left;
}

void keys_on(u8 *seq, i32 channel, i32 note)            /* a MIDI note is about to begin */
{
    if (!seq || (u32)channel > 15 || (u32)note > 127) return;
    if (nwaits) let_go(seq, channel, note);
    if (!channel) began[note] = (u8)((os_midi() & CHANNEL_ONE_TO_ACTIVE ? track_now(seq) : 0) + 1);
}

i32 keys_off(u8 *seq, i32 channel, i32 note, i32 source, i32 flags)     /* a MIDI note is let go: the track to end it on, -1 = not now */
{
    if (!seq || (u32)channel > 15 || (u32)note > 127) return channel;
    i32 track = channel;
    if (!channel && began[note]) track = began[note] - 1;
    if (!channel) began[note] = 0;
    if ((u32)track > 15) track = channel;
    if (!pedal[channel] || nwaits >= WAITS) return track;
    Wait *w = &waits[nwaits++];
    w->source = source; w->flags = flags; w->channel = (u8)channel; w->track = (u8)track; w->note = (u8)note; w->pad = 0;
    return -1;
}

i32 keys_control(u8 *seq, i32 channel, i32 control, i32 value)          /* a MIDI control change. 1: it was ours */
{
    if (!seq || (u32)channel > 15) return 0;
    if (control == 64) {
        u8 down = value >= 64;
        pedal[channel] = down;
        if (!down) let_go(seq, channel, -1);
        return 1;
    }
    if (control == 1 && !channel && instrument()) {
        if (!wheel && value) wheel_ms = os_ms();
        wheel = (u8)(value & 127);
        return 1;
    }
    return 0;
}

void keys_bend(i32 channel, i32 low, i32 high)          /* the pitch wheel, on its way to the OS */
{
    if ((u32)channel < 16) bend[channel] = (low & 127) + ((high & 127) << 7) - 8192;
}

static i32 wheel_bend(void)         /* the pitch wheel as the OS makes it (0x80107fba): Q31 and a twentieth more, to the ends */
{
    i32 b = bend[0] * 32;           /* Q16 + 2: room for the twentieth */
    b += b * 13 >> 8;
    return b > 262143 ? 0x7fffffff : b < -262144 ? (i32)0x80000000 : b * 8192;
}

void keys_tick(void)                /* every UI frame */
{
    u8 *seq = os_seq();
    if (!seq) return;
    u8 is = (u8)instrument();
    if (is != was_instrument) {
        was_instrument = is;
        wheel = 0;
        for (i32 i = 0; i < 16; i++) pedal[i] = 0;
        let_go(seq, -1, -1);
    }
    i32 track = track_now(seq);
    if (shaken && (!wheel || shaken - 1 != track)) { os_bend(shaken - 1, wheel_bend()); shaken = 0; }
    if (!wheel || (u32)track > 7) return;
    u32 ms = (os_ms() - wheel_ms) & 0xffff;
    i32 x = (i32)(ms * 360 << 16) >> 16;                /* 5.5 Hz: 65536 a turn, 360 a ms; -32768..32767 */
    i32 a = x < 0 ? -x : x;
    i32 sine = (x * (32768 - a)) >> 13;                 /* a parabola: +-32768 */
    i32 depth = wheel * 2064;                           /* at the top 262128; the sum below has 50 cents there, a quarter of the bend */
    i32 b = (wheel_bend() >> 4) + ((sine * (depth >> 4)) >> 4);     /* Q27: +-134217728 is the end */
    shaken = (u8)(track + 1);
    os_bend(track, b > 134217727 ? 0x7fffffff : b < -134217728 ? (i32)0x80000000 : b * 16);
}

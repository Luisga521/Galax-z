/* Galax-z pages: two more parameter pages on the eight instrument tracks, with two of TO-2's sequencers in them.
 *
 * Page 5, pink: TOMBOLA. Every key (or MIDI note) of the track drops a ball into that track's spinning hexagon, and every bounce
 * plays the ball's note. The dials are TO-2's knobs in TO-2's order: GRAVITY, BOUNCE, SPIN, SCATTER. Up to 8 balls (the oldest
 * leaves).
 *
 * Page 6, teal: EUCLID. Keys latch notes (again: let go; at most 8) and Euclidean pulses play them in turn. STEPS, PULSES,
 * ROTATE, RATE; hold SHIFT for 2 s for MORE (the dials flash twice): GATE, ACCENT, CHANCE, OCTAVES, and again to come back (one
 * flash). On the drum tracks every key has a ring of its own length, all on one clock: a key joins, a key that is in is picked
 * for the dials, the picked one leaves. It runs on the OP-Z's own 96 ticks a beat: from the first step when playing, from the
 * first note when stopped.
 *
 * Each track has its own. They go on when you leave the page or the track. STOP on a page empties it; STOP while the sequencer
 * is already stopped empties all of them. With REC on and playing, the selected track's notes are recorded into its pattern as
 * keys are (nearest step, micro timing, velocity), and so are the turns of these pages' dials, a value a step; a step held while a
 * dial is turned takes its value too. REC with - and a dial: that dial's values go. They are kept per pattern until power-off.
 *
 * The tumbler's physics is TO-2's (TO2/Model/AppState.swift, struct Tombola), constant for constant, in fixed point: positions
 * and speeds in Q24 (1.0 = 1 << 24), unit vectors in Q31, 256 substeps a second (TO-2: 4 per 60 Hz frame). The hexagon is
 * convex, so a ball inside it touches an edge exactly when it is that close to the edge's line: no closest-point search.
 * EUCLID is TO-2's stepEuclid, euclidPulse and ringPulse (TO2/Audio/AudioCore.swift) and enum Euclid (TO2/Model/Patches.swift).
 *
 * Compiled by tools/pages_build.py (bfin-elf-gcc) into pages.gen.S, which pages.S includes with the hooks' veneers.
 * Everything runs in the OS's UI/sequencer task, the same one that plays keys; nothing here runs in an interrupt. */

typedef signed int i32;
typedef unsigned int u32;
typedef unsigned char u8;

#define TRACKS 8
#define BALLS 8
#define PINK 4                      /* the pages, 0-based */
#define TEAL 5
#define RED 6
#define ONE (1 << 24)
#define Q24(x) ((i32)((x) * 16777216.0))
#define Q31(x) ((i32)((x) * 2147483647.0))

/* R G B (the LEDs' green is weak and their red strong) */
static const u8 colour[3][3] = { { 255, 0, 84 }, { 0, 255, 120 }, { 90, 255, 30 } };     /* pink, teal, light green (the red page, as the code calls it: it was) */

#include "groove_data.h"

#ifdef PAGES_TEST                 /* the Mac, for tools/test_pages.py */
typedef long long i64;
static i32 mul(i32 a, i32 b) { return (i32)(((i64)a * b) >> 31); }
u8 *os_seq(void);
u32 os_ms(void);
void os_play(u8 *seq, i32 track, i32 note, i32 vel, i32 len);
void os_led(i32 led, i32 r, i32 g, i32 b, i32 w);
u8 *os_led_record(i32 led);
void os_where(u8 *seq, i32 track, i32 *step, i32 *micro);
void os_record(u8 *seq, i32 track, i32 step, i32 micro, i32 note, i32 vel, i32 len);
u8 *os_pattern(u8 *seq);
i32 os_slot(i32 track);
i32 os_pages(i32 track);
i32 os_page_colour(i32 track, i32 page);
void os_flash(i32 page, i32 colour);
#else                               /* the OP-Z, OS 1.2.45 (notes/device-guide.md 11) */
static inline i32 mul(i32 a, i32 b) { return __builtin_bfin_mult_fr1x32x32(a, b); }
static inline u8 *os_seq(void) { return *(u8 *volatile *)0x81059d1c; }
static inline u32 os_ms(void) { return ((u32(*)(void))0x80028294)(); }
static inline void os_play(u8 *seq, i32 track, i32 note, i32 vel, i32 len)
{
    /* Sequencer::playNote on the live layer, with a length: as the OS's own preview on a track press (0x801259d4) */
    ((void (*)(u8 *, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32))0x8010c894)
        (seq, track, note, note, note, vel, len, 1, 0, -1, 0x2000, 0, 0);
}
static inline void os_led(i32 led, i32 r, i32 g, i32 b, i32 w)
{
    ((void (*)(i32, i32, i32, i32, i32))0x8003d3be)(led, r, g, b, w);
}
static inline u8 *os_led_record(i32 led) { return (u8 *)0x0802d3a4 + led * 5; }
static inline void os_where(u8 *seq, i32 track, i32 *step, i32 *micro)
{
    ((void (*)(u8 *, i32, i32 *, i32 *))0x8010af78)(seq, track, step, micro);   /* the step nearest the playhead, and how far off */
}
static inline void os_record(u8 *seq, i32 track, i32 step, i32 micro, i32 note, i32 vel, i32 len)
{
    /* DefaultContext: add a note to the pattern, as its live recording does (0x8011d264) */
    ((void (*)(u8 *, i32, i32, i32, i32, i32, i32, i32, i32))0x8011cd5c)(seq + 0x346260, 2, track, step, micro, note, vel, len, 0);
}
static inline u8 *os_pattern(u8 *seq) { return *(u8 **)(seq + 0x690 + (*(u32 *)(seq + 0x44) << 3)); }
static inline i32 os_slot(i32 track) { return ((const i32 *)0x811130e8)[track]; }     /* a track's first note of a step's 55 */
static inline i32 os_pages(i32 track) { return ((const i32 *)0x81112f5c)[track]; }    /* a track's parameter pages (SHIFT: 0x8011ebe4) */
static inline i32 os_page_colour(i32 track, i32 page)                                  /* the colour SHIFT flashes for a page (0x8011ec14) */
{
    signed char kind = ((const signed char *)0x811131cc)[track * 6 + page];
    return kind < 0 ? -1 : ((const u8 *)0x811130cc)[kind];
}
static inline void os_flash(i32 page, i32 colour)
{
    /* the dial LEDs' flash of a page turn, as SHIFT starts it (0x8011ec40): overlay 2, 500 ms, the page, its colour */
    ((void (*)(u32, i32, i32, i32, i32, i32, i32))0x8003c60c)(*(volatile u32 *)0x81015e9c, 2, 500, page, colour, 0, 0);
}
#endif

static inline i32 word(const u8 *seq, u32 at) { return *(const i32 *)(seq + at); }

#define SEQ_PLAYING 0x1c            /* byte */
#define SEQ_SHIFT 0x14              /* byte: SHIFT is down */
#define SEQ_REC_HELD 0x1d           /* byte */
#define SEQ_REC 0x1f                /* byte */
#define SEQ_TRACK 0x30
#define SEQ_HELD_STEP 0x7c          /* 31: none */
#define SEQ_PATTERN 0x44            /* project x 16 + pattern */
#define SEQ_SOUNDING 0x68c          /* notes sounding now, at most 50 */
#define SEQ_TICK 0x40               /* 0-23 in the step */
#define SEQ_STEP 0x38
#define SEQ_LENGTH 0x3c
#define SEQ_TRACK_STEP 0x345d3a     /* a byte a track: the step in bits 4-7 */
#define SEQ_PAGE 0x345e2c
#define SEQ_STEPS 0x346260          /* the normal step screen */
#define SEQ_ERASING 0x346270        /* the step screen's: REC with -, notes are taken out */
#define SEQ_SCREEN 0x3463bc         /* the screen on now */
#define SEQ_CLEAN 0x39c123          /* byte: SHIFT was the last control pressed (its release then turns the page) */
#define SEQ_SCREEN_KEY 0x27         /* byte: SCREEN is down (what the OS's $06 tells an app, 0x801088ac) */
#define JOG 4                       /* the blue dial's clicks a page, SCREEN held */

typedef struct { i32 x, y, vx, vy; u8 note, flash, rest, pad; } Ball;
typedef struct { Ball ball[BALLS]; i32 n; u32 rot; } Tumbler;

typedef struct { u8 key, steps, pulses, rot; } Ring;
typedef struct {
    i32 n;                          /* notes latched, or rings */
    Ring ring[BALLS];               /* a latched note is a ring's key */
    i32 next, pulses;               /* the note that is next, the pulses so far */
    u8 pick, more, turned[2];       /* drums: the ring the dials turn; the MORE layer is on */
    i32 slack[3];                   /* drums: turns not yet a step */
} Euclid;

#define KNOBS 12
enum { GRAVITY, BOUNCE, SPIN, SCATTER, STEPS, PULSES, ROTATE, RATE, GATE, ACCENT, CHANCE, OCTAVES };
/* TO-2's defaults, of 255: .45 .6 .25 .15 | .45 .3 0 .6 | .5 .3 1 0 */
#define AS_NEW { 115, 153, 64, 38, 115, 77, 0, 153, 128, 77, 255, 0 }


/* the seventh page, light green ("red" here: it was, in v11 and v12): notes kept, played by a groove; on a melodic track a progression takes them through its chords */
typedef struct { u8 n, key[BALLS], next, more; } Groove;
enum { GROOVE, G_RATE, G_GATE, ORDER, PROG, KEY, LENGTH, SWING, GKNOBS };
/* TRESILLO, 1/16, .6, CHORD | off, C, a bar, straight */
#define RED_NEW { 0, 153, 153, 0, 0, 0, 64, 0 }

#ifdef PAGES_TEST
#define STATE
#else
#define STATE __attribute__((section(".data")))      /* in the block: there is no .bss to be cleared */
#endif
Tumbler STATE tumblers[TRACKS] = { { .n = 0 } };
Euclid STATE euclids[TRACKS] = { { 0 } };
u8 knob[TRACKS][KNOBS] = { AS_NEW, AS_NEW, AS_NEW, AS_NEW, AS_NEW, AS_NEW, AS_NEW, AS_NEW };       /* as the dials were left */
Groove STATE grooves[TRACKS] = { { 0 } };
u8 gknob[TRACKS][GKNOBS] = { RED_NEW, RED_NEW, RED_NEW, RED_NEW, RED_NEW, RED_NEW, RED_NEW, RED_NEW };
static u8 STATE now[TRACKS][KNOBS] = { { 0 } };     /* as they are on this step */
static u32 STATE beat = 0, STATE shift_ms = 0, STATE flash_ms = 0;     /* beat: ticks on the grid */
/* a dial turned while recording keeps its value, and gives it to the steps that come, for a second after the last turn */
static u8 STATE hand[KNOBS] = { 0 };
static u32 STATE hand_ms[KNOBS] = { 0 };
static i32 STATE hands = 0, STATE hand_track = 0;
static u8 STATE waiting = 0, STATE was_playing = 0, STATE shift_held = 0, STATE flashes = 0;
u8 STATE touched = 0;               /* a key was pressed while SHIFT was down (pages.S sets it) */
static i32 STATE jog_slack = 0;     /* SCREEN + blue: clicks not yet a page */
static u8 STATE jogged = 0;         /* SCREEN + blue turned the page: flash it when SCREEN is let go */

/* recorded dials: a value (0-254) or 255 = none, for each pattern, track, dial and step. They live past our block in memory
 * nothing in the OS refers to; a dial's 16 are filled when its bit in `locked` is first set, so nothing there is read before. */
#define PATTERNS 160
typedef u8 Lock[TRACKS][KNOBS][16];
static unsigned short STATE locked[PATTERNS][TRACKS] = { { 0 } };
#ifdef PAGES_TEST
static Lock locks[PATTERNS];
#else
#define locks ((Lock *)0x80c40000)
#endif

static u32 STATE last_ms = 0, STATE acc = 0, STATE seed = 0x6a09e667;
typedef struct { short step, micro; i32 len; u8 track, note, vel, pad; } Take;
#define TAKES 16
static Take STATE takes[TAKES] = { { 0 } };
static i32 STATE ntakes = 0;
static u8 STATE running = 0, STATE glow[16] = { 0 }, STATE spark[16] = { 0 }, STATE tick4 = 0;

/* a quarter sine, Q15, 65 entries; the rest by symmetry, linear in between */
static const short sine[65] = {
    0, 804, 1608, 2410, 3212, 4011, 4808, 5602, 6393, 7179, 7962, 8739, 9512, 10278, 11039, 11793, 12539, 13279, 14010,
    14732, 15446, 16151, 16846, 17530, 18204, 18868, 19519, 20159, 20787, 21403, 22005, 22594, 23170, 23731, 24279, 24811,
    25329, 25832, 26319, 26790, 27245, 27683, 28105, 28510, 28898, 29268, 29621, 29956, 30273, 30571, 30852, 31113, 31356,
    31580, 31785, 31971, 32137, 32285, 32412, 32521, 32609, 32678, 32728, 32757, 32767 };

static i32 sin31(u32 turn)          /* Q31, turn: 2^32 = one turn */
{
    u32 q = turn >> 30, f = turn & 0x3fffffff;
    if (q & 1) f = 0x40000000 - f;
    u32 i = f >> 24;
    i32 a = sine[i], b = i < 64 ? sine[i + 1] : a;
    i32 v = (a << 16) + (b - a) * (i32)((f >> 8) & 0xffff);
    return q & 2 ? -v : v;
}

static i32 noise(void)              /* Q31, -1..1 */
{
    seed ^= seed << 13; seed ^= seed >> 17; seed ^= seed << 5;
    return (i32)seed;
}

static u32 root(u32 v)              /* integer square root */
{
    u32 r = 0, b = 1u << 30;
    while (b > v) b >>= 2;
    while (b) {
        if (v >= r + b) { v -= r + b; r = (r >> 1) + b; } else r >>= 1;
        b >>= 2;
    }
    return r;
}

static u32 divide(u32 n, u32 d)     /* without libgcc; rare */
{
    u32 q = 0, r = 0;
    for (i32 i = 31; i >= 0; i--) {
        r = r << 1 | (n >> i & 1);
        q <<= 1;
        if (r >= d) { r -= d; q |= 1; }
    }
    return q;
}

/* the track whose page (PINK, TEAL or RED) the OP-Z shows, -1 = neither */
static i32 on_page(const u8 *seq, i32 page)
{
    if (!seq || word(seq, SEQ_PAGE) != page) return -1;
    u32 t = (u32)word(seq, SEQ_TRACK);
    return t < TRACKS ? (i32)t : -1;
}
static i32 our_page(const u8 *seq)  /* 0 pink, 1 teal, 2 red, -1 none of them */
{
    return on_page(seq, PINK) >= 0 ? 0 : on_page(seq, TEAL) >= 0 ? 1 : on_page(seq, RED) >= 0 ? 2 : -1;
}

/* ---- recorded dials ---- */

static u8 *lock_row(const u8 *seq, i32 track, i32 k)        /* a dial's 16 values in this pattern, 0 = not recorded */
{
    u32 p = (u32)word(seq, SEQ_PATTERN);
    return p < PATTERNS && locked[p][track] >> k & 1 ? locks[p][track][k] : 0;
}
static void set_lock(const u8 *seq, i32 track, i32 k, i32 step, i32 v)
{
    u32 p = (u32)word(seq, SEQ_PATTERN);
    if (p >= PATTERNS || (u32)step > 15) return;
    u8 *row = locks[p][track][k];
    if (!(locked[p][track] >> k & 1)) {
        for (i32 i = 0; i < 16; i++) row[i] = 255;
        locked[p][track] |= (unsigned short)(1 << k);
    }
    row[step] = v > 254 ? 254 : (u8)v;
}
static i32 step_of(const u8 *seq, i32 track) { return seq[SEQ_TRACK_STEP + track] >> 4; }

static i32 recording(const u8 *seq, i32 track);

static void set_now(const u8 *seq)  /* every tick: the dials as this step has them */
{
    if (hands) {
        u32 ms = os_ms();
        for (i32 k = 0; k < KNOBS; k++)
            if (hands >> k & 1) {
                if (ms - hand_ms[k] >= 1000 || !recording(seq, hand_track)) hands &= ~(1 << k);
                else set_lock(seq, hand_track, k, step_of(seq, hand_track), hand[k]);
            }
    }
    for (i32 t = 0; t < TRACKS; t++)
        for (i32 k = 0; k < KNOBS; k++) {
            u8 *row = seq[SEQ_PLAYING] ? lock_row(seq, t, k) : 0;
            u8 v = row ? row[step_of(seq, t)] : 255;
            now[t][k] = v == 255 ? knob[t][k] : v;
        }
}

static i32 recording(const u8 *seq, i32 track)
{
    return seq[SEQ_PLAYING] && (seq[SEQ_REC] | seq[SEQ_REC_HELD]) && track == word(seq, SEQ_TRACK)
        && word(seq, SEQ_HELD_STEP) == 31 && !word(seq, SEQ_ERASING);
}

static void drop(Tumbler *t, i32 note)
{
    if (t->n >= BALLS) {            /* the oldest leaves */
        for (i32 i = 0; i < BALLS - 1; i++) t->ball[i] = t->ball[i + 1];
        t->n = BALLS - 1;
    }
    Ball *b = &t->ball[t->n++];
    b->x = mul(noise(), Q24(0.25));
    b->y = -Q24(0.3);
    b->vx = mul(noise(), Q24(0.5));
    b->vy = Q24(0.1) + mul(noise(), Q24(0.2));
    b->note = (u8)note; b->flash = 0; b->rest = 0;
}

static void write(u8 *seq, const Take *k)
{
    const u8 *pattern = os_pattern(seq);
    if (!pattern) return;
    for (i32 i = os_slot(k->track); i < os_slot(k->track + 1); i++)     /* the step has this note: nothing to add */
        if (pattern[0xc0 + (k->step * 55 + i) * 8 + 4] == k->note) return;
    os_record(seq, k->track, k->step, k->micro, k->note, k->vel, k->len);
}

/* A note written ahead of the playhead would be played a second time when the playhead gets there: each waits until the
 * playhead is a tick (8 of micro timing) past both its step and itself. */
static void write_waiting(u8 *seq)
{
    i32 left = 0;
    for (i32 i = 0; i < ntakes; i++) {
        Take *k = &takes[i];
        i32 step, micro;
        if (seq[SEQ_PLAYING]) {
            os_where(seq, k->track, &step, &micro);
            if (step == k->step && (micro < 8 || micro < k->micro + 8)) { takes[left++] = *k; continue; }
        }
        write(seq, k);
    }
    ntakes = left;
}

static void record(u8 *seq, i32 track, i32 note, i32 vel, i32 len)
{
    i32 step, micro;
    if (!recording(seq, track)) return;
    os_where(seq, track, &step, &micro);
    if ((u32)step > 15) return;
    for (i32 i = 0; i < ntakes; i++)                            /* one of these is already on its way to this step */
        if (takes[i].track == track && takes[i].step == step && takes[i].note == note) return;
    Take k = { (short)step, (short)micro, len, (u8)track, (u8)note, (u8)vel, 0 };
    if (ntakes < TAKES) takes[ntakes++] = k;
    else write(seq, &k);
}

/* A note, played now if the OP-Z has room for it. The length is in 1/96 beats x 256; the OS multiplies it by the track's step
 * length, so it is divided by that first. */
static void play(u8 *seq, i32 track, i32 note, i32 vel, i32 length)
{
    if (word(seq, SEQ_SOUNDING) >= 40) return;                  /* the OS drops notes at 50 and logs it */
    const u8 *pattern = os_pattern(seq);
    i32 step = pattern ? pattern[track * 12 + 6] : 1;
    step = step == 9 ? 16 : step == 0 || step > 8 ? 1 : step;
    i32 len = (i32)divide((u32)length, (u32)step);
    os_play(seq, track, note, vel, len);
    record(seq, track, note, vel, len);
}

/* 1/256 s for one hexagon */
static void substep(u8 *seq, i32 track, Tumbler *t)
{
    const i32 R = Q24(0.075);                                   /* a ball's radius */
    const i32 WALL = Q24(0.86 * 0.86602540378 - 0.075);         /* as far as a ball's centre gets towards an edge */
    const u8 *set = now[track];
    i32 dv = 98304 + set[GRAVITY] * 2570;                         /* (1.5 + 10 g) / 256 */
    i32 e = Q31(0.3) + set[BOUNCE] * 5221294;                    /* 0.3 + 0.62 b, Q31 */
    i32 w = set[SPIN] * 4631787;                               /* 2.2 s rad/s, Q29 */
    i32 scatter = set[SCATTER] * 52634;                           /* 0.8 s, Q24 */
    i32 ox[6], oy[6];                                           /* the edges' outward normals, Q31 */
    i32 hits = 0; u8 note[BALLS], vel[BALLS];

    t->rot += set[SPIN] * 23037;                               /* w / 256, in turns */
    for (i32 k = 0; k < 3; k++) {
        u32 a = t->rot + 357913941 + (u32)k * 715827883;        /* + 30 degrees, + 60 each */
        ox[k] = sin31(a + 0x40000000); oy[k] = sin31(a);
        ox[k + 3] = -ox[k]; oy[k + 3] = -oy[k];
    }

    for (i32 i = 0; i < t->n; i++) {
        Ball *b = &t->ball[i];
        b->vy += dv;
        b->x += b->vx >> 8;
        b->y += b->vy >> 8;
        if (b->flash > 5) b->flash -= 5; else b->flash = 0;     /* gone in 0.2 s */
        if (b->rest) b->rest--;

        for (i32 k = 0; k < 6; k++) {
            i32 pen = mul(b->x, ox[k]) + mul(b->y, oy[k]) - WALL;
            if (pen <= 0) continue;
            i32 nx = -ox[k], ny = -oy[k];                       /* the contact's normal, towards the ball */
            i32 cx = b->x + mul(R, ox[k]), cy = b->y + mul(R, oy[k]);
            i32 wvx = mul(cy, w) * -4, wvy = mul(cx, w) * 4;         /* how fast the wall moves there */
            i32 rvx = b->vx - wvx, rvy = b->vy - wvy;
            i32 vn = mul(rvx, nx) + mul(rvy, ny);

            b->x += mul(pen, nx);
            b->y += mul(pen, ny);
            if (vn >= 0) continue;
            i32 impact = -vn;
            if (impact > Q24(0.35)) {                           /* a bounce you hear */
                i32 out = impact + mul(impact, e);              /* (1 + e) */
                i32 x = rvx + mul(out, nx), y = rvy + mul(out, ny);
                i32 tx = -ny, ty = nx;
                i32 vt = mul(mul(x, tx) + mul(y, ty), Q31(0.88)) + mul(noise(), scatter);
                i32 vnn = mul(x, nx) + mul(y, ny);
                b->vx = wvx + mul(vnn, nx) + mul(vt, tx);
                b->vy = wvy + mul(vnn, ny) + mul(vt, ty);
                if (!b->rest && hits < BALLS) {                 /* at most one note per ball in 40 ms */
                    i32 v = 38 + ((impact >> 16) * 48 >> 8);    /* 0.3 + 0.38 impact */
                    note[hits] = b->note; vel[hits++] = v > 127 ? 127 : (u8)v;
                    b->rest = 10;
                }
                b->flash = 255;
            } else {                                            /* rolling, resting */
                b->vx = wvx + mul(rvx + mul(impact, nx), Q31(0.998));
                b->vy = wvy + mul(rvy + mul(impact, ny), Q31(0.998));
            }
        }
        for (i32 j = 0; j < 4; j++) {                           /* no faster than 5 */
            i32 sx = b->vx >> 13, sy = b->vy >> 13;             /* Q11 */
            if (sx * sx + sy * sy <= 10240 * 10240) break;
            b->vx -= b->vx >> 3; b->vy -= b->vy >> 3;
        }
    }

    for (i32 i = 0; i < t->n - 1; i++)                          /* balls against balls */
        for (i32 j = i + 1; j < t->n; j++) {
            Ball *a = &t->ball[i], *c = &t->ball[j];
            i32 dx = (c->x - a->x) >> 8, dy = (c->y - a->y) >> 8;       /* Q16 */
            if (dx > 9830 || dx < -9830 || dy > 9830 || dy < -9830) continue;
            u32 d2 = (u32)(dx * dx) + (u32)(dy * dy);
            if (d2 >= 9830u * 9830u || d2 < 64) continue;
            u32 d = root(d2);
            i32 nx = (i32)divide((u32)(dx < 0 ? -dx : dx) << 15, d), ny = (i32)divide((u32)(dy < 0 ? -dy : dy) << 15, d);
            nx = nx > 32767 ? 32767 : nx; ny = ny > 32767 ? 32767 : ny;
            nx = (dx < 0 ? -nx : nx) * 65536; ny = (dy < 0 ? -ny : ny) * 65536;     /* Q31 */
            i32 apart = (9830 - (i32)d) << 7;                   /* half the overlap, Q24 */
            a->x -= mul(apart, nx); a->y -= mul(apart, ny);
            c->x += mul(apart, nx); c->y += mul(apart, ny);
            i32 vn = mul(c->vx - a->vx, nx) + mul(c->vy - a->vy, ny);
            if (vn >= 0) continue;
            i32 imp = -(vn + mul(vn, mul(e, Q31(0.9)))) >> 1;
            a->vx -= mul(imp, nx); a->vy -= mul(imp, ny);
            c->vx += mul(imp, nx); c->vy += mul(imp, ny);
            if (-vn > Q24(0.6)) {
                if (a->flash < 153) a->flash = 153;
                if (c->flash < 153) c->flash = 153;
            }
        }

    for (i32 i = 0; i < hits; i++) play(seq, track, note[i], vel[i], 36 << 8);     /* TO-2's 180 ms at 120 */
}

/* where the balls are, across the 16 step LEDs, 64 times a second */
static void look(const Tumbler *t)
{
    for (i32 i = 0; i < 16; i++) glow[i] = spark[i] = 0;
    for (i32 i = 0; i < t->n; i++) {
        const Ball *b = &t->ball[i];
        i32 x = ((b->x >> 12) + 2744) * 2867 >> 12;             /* -0.67..0.67 to 0..15 in Q8 */
        if (x < 0) x = 0;
        if (x > 3840) x = 3840;
        i32 at = x >> 8, f = x & 255;
        for (i32 k = 0; k < 2 && at + k < 16; k++) {
            i32 part = k ? f : 256 - f, lit = part * (110 + (b->flash >> 1)) >> 8, hot = part * b->flash >> 8;
            if (lit > glow[at + k]) glow[at + k] = (u8)lit;
            if (hot > spark[at + k]) spark[at + k] = (u8)hot;
        }
    }
}

/* ---- EUCLID ---- */

static const u8 DIV[7] = { 96, 64, 48, 32, 24, 16, 12 };    /* ticks a step: a beat, 2/3, 1/2, 1/3, 1/4, 1/6, 1/8 */

static i32 e_steps(i32 v) { return 2 + (v * 3852 >> 16); }                  /* 2-16 */
static i32 e_pulses(i32 v, i32 n) { i32 k = 1 + (v * n >> 8); return k > n ? n : k; }
static i32 e_rot(i32 v, i32 n) { i32 r = v * n >> 8; return r > n - 1 ? n - 1 : r; }
static u32 modulo(u32 a, u32 n) { return a - divide(a, n) * n; }
static i32 is_pulse(i32 i, i32 n, i32 k, i32 rot)
{
    i32 j = i + rot;
    while (j >= n) j -= n;
    j *= k;
    while (j >= n) j -= n;
    return j < k;
}
static i32 chance(i32 v) { return v >= 254 || (i32)((u32)noise() >> 24) < v; }
static i32 step_ticks(i32 track) { return DIV[now[track][RATE] * 1796 >> 16]; }

static void euclid_step(u8 *seq, i32 track)         /* the grid is on one of this track's steps */
{
    Euclid *e = &euclids[track];
    const u8 *set = now[track];
    i32 ticks = step_ticks(track);
    u32 at = divide(beat, (u32)ticks);
    if (track < 4) {                                /* drums: every ring at its own length */
        for (i32 r = 0; r < e->n; r++) {
            const Ring *g = &e->ring[r];
            i32 i = (i32)modulo(at, g->steps);
            if (!is_pulse(i, g->steps, g->pulses, g->rot) || !chance(set[CHANCE])) continue;
            play(seq, track, g->key, i ? 109 - (set[ACCENT] * 51 >> 8) : 109 + (set[ACCENT] * 18 >> 8), 24 << 8);
        }
        return;
    }
    i32 n = e_steps(set[STEPS]), k = e_pulses(set[PULSES], n), i = (i32)modulo(at, (u32)n);
    if (!is_pulse(i, n, k, e_rot(set[ROTATE], n)) || !chance(set[CHANCE])) return;
    if (e->next >= e->n) e->next = 0;
    i32 note = e->ring[e->next].key, octaves = set[OCTAVES] * 1025 >> 16;
    e->next++;
    if (octaves) note += 12 * (i32)modulo((u32)e->pulses, (u32)octaves + 1);
    e->pulses = (e->pulses + 1) & 0xffff;
    while (note > 127) note -= 12;
    i32 length = ticks * (26 + (set[GATE] * 218 >> 8));
    play(seq, track, note, i ? 114 - (set[ACCENT] * 57 >> 8) : 114 + (set[ACCENT] * 13 >> 8), length < 256 ? 256 : length);
}

static void euclid_tick(u8 *seq)    /* once a tick: 96 a beat, playing or not */
{
    i32 any = 0;
    for (i32 t = 0; t < TRACKS; t++) any |= euclids[t].n;
    u32 playing = seq[SEQ_PLAYING];
    if (playing && !was_playing) waiting = 1;       /* the grid starts with the sequencer's first step */
    if (!playing) waiting = 0;
    was_playing = (u8)playing;
    i32 at_top = playing && !word(seq, SEQ_TICK) && !word(seq, SEQ_STEP);
    if (waiting) {
        if (word(seq, SEQ_TICK)) return;
        waiting = 0;
        beat = 0;
    } else {
        beat++;
        /* started again while playing: the top of the bar is not where our grid has it */
        u32 bar = (u32)word(seq, SEQ_LENGTH);
        if (at_top && bar - 1 < 64 && modulo(beat, bar * 24)) beat = 0;
    }
    if (!any) return;
    for (i32 t = 0; t < TRACKS; t++)
        if (euclids[t].n && !modulo(beat, (u32)step_ticks(t))) euclid_step(seq, t);
}

static i32 anything(void)           /* EUCLID's or a groove's notes are kept on some track */
{
    i32 any = 0;
    for (i32 t = 0; t < TRACKS; t++) any |= euclids[t].n | grooves[t].n;
    return any;
}

static void latch(u8 *seq, i32 track, i32 note)
{
    static const u8 fresh[8][2] = { {16,4}, {16,3}, {12,5}, {16,7}, {10,3}, {16,5}, {14,3}, {9,4} };
    Euclid *e = &euclids[track];
    i32 at = -1;
    if (!anything() && !seq[SEQ_PLAYING]) beat = 0xffffffff;       /* stopped, the first note: on the next tick */
    for (i32 i = 0; i < e->n; i++) if (e->ring[i].key == note) at = i;
    if (at >= 0) {
        if (track < 4 && e->pick != at) { e->pick = (u8)at; return; }
        for (i32 i = at; i < e->n - 1; i++) e->ring[i] = e->ring[i + 1];
        e->n--;
        if (e->pick >= e->n) e->pick = (u8)(e->n ? e->n - 1 : 0);
        return;
    }
    if (e->n >= BALLS) {
        for (i32 i = 0; i < BALLS - 1; i++) e->ring[i] = e->ring[i + 1];
        e->n = BALLS - 1;
    }
    Ring *r = &e->ring[e->n];
    r->key = (u8)note; r->steps = fresh[e->n][0]; r->pulses = fresh[e->n][1]; r->rot = 0;
    e->pick = (u8)e->n++;
}

/* ---- the seventh page: grooves and progressions (TO-2's) ---- */

static i32 progression(i32 track, const u8 *set) { return track < 4 ? 0 : set[PROG] * (PROGS + 1) >> 8; }     /* 0: none */
static i32 groove_ticks(const u8 *set) { return DIV[set[G_RATE] * 1796 >> 16]; }
static i32 groove_of(const u8 *set) { return set[GROOVE] * GROOVES >> 8; }

/* the notes the groove has now, lowest first (as they were played, for PLAYED); how many */
static i32 groove_notes(i32 track, const Groove *g, const u8 *set, u8 *out)
{
    i32 p = progression(track, set);
    if (p) {
        static const u8 degree[8] = { 0, 2, 4, 5, 7, 9, 11, 0 };
        p--;
        u32 n = (u32)(prog_at[p + 1] - prog_at[p]), bar = 24u * 8 << (set[LENGTH] * 4 >> 8);
        u8 c = prog[prog_at[p] + modulo(divide(beat == 0xffffffff ? 0 : beat, bar), n)];
        u32 pc = modulo((u32)((set[KEY] * 12 >> 8) + degree[((c & 7) - 1) & 7] - (c >> 7) + 12), 12);
        i32 base = g->key[0] - (i32)modulo((u32)(g->key[0] - (i32)pc + 120), 12), m = 0;       /* the root at the key kept, or under it */
        const u8 *tones = chord_notes[c >> 3 & 15];
        for (i32 i = 0; i < 5 && tones[i] != 255; i++) {
            i32 note = base + tones[i];
            while (note < 0) note += 12;
            while (note > 127) note -= 12;
            out[m++] = (u8)note;
        }
        return m;
    }
    for (i32 i = 0; i < g->n; i++) {
        i32 at = i;
        if (set[ORDER] * 5 >> 8 != 3) for (; at && out[at - 1] > g->key[i]; at--) out[at] = out[at - 1];
        out[at] = g->key[i];
    }
    return g->n;
}

static void groove_step(u8 *seq, i32 track, i32 step)
{
    Groove *g = &grooves[track];
    const u8 *set = gknob[track];
    i32 which = groove_of(set);
    u32 bit = 1u << (step & 15);
    if (!(groove[which].hit & bit)) return;
    i32 vel = groove[which].accent & bit ? 118 : groove[which].ghost & bit ? 45 : 85, length = groove_ticks(set) * (26 + (set[G_GATE] * 218 >> 8));
    if (length < 256) length = 256;
    u8 notes[BALLS];
    i32 n = groove_notes(track, g, set, notes), order = set[ORDER] * 5 >> 8;
    if (n <= 0) return;
    if (!order) { for (i32 i = 0; i < n; i++) play(seq, track, notes[i], vel, length); return; }
    u32 k = order == 4 ? (u32)noise() >> 8 : g->next;
    k = modulo(k, (u32)n);
    g->next = (u8)modulo(g->next + 1u, 240);        /* 240: whole rounds of 1-6 and 8 notes */
    play(seq, track, notes[order == 2 ? n - 1 - (i32)k : (i32)k], vel, length);
}

static void groove_tick(u8 *seq)    /* after EUCLID's, whose grid it goes by */
{
    if (waiting || beat == 0xffffffff) return;
    for (i32 t = 0; t < TRACKS; t++) {
        if (!grooves[t].n) continue;
        const u8 *set = gknob[t];
        u32 ticks = (u32)groove_ticks(set), at = divide(beat, ticks), off = beat - at * ticks;
        u32 late = at & 1 ? ticks * set[SWING] * 84 >> 16 : 0;          /* a third of a step, at the most */
        if (off == late) groove_step(seq, t, (i32)(at & 15));
    }
}

static void keep(u8 *seq, i32 track, i32 note)
{
    Groove *g = &grooves[track];
    if (!anything() && !seq[SEQ_PLAYING]) beat = 0xffffffff;            /* stopped, the first note: on the next tick */
    for (i32 i = 0; i < g->n; i++)
        if (g->key[i] == note) {                                        /* again: it is let go */
            for (; i < g->n - 1; i++) g->key[i] = g->key[i + 1];
            g->n--;
            return;
        }
    if (progression(track, gknob[track])) g->n = 0;                     /* one key is where the chords are */
    if (g->n >= BALLS) {
        for (i32 i = 0; i < BALLS - 1; i++) g->key[i] = g->key[i + 1];
        g->n = BALLS - 1;
    }
    g->key[g->n++] = (u8)note;
}

/* ---- the hooks (pages.S) ---- */

static void balls_tick(u8 *seq)
{
    i32 any = 0;
    for (i32 k = 0; k < TRACKS; k++) any |= tumblers[k].n;
    if (!any) {
        if (running) for (i32 i = 0; i < 16; i++) glow[i] = spark[i] = 0;
        running = 0;
        return;
    }
    u32 ms = os_ms();
    if (!running) { running = 1; last_ms = ms; acc = 0; seed ^= ms | 1; if (!seed) seed = 1; }
    u32 dt = ms - last_ms;
    last_ms = ms;
    if (dt > 33) dt = 33;
    acc += dt << 8;                 /* a substep is 1000 */
    while (acc >= 1000) {
        acc -= 1000;
        for (i32 k = 0; k < TRACKS; k++) if (tumblers[k].n) substep(seq, k, &tumblers[k]);
        if (!(++tick4 & 3)) { i32 t = on_page(seq, PINK); if (t >= 0) look(&tumblers[t]); }
    }
}

static void shift_tick(u8 *seq)     /* SHIFT alone for 2 s on the teal or the red page: MORE, or back */
{
    i32 t = on_page(seq, TEAL), r = on_page(seq, RED);
    for (i32 k = 0; k < TRACKS; k++) { if (k != t) euclids[k].more = 0; if (k != r) grooves[k].more = 0; }
    if (!seq[SEQ_SHIFT] || (t < 0 && r < 0)) { shift_held = touched = 0; return; }
    if (!seq[SEQ_CLEAN] || touched) { shift_held = 2; return; }     /* something else was done with it */
    if (shift_held == 2) return;
    u32 ms = os_ms();
    if (!shift_held) { shift_held = 1; shift_ms = ms; return; }
    if (ms - shift_ms < 2000) return;
    shift_held = 2;
    seq[SEQ_CLEAN] = 0;             /* letting go now does not turn the page */
    u8 *more = t >= 0 ? &euclids[t].more : &grooves[r].more;
    *more ^= 1;
    flashes = *more ? 2 : 1;
    flash_ms = ms;
}

/* SCREEN held (v14). The OS then puts its SCREEN screen on (0x8010a360), and the dials go to that screen's onCC (0x8011e516) and not to
 * DefaultContext's: each click goes out as CC 105-108 on channel 16, 1 one way and 127 the other (what TE's app turned its pages
 * by, and the Galax-z app does). The blue dial is taken here instead: it turns the OP-Z's parameter pages, both ways. The page
 * flashes on the dial LEDs when SCREEN is let go: while it is down the SCREEN screen has the LEDs. */
static void screen_up(u8 *seq)
{
    jog_slack = 0;
    if (!jogged) return;
    jogged = 0;
    i32 track = word(seq, SEQ_TRACK), page = word(seq, SEQ_PAGE);
    if ((u32)track >= 16 || (u32)page >= 8) return;
    i32 c = os_page_colour(track, page);
    if (c >= 0) os_flash(page, c);
}

i32 pages_screen(i32 control, i32 delta)        /* a dial turned on the SCREEN screen. 1: it was ours */
{
    u8 *seq = os_seq();
    if (!seq || control != 2 || !delta) return 0;
    i32 track = word(seq, SEQ_TRACK), d = 0;
    if ((u32)track >= 16) return 0;
    jog_slack += delta;
    while (jog_slack >= JOG) { jog_slack -= JOG; d++; }
    while (jog_slack <= -JOG) { jog_slack += JOG; d--; }
    if (!d) return 1;
    i32 n = os_pages(track), page = word(seq, SEQ_PAGE) + (d > 0 ? 1 : -1);    /* a page at a time, however fast */
    if (n < 2 || n > 8) return 1;
    page = page < 0 ? n - 1 : page >= n ? 0 : page;
    *(i32 *)(seq + SEQ_PAGE) = page;                                            /* as the OS's own CC 102 sets it (0x801101cc) */
    jogged = 1;
    return 1;
}

void pages_tick(u8 *seq)            /* before every UI frame, which is once a sequencer tick */
{
    if (!seq) return;
    if (!seq[SEQ_SCREEN_KEY]) screen_up(seq);
    set_now(seq);
    if (ntakes) write_waiting(seq);
    euclid_tick(seq);
    groove_tick(seq);
    balls_tick(seq);
    shift_tick(seq);
}

void pages_note(u8 *seq, i32 track, i32 note)       /* a key or a MIDI note is about to sound */
{
    if ((u32)track >= TRACKS || (u32)note > 127) return;
    if (on_page(seq, PINK) == track) drop(&tumblers[track], note);
    if (on_page(seq, TEAL) == track) latch(seq, track, note);
    if (on_page(seq, RED) == track) keep(seq, track, note);
}

static i32 drum_dial(Euclid *e, i32 dial, i32 delta)        /* a drum ring's STEPS, PULSES, ROTATE: 8 clicks a step */
{
    if (!e->n) return 0;
    Ring *r = &e->ring[e->pick];
    i32 d = 0;
    e->slack[dial] += delta;
    while (e->slack[dial] >= 8) { e->slack[dial] -= 8; d++; }
    while (e->slack[dial] <= -8) { e->slack[dial] += 8; d--; }
    i32 v = (dial == 0 ? r->steps : dial == 1 ? r->pulses : r->rot) + d, lo = dial == 0 ? 2 : dial == 1, hi = dial == 0 ? 16 : dial == 1 ? r->steps : r->steps - 1;
    v = v < lo ? lo : v > hi ? hi : v;
    if (dial == 0) r->steps = (u8)v; else if (dial == 1) r->pulses = (u8)v; else r->rot = (u8)v;
    if (r->pulses > r->steps) r->pulses = r->steps;
    if (r->rot >= r->steps) r->rot = (u8)(r->steps - 1);
    return 1;
}

i32 pages_knob(i32 track, i32 dial, i32 delta)      /* 1: it was ours */
{
    u8 *seq = os_seq();
    i32 page = our_page(seq);
    if (page < 0 || (u32)track >= TRACKS || track != word(seq, SEQ_TRACK) || (u32)dial > 3) return 0;
    Euclid *e = &euclids[track];
    i32 k = page ? (e->more ? GATE : STEPS) + dial : dial, held = word(seq, SEQ_HELD_STEP);
    if (held != 31) {               /* the step, let go, is not switched: as TE's dials have it */
        *(i32 *)(seq + SEQ_STEPS + 0xc) = 0;
        seq[SEQ_STEPS + 0x15] = 0;
    }
    if (page == 2) {
        u8 *g = &gknob[track][(grooves[track].more ? PROG : GROOVE) + dial];
        i32 v = *g + delta;
        *g = (u8)(v < 0 ? 0 : v > 255 ? 255 : v);
        return 1;
    }
    if (track < 4 && k >= STEPS && k <= ROTATE) { drum_dial(e, dial, delta); return 1; }
    if ((seq[SEQ_REC] | seq[SEQ_REC_HELD]) && word(seq, SEQ_ERASING)) {     /* REC with -: what was recorded goes */
        u32 p = (u32)word(seq, SEQ_PATTERN);
        if (p < PATTERNS) locked[p][track] &= (unsigned short)~(1 << k);
        hands &= ~(1 << k);
        now[track][k] = knob[track][k];
        return 1;
    }
    i32 v = now[track][k], step = -1;
    if ((u32)held < 16) {
        u8 *row = lock_row(seq, track, k);
        step = held;
        v = row && row[held] != 255 ? row[held] : knob[track][k];
    } else if (recording(seq, track)) {
        step = step_of(seq, track);
        if (hands >> k & 1 && hand_track == track) v = hand[k];
    } else v = knob[track][k];
    v += delta;
    v = v < 0 ? 0 : v > 255 ? 255 : v;
    if (step < 0) knob[track][k] = (u8)v;
    else set_lock(seq, track, k, step, v);
    if (step >= 0 && held == 31) {
        if (hand_track != track) hands = 0;
        hands |= 1 << k; hand_track = track; hand[k] = (u8)v; hand_ms[k] = os_ms();
    }
    if (held == 31) now[track][k] = (u8)v;
    return 1;
}

static void paint(i32 led, const u8 *c, i32 v, i32 w)
{
    v += 1;
    os_led(led, c[0] * v >> 8, c[1] * v >> 8, c[2] * v >> 8, w);
}

static i32 shown(const u8 *seq, i32 track, i32 k)   /* a dial's value as its LED has it */
{
    i32 held = word(seq, SEQ_HELD_STEP);
    if ((u32)held < 16) {
        u8 *row = lock_row(seq, track, k);
        return row && row[held] != 255 ? row[held] : knob[track][k];
    }
    return now[track][k];
}

i32 pages_dials(void)               /* the dial LEDs: 1 = drawn */
{
    const u8 *seq = os_seq();
    i32 page = our_page(seq);
    if (page < 0) return 0;
    i32 t = word(seq, SEQ_TRACK), flash = -1;
    Euclid *e = &euclids[t];
    if (flashes) {                  /* MORE: twice, back: once; lit 150 ms, dark 150 */
        u32 at = os_ms() - flash_ms;
        flash = at < 150 ? 1 : at < 300 ? 0 : at < 450 && flashes == 2 ? 1 : at < 600 && flashes == 2 ? 0 : -1;
        if (flash < 0) flashes = 0;
    }
    for (i32 d = 0; d < 4; d++) {
        i32 k = page ? (e->more ? GATE : STEPS) + d : d, v = page == 2 ? gknob[t][(grooves[t].more ? PROG : GROOVE) + d] : shown(seq, t, k);
        if (page != 2 && t < 4 && k >= STEPS && k <= ROTATE) {
            const Ring *r = &e->ring[e->pick];
            v = !e->n ? 0 : k == STEPS ? (r->steps - 2) * 18 : (i32)divide((u32)(k == PULSES ? r->pulses - 1 : r->rot) * 255, (u32)r->steps - 1);
        }
        v = (v + 1) * 247 / 256 + 8;
        if (page && flash == 0) os_led(40 + d, 0, 0, 0, 0);
        else paint(40 + d, colour[page], page && flash > 0 ? 255 : v > 255 ? 255 : v, 0);
    }
    return 1;
}

i32 pages_fade(i32 led, i32 amount)         /* the dial LEDs' flash when SHIFT turns the page: ours are in our colours */
{
    i32 page = our_page(os_seq());
    if (page < 0) return 0;
    const u8 *c = colour[page];
    u8 *r = os_led_record(led);
    i32 keep = 255 - (amount & 255), a = amount & 255;
    for (i32 i = 0; i < 3; i++) r[i] = (u8)((r[i] * keep + c[i] * a) >> 8);
    r[3] = (u8)(r[3] * keep >> 8);
    return 1;
}

void pages_paint(void)              /* after the screen drew, on the normal step screen: the balls, or the ring, on the step row */
{
    u8 *seq = os_seq();
    i32 page = our_page(seq);
    if (page < 0 || word(seq, SEQ_SCREEN) != (i32)(__SIZE_TYPE__)(seq + SEQ_STEPS)) return;
    i32 t = word(seq, SEQ_TRACK);
    if (!page) {
        if (!tumblers[t].n) return;
        for (i32 i = 0; i < 16; i++) if (glow[i] >= 24) paint(i, colour[0], glow[i], spark[i]);
        return;
    }
    if (page == 2) {
        const Groove *g = &grooves[t];
        const u8 *how = gknob[t];
        i32 which = groove_of(how), here = g->n && !waiting && beat != 0xffffffff ? (i32)(divide(beat, (u32)groove_ticks(how)) & 15) : -1;
        for (i32 i = 0; i < 16; i++) {
            u32 bit = 1u << i;
            i32 v = groove[which].accent & bit ? 255 : groove[which].ghost & bit ? 50 : groove[which].hit & bit ? 130 : 8;
            paint(i, colour[2], g->n ? v : v >> 1, i != here ? 0 : groove[which].hit & bit ? 255 : 70);
        }
        return;
    }
    const Euclid *e = &euclids[t];
    const u8 *set = now[t];
    const Ring *r = &e->ring[e->pick];
    if (t < 4 && !e->n) return;
    i32 n = t < 4 ? r->steps : e_steps(set[STEPS]), k = t < 4 ? r->pulses : e_pulses(set[PULSES], n), rot = t < 4 ? r->rot : e_rot(set[ROTATE], n);
    i32 at = e->n && !waiting ? (i32)modulo(divide(beat == 0xffffffff ? 0 : beat, (u32)step_ticks(t)), (u32)n) : -1;
    for (i32 i = 0; i < 16; i++) {
        if (i >= n) { os_led(i, 0, 0, 0, 0); continue; }
        i32 p = is_pulse(i, n, k, rot);
        /* the step that is playing is white, with some teal so that the A/B bars leave it alone */
        paint(i, colour[1], p ? e->n ? 170 : 90 : 14, i != at ? 0 : p ? 255 : 70);
    }
}

i32 pages_stop(void)                /* STOP pressed. 1: it emptied this page, and that was all */
{
    u8 *seq = os_seq();
    i32 page = our_page(seq);
    if (!seq) return 0;
    if (page >= 0) {
        if (page == 2) {
            Groove *g = &grooves[word(seq, SEQ_TRACK)];
            if (g->n) { g->n = 0; return 1; }
        }
        i32 *n = page == 1 ? &euclids[word(seq, SEQ_TRACK)].n : page == 0 ? &tumblers[word(seq, SEQ_TRACK)].n : &(i32){ 0 };
        if (*n) { *n = 0; euclids[word(seq, SEQ_TRACK)].pick = 0; return 1; }
    }
    if (!seq[SEQ_PLAYING]) for (i32 k = 0; k < TRACKS; k++) { tumblers[k].n = euclids[k].n = 0; grooves[k].n = 0; }
    return 0;
}

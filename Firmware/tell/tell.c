/* Galax-z tell: the OP-Z tells the Galax-z app what its pink and teal pages (pages/) are doing, so that the app can show the balls
 * and the rings as they are.
 *
 * Only while an app is connected that said it is Galax-z's (the session's client id is 0x4242, op-free's and ours; TE's app never
 * gets these), in two messages of our own beside the OS's:
 *
 *  $70, when it changed (at most 12 times a second) and every second:
 *     0 version 1 | 1 the parameter page (0-5) | 2 the track | 3 tracks with balls, a bit each | 4 tracks with EUCLID notes
 *     5 bit 0 MORE, bit 1 waiting for the first step | 6 the ring the dials turn | 7 how many rings or notes
 *     8-19 the track's twelve dials as they are now | 20 ... a ring: key, steps, pulses, rotation
 *  $71, 17 times a second while the track has balls, at each step (25 a second at most) while only its EUCLID runs:
 *     0 the track | 1 balls | 2-3 the hexagon's turn (65536 = once round) | 4-7 EUCLID's steps since the start | a ball, 6 each:
 *     x, y (128 = 1.0) | vx, vy (16 = 1.0) | note | flash
 *  $72, while the red page is on or the track's groove has notes, when it changed (at most 13 times a second), at each of its steps (25 a
 *     second at most) and every second:
 *     0 the track | 1 notes kept | 2 bit 0 MORE, bit 1 waiting | 3 the step of the groove now, 255: none | 4-11 its eight dials | 12 ... the notes
 *
 * tell() runs in the UI/sequencer task, where the OS looks after its app session (every 20 ms): the task the pages run in, so what
 * it reads does not change meanwhile. It only reads. Compiled by tools/tell_build.py, which fills in where the pages' state is. */

typedef signed int i32;
typedef unsigned int u32;
typedef unsigned char u8;
typedef unsigned short u16;

typedef struct { i32 x, y, vx, vy; u8 note, flash, rest, pad; } Ball;           /* as in pages/pages.c */
typedef struct { Ball ball[8]; i32 n; u32 rot; } Tumbler;
typedef struct { u8 key, steps, pulses, rot; } Ring;
typedef struct { i32 n; Ring ring[8]; i32 next, pulses; u8 pick, more, turned[2]; i32 slack[3]; } Euclid;
typedef struct { u8 n, key[8], next, more; } Groove;

#include "where.h"                  /* TUMBLERS EUCLIDS NOW BEAT WAITING: addresses in the pages' block (tools/tell_build.py) */
#define tumblers ((const Tumbler *)TUMBLERS)
#define euclids ((const Euclid *)EUCLIDS)
#define dials ((const u8 (*)[12])NOW)
#define grooves ((const Groove *)GROOVES)
#define red ((const u8 (*)[8])GKNOB)
#define RED 6

#define STATE __attribute__((section(".data")))
#define CLIENT 0x3c                 /* the session's client id, -1: none */
#define FROM 0x34                   /* where its messages go, two words */
#define GALAXZ 0x4242
#define SEQ_TRACK 0x30
#define SEQ_PAGE 0x345e2c
#define TRACKS 8

static inline i32 word(const u8 *p, u32 at) { return *(const i32 *)(p + at); }
static inline u8 *os_seq(void) { return *(u8 *volatile *)0x81059d1c; }
static inline u32 os_ms(void) { return ((u32(*)(void))0x80028294)(); }
static inline void os_send(const u8 *replica, i32 id, const u8 *bytes, i32 n)      /* as the OS sends $12: 0x80113e30 */
{
    ((void (*)(u32, const u8 *, i32, i32, i32, i32))0x80041eac)(*(volatile u32 *)0x81018320, bytes, n, id, word(replica, FROM), word(replica, FROM + 4));
}

#define MOST 56
static u8 STATE last[MOST] = { 0 };
static i32 STATE last_n = 0;
static u32 STATE told_ms = 0, STATE ball_ms = 0, STATE last_at = 0;
static u8 STATE had = 0;

static u32 divide(u32 n, u32 d)     /* without libgcc */
{
    u32 q = 0, r = 0;
    for (i32 i = 31; i >= 0; i--) {
        r = r << 1 | (n >> i & 1);
        q <<= 1;
        if (r >= d) { r -= d; q |= 1; }
    }
    return q;
}

static u8 part(i32 v, i32 by) { v >>= by; return (u8)(v > 127 ? 127 : v < -127 ? -127 : v); }

static const u8 DIV[7] = { 96, 64, 48, 32, 24, 16, 12 };
static u8 STATE red_last[20] = { 0 };
static i32 STATE red_n = 0;
static u32 STATE red_ms = 0;

static void tell_red(const u8 *replica, u32 track, u32 page, u32 ms)
{
    const Groove *g = &grooves[track];
    i32 k = g->n > 8 ? 0 : g->n;
    if (page != RED && !k) { red_n = 0; return; }
    u32 at = *(volatile u32 *)BEAT, waits = *(volatile u8 *)WAITING;
    u8 b[20];
    b[0] = (u8)track; b[1] = (u8)k; b[2] = (u8)((g->more != 0) | (waits != 0) << 1);
    b[3] = k && !waits && at != 0xffffffff ? (u8)(divide(at, DIV[red[track][1] * 1796 >> 16]) & 15) : 255;
    for (i32 i = 0; i < 8; i++) b[4 + i] = red[track][i];
    for (i32 i = 0; i < k; i++) b[12 + i] = g->key[i];
    i32 n = 12 + k, same = n == red_n, step = red_n && red_last[3] != b[3];
    for (i32 i = 0; same && i < n; i++) same = red_last[i] == b[i];
    u32 since = ms - red_ms;
    if (red_n && since < 1000 && (same || since < (step ? 35u : 75u))) return;
    for (i32 i = 0; i < n; i++) red_last[i] = b[i];
    red_n = n;
    red_ms = ms;
    os_send(replica, 0x72, b, n);
}

void tell(const u8 *replica)
{
    const u8 *seq = os_seq();
    if (!seq || !replica) return;
    if (word(replica, CLIENT) != GALAXZ) { last_n = red_n = 0; return; }
    u32 track = (u32)word(seq, SEQ_TRACK), ms = os_ms();
    u8 b[MOST];
    i32 n = 0;
    b[0] = 1;
    b[1] = (u8)word(seq, SEQ_PAGE);
    b[2] = (u8)track;
    b[3] = b[4] = b[5] = b[6] = b[7] = 0;
    for (i32 t = 0; t < TRACKS; t++) {
        b[3] |= (u8)((tumblers[t].n > 0) << t);
        b[4] |= (u8)((euclids[t].n > 0) << t);
    }
    i32 ours = track < TRACKS;
    const Euclid *e = &euclids[ours ? track : 0];
    i32 rings = ours ? e->n : 0;
    if (rings < 0 || rings > 8) rings = 0;
    for (i32 i = 0; i < 12; i++) b[8 + i] = ours ? dials[track][i] : 0;
    n = 20;
    if (ours) {
        b[5] = (u8)((e->more != 0) | (*(volatile u8 *)WAITING != 0) << 1);
        b[6] = e->pick;
        b[7] = (u8)rings;
        for (i32 i = 0; i < rings; i++) {
            b[n++] = e->ring[i].key; b[n++] = e->ring[i].steps; b[n++] = e->ring[i].pulses; b[n++] = e->ring[i].rot;
        }
    }
    i32 same = n == last_n;
    for (i32 i = 0; same && i < n; i++) same = b[i] == last[i];
    u32 since = ms - told_ms;
    if (last_n == 0 || since >= 1000 || (!same && since >= 75)) {
        for (i32 i = 0; i < n; i++) last[i] = b[i];
        last_n = n;
        told_ms = ms;
        os_send(replica, 0x70, b, n);
    }

    if (!ours) return;
    tell_red(replica, track, b[1], ms);
    const Tumbler *t = &tumblers[track];
    i32 balls = t->n < 0 || t->n > 8 ? 0 : t->n;
    if (ms - ball_ms < (balls ? 55 : 35)) return;          /* 17 a second with balls: at most 1 KB a second, for Bluetooth */
    u32 beat = *(volatile u32 *)BEAT, at = beat == 0xffffffff ? 0 : divide(beat, DIV[dials[track][7] * 1796 >> 16]);
    if (!rings) at = 0;
    if (!balls && !had && at == last_at) return;        /* once more when the last ball has gone */
    ball_ms = ms;
    had = balls != 0;
    last_at = at;
    b[0] = (u8)track;
    b[1] = (u8)balls;
    b[2] = (u8)(t->rot >> 16); b[3] = (u8)(t->rot >> 24);
    b[4] = (u8)at; b[5] = (u8)(at >> 8); b[6] = (u8)(at >> 16); b[7] = (u8)(at >> 24);
    n = 8;
    for (i32 i = 0; i < balls; i++) {
        const Ball *k = &t->ball[i];
        b[n++] = part(k->x, 17); b[n++] = part(k->y, 17);               /* 2^24 / 2^17 = 128 */
        b[n++] = part(k->vx, 20); b[n++] = part(k->vy, 20);            /* 16; no ball is faster than 5 */
        b[n++] = k->note; b[n++] = k->flash;
    }
    os_send(replica, 0x71, b, n);
}

/* Galax-z chime: two Quindar tones when the OP-Z is switched on (Mission Control's: 2525 Hz, then 2475 Hz, a quarter second each), to
 * say that Galax-z is on it. They are in place of TE's start sound: chime_start() is called where the OS would play that, which it does
 * not if general.json has disable_start_sound; then there is no chime either.
 *
 * chime_block() runs in the audio interrupt, once a block of 64 frames, as the OS hands its mix on: before the OS's own volume and before
 * USB, so a tone is as loud as a sound of that level is at that volume. The mix is interleaved stereo, 32 bits. When the tones are over it
 * is a load, a compare and a return. */

typedef signed int i32;
typedef unsigned int u32;

#ifdef CHIME_TEST
typedef long long i64;
static i32 mul(i32 a, i32 b) { return (i32)(((i64)a * b) >> 31); }
#define STATE
#else
static inline i32 mul(i32 a, i32 b) { return __builtin_bfin_mult_fr1x32x32(a, b); }
#define STATE __attribute__((section(".data")))
#endif

#define FRAMES 64
#define RATE 44100
#define LEVEL (1 << 27)                     /* 1/16 of full: -24 dB */
#define QUIET (RATE / 4)                     /* before the first */
#define TONE (RATE / 4)
#define GAP (RATE * 12 / 100)
#define EDGE 512                            /* a tone comes and goes over 11.6 ms: no click */
#define STEP(hz) ((u32)((hz) * 4294967296.0 / RATE))

/* a quarter sine, Q15, 65 entries */
static const short sine[65] = {
    0, 804, 1608, 2410, 3212, 4011, 4808, 5602, 6393, 7179, 7962, 8739, 9512, 10278, 11039, 11793, 12539, 13279, 14010,
    14732, 15446, 16151, 16846, 17530, 18204, 18868, 19519, 20159, 20787, 21403, 22005, 22594, 23170, 23731, 24279, 24811,
    25329, 25832, 26319, 26790, 27245, 27683, 28105, 28510, 28898, 29268, 29621, 29956, 30273, 30571, 30852, 31113, 31356,
    31580, 31785, 31971, 32137, 32285, 32412, 32521, 32609, 32678, 32728, 32757, 32767 };

static i32 sin31(u32 turn)
{
    u32 q = turn >> 30, f = turn & 0x3fffffff;
    if (q & 1) f = 0x40000000 - f;
    u32 i = f >> 24;
    i32 a = sine[i], b = i < 64 ? sine[i + 1] : a;
    i32 v = (a << 16) + (b - a) * (i32)((f >> 8) & 0xffff);
    return q & 2 ? -v : v;
}

#define OVER (QUIET + TONE + GAP + TONE)

u32 STATE chime_at = OVER;                  /* frames since it was started, till it is over */
static u32 STATE phase = 0;

static i32 add(i32 a, i32 b)                /* a sum that does not go round */
{
    i32 s = (i32)((u32)a + (u32)b);
    if (((a ^ s) & (b ^ s)) < 0) s = a < 0 ? (i32)0x80000000 : 0x7fffffff;
    return s;
}

void chime_block(i32 *mix)
{
    u32 at = chime_at;
    if (at >= OVER || !mix) return;
    chime_at = at + FRAMES;
    if (at + FRAMES <= QUIET) return;
    for (u32 k = 0; k < FRAMES; k++, at++) {
        if (at < QUIET) continue;
        u32 in = at - QUIET, second = in >= TONE + GAP;
        if (second) in -= TONE + GAP;
        if (in >= TONE) { phase = 0; continue; }
        i32 edge = (i32)(in < EDGE ? in : TONE - 1 - in < EDGE ? TONE - 1 - in : EDGE);
        i32 v = mul(sin31(phase), LEVEL / EDGE * edge);
        phase += second ? STEP(2475.0) : STEP(2525.0);
        mix[k * 2] = add(mix[k * 2], v);
        mix[k * 2 + 1] = add(mix[k * 2 + 1], v);
    }
}

void chime_start(void)                      /* in place of TE's start sound, before the audio is started */
{
    phase = 0;
    chime_at = 0;
}

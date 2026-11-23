// SPDX-License-Identifier: MIT
// Derived in part from OP-FREE: the engine's frame is the SDK's, as in engines/glue; the compressor is not
// Copyright (c) 2026 Lourens Smit and the op-z-engines contributors (OP-FREE)
// Copyright (c) 2026 Luis Tosado (this version of it)

/*
 * ott — three-band upward and downward compressor for FX1/FX2 ("over the top").
 *
 *   P1        depth     0 = the sound as it came (but for the crossovers' phase and the limiter above -3 dBFS) .. 255 = all of it. Every gain
 *                       below is scaled by it in dB.
 *   P2        time      attack and release times, x 1/4 (left: pumping, gritty) .. x 1 (centre) .. x 4 (right: smooth)
 *   pan       dry/wet   0 dry .. 128 wet, then wet (not reachable on the OP-Z; as glue)
 *   level     output level
 *
 * Bands: Linkwitz-Riley, 12 dB/oct, at 150 Hz and 2.5 kHz: a band's skirt is in phase with its neighbour everywhere, so a skirt
 * brought up never cancels it (with bands that merely add up to the input it did, by 12 dB); the sum is an all-pass. Per band, stereo-linked: peak of the next 16
 * frames -> attack / release on its log -> above the upper line everything is brought down to it, below the lower line it is
 * brought up by 3/4 of what it misses -> make-up, so that a band peaking at -15 dBFS keeps its level -> a limiter that knows the
 * coming 16 frames (band at most -7 dBFS). What is quieter than -63 dBFS is lifted less and less, from -81 dBFS not at all:
 * silence stays silent. Then the sum is limited softly below 0 dBFS. Notes on its track do nothing.
 *
 * No buffer, integers only, no division in the audio. MIT licence.
 */
#include "opz_engine.h"
#include "opz_dsp.h"

#define CTRL    16                              /* frames a gain step */
#define DB(x)   ((int32_t)((x) * 10885.0))      /* dB -> log2, Q16 (65536 / 6.0206) */
#define BOOST   DB(27)                          /* the most a band is raised */
#define CEIL    DB(-7)
#define GATE0   DB(-63)
#define GATE1   DB(-81)
#define HELD    DB(-15)                         /* a band at this level keeps it */
#define FALL    900                             /* the limiter lets go: log2 Q16 a step: 6 dB in 26 ms */

typedef struct Band { int32_t up, down, att, rel; } Band;    /* lower line, upper line (log2 Q16); times (log2 of steps, Q16) */
static const Band BANDS[3] = {
    { DB(-36), DB(-28), 444200, 628700 },       /* log2(40 ms / 0.3628 ms) x 65536 = 6.78; 280 ms = 9.59 */
    { DB(-36), DB(-26), 378700, 617200 },       /* 20 ms = 5.78; 250 ms = 9.43 */
    { DB(-36), DB(-29), 330300, 555300 },       /* 12 ms = 5.05; 130 ms = 8.49 */
};

typedef struct State {
    OpzSvf   lo[2], hi[2];
    OpzSvfCoef cl, ch;
    int32_t  env[3], fast[3];                   /* log2 Q16 */
    int32_t  g[3];                              /* Q26 */
    int32_t  att[3], rel[3];                    /* one-pole per step, Q31 */
    uint32_t w2;
    int32_t  wet_og, dry_og;
    uint8_t  started;
} State;
_Static_assert(sizeof(State) <= OPZ_FX_STATE_BYTES, "FX state must fit in 200 bytes");

uint32_t initModule(uint32_t version, const ModuleCallbackInterface *cb, uint32_t *memRequest)
{
    (void)version; (void)cb;
    *memRequest = 0;
    return 1;
}

void init(void *state, uint32_t track, uint32_t arg2, void *mem, void *scratch)
{
    (void)track; (void)arg2; (void)mem; (void)scratch;
    volatile uint8_t *p = (volatile uint8_t *)state;
    for (unsigned i = 0; i < sizeof(State); i++) p[i] = 0;
}

void onNoteOn(int note, uint8_t velocity, void *state, const uint32_t *params) { (void)note; (void)velocity; (void)state; (void)params; }
void onNoteOff(int note, void *state) { (void)note; (void)state; }

/* log2(x / 2^31), Q16; as glue's */
static inline int32_t log2_q16(int32_t x)
{
    if (x <= 0) return -(31 << 16);
    int e = opz_norm32(x);
    int32_t f = ((x << e) - 0x40000000) >> 14;
    return f + (opz_mul_q31(f * (65536 - f), 736801640) >> 16) - ((e + 1) << 16);
}

/* 1 - e^-(1 / tau), Q31, tau = 2^(l / 65536) steps >= 2 */
static int32_t coef(int32_t l)
{
    if (l < 65536) l = 65536;
    int32_t x = opz_exp2_q16((15 << 16) - l);
    int32_t x2 = opz_mul_q31(x, x);
    return x - (x2 >> 1) + opz_mul_q31(opz_mul_q31(x2, x), 0x15555555);
}

static void __attribute__((noinline)) times(State *s, uint32_t w2)
{
    s->w2 = w2;
    int32_t by = (opz_p16(w2) - 32768) * 4;     /* -2 .. 2 octaves, Q16 */
    for (int b = 0; b < 3; b++) {
        s->att[b] = coef(BANDS[b].att + by);
        s->rel[b] = coef(BANDS[b].rel + by);
    }
}

/* One band's gain, log2 Q16, from the peak of the coming frames */
static inline int32_t gain_of(State *s, int b, int32_t peak, int32_t depth)
{
    int32_t l = log2_q16(peak), e = s->env[b];
    e += opz_mul_q31(l > e ? s->att[b] : s->rel[b], l - e);
    s->env[b] = e;
    int32_t f = s->fast[b] - FALL;
    if (l > f) f = l;
    if (f < -(31 << 16)) f = -(31 << 16);
    s->fast[b] = f;

    const Band *k = &BANDS[b];
    int32_t g = HELD - k->down;                                     /* make-up */
    if (e > k->down) g -= e - k->down;
    else if (e < k->up) g += ((k->up - e) >> 2) * 3;
    if (g > BOOST) g = BOOST;
    if (e < GATE0 && g > 0) g = e <= GATE1 ? 0 : opz_mul_q31(g, (e - GATE1) * (0x7fffffff / (GATE0 - GATE1)));
    g = opz_mul_q31(g, depth);
    int32_t c = CEIL - f;                                           /* not above the ceiling, but never pushed down by it */
    if (c < 0) c = 0;
    return g > c ? c : g;
}

void renderFX(const uint32_t *params, fract32 pitchBend, void *state, const fract32 *in, fract32 *out, fract32 gain)
{
    (void)pitchBend;
    State *s = state;
    fract32 wet = opz_fx_wet_linear(params[OPZ_P_PAN]);
    int32_t og = opz_mul_q31(opz_pq31(params[OPZ_P_LEVEL]), gain);
    int32_t wet_og = opz_mul_q31(wet, og), dry_og = opz_mul_q31(OPZ_Q31_ONE - wet, og);
    if (!s->started) {
        s->cl = opz_svf_coef(150 << 16, 0x7fffffff);                /* k = 2: two equal real poles */
        s->ch = opz_svf_coef(2500 << 16, 0x7fffffff);
        for (int b = 0; b < 3; b++) { s->env[b] = s->fast[b] = -(31 << 16); s->g[b] = 1 << 26; }
        s->wet_og = wet_og; s->dry_og = dry_og;
        times(s, params[OPZ_P_P2]);
        s->started = 1;
    }
    if (params[OPZ_P_P2] != s->w2) times(s, params[OPZ_P_P2]);
    int32_t depth = opz_pq31(params[OPZ_P_P1]);
    int32_t w_og = s->wet_og, d_og = s->dry_og, dw = (wet_og - w_og) >> 6, dd = (dry_og - d_og) >> 6;
    int dry = (dry_og | d_og) != 0;

    for (int sub = 0; sub < OPZ_BLOCK_FRAMES; sub += CTRL) {
        const fract32 *x = in + 2 * sub;
        fract32 *y = out + 2 * sub;
        fract32 lo[2 * CTRL], hi[2 * CTRL], mid[2 * CTRL];
        int32_t pl = 0, pm = 0, ph = 0;
        for (int c = 0; c < 2; c++)
            for (int i = c; i < 2 * CTRL; i += 2) {
                fract32 l, m, h;
                opz_svf(&s->lo[c], &s->cl, x[i] >> 1, &l, 0, &h);   /* half scale: headroom */
                opz_svf(&s->hi[c], &s->ch, -h, &m, 0, &h);
                h = -h;
                lo[i] = l; hi[i] = h; mid[i] = m;
                l = opz_abs32(l); m = opz_abs32(m); h = opz_abs32(h);
                if (l > pl) pl = l;
                if (m > pm) pm = m;
                if (h > ph) ph = h;
            }
        pl = opz_shl_q31(pl, 1); pm = opz_shl_q31(pm, 1); ph = opz_shl_q31(ph, 1);
        int32_t t0 = opz_exp2_q16(gain_of(s, 0, pl, depth) + (10 << 16));      /* Q26 */
        int32_t t1 = opz_exp2_q16(gain_of(s, 1, pm, depth) + (10 << 16));
        int32_t t2 = opz_exp2_q16(gain_of(s, 2, ph, depth) + (10 << 16));
        int32_t g0 = s->g[0], g1 = s->g[1], g2 = s->g[2];
        int32_t d0 = (t0 - g0) >> 4, d1 = (t1 - g1) >> 4, d2 = (t2 - g2) >> 4;
        for (int i = 0; i < 2 * CTRL; i += 2) {
            g0 += d0; g1 += d1; g2 += d2;
            w_og += dw; d_og += dd;
            for (int c = 0; c < 2; c++) {
                int32_t v = opz_mul_q31(lo[i + c], g0) + opz_mul_q31(mid[i + c], g1) + opz_mul_q31(hi[i + c], g2);   /* half scale, Q26 */
                v = opz_limit_half(opz_shl_q31(v, 5));
                v = opz_mul_q31_q15(v, w_og >> 16);
                if (dry) v = opz_add_q31(v, opz_mul_q31_q15(x[i + c], d_og >> 16));
                y[i + c] = v;
            }
        }
        s->g[0] = t0; s->g[1] = t1; s->g[2] = t2;
    }
    s->wet_og = wet_og; s->dry_og = dry_og;
}

OPZ_EXPORTS_FX();

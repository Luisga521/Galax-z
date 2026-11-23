// SPDX-License-Identifier: MIT
// Derived in part from OP-FREE: the engine's frame is the SDK's; the player is not
// Copyright (c) 2026 Lourens Smit and the op-z-engines contributors (OP-FREE)
// Copyright (c) 2026 Luis Tosado (this version of it)

/*
 * piano — a sampled grand piano for the OP-Z's synth tracks (Salamander Grand Piano V3, CC BY 3.0).
 *
 * The sound is in the plug's sample pack (samplepacks/opzk_piano.aif): 30 notes of a Yamaha C5, each a full-band mid
 * stream and a half-rate side stream, 4-bit adaptive prediction, the recorded first 0.3-1.9 s and a loop made of the
 * note's own partials; tools/build_pack.py makes it and README.md describes it. The OS loads the pack and locks it for
 * each note; without it, or with a pack that is not ours, the engine stays silent (pack_ok).
 *
 * Per voice and block: decode (32 samples at a time) -> tone filters at the source rate -> 8-tap (mid) and 4-tap (side)
 * interpolation -> mid/side to left/right -> gain. P1 = tone (dark ... natural ... bright), P2 = hammer (soft ...
 * natural ... hard); velocity sets level and tone as the recorded velocity layers do. Integers only.
 */
#include "opz_adsr.h"
#include "opz_dsp.h"
#include "opz_engine.h"
#include "opz_mix.h"

#if defined(__bfin__) && !defined(PIANO_NO_ASM)   /* the hand-written kernels; PIANO_NO_ASM: the C ones, to compare */
#define BF_ASM 1
#else
#define BF_ASM 0
#endif
#define ALWAYS_INLINE static inline __attribute__((always_inline))

#define PACK_MAGIC   0x4F4E4150u
#define PACK_VERSION 2u
#define ZONES        30
#define BL           32                         /* samples per coded block */
#define BB           17                         /* bytes per coded block */
#define PHASE_SHIFT  7                          /* Q16 position -> 512 phases */
#define STEP_MAX     0x40000u                   /* 4 source samples per output sample (legato far up) */

typedef struct Zone {
    uint32_t note, mid, mid_attack, mid_loop, side, side_attack, side_loop; /* byte offsets, lengths in blocks */
    uint32_t k;                                 /* source frames per cycle, Q16: step = pitch * k >> 32 */
    uint32_t decay;                             /* loop gain per mid block, Q31 */
    uint16_t norm, knee;                        /* Q15; the loop gain below which it falls slowly, Q15 */
    uint16_t w1k, slow;                         /* 2 pi x 1 kHz / rate, Q16; loop decay per mid block then, Q24 */
    uint32_t hf;                                /* how much faster the highs fall in the loop, per mid block, Q31 */
    int16_t  mid_hist[4], side_hist[4];         /* decoder history at the loop start, newest first */
    int16_t  mid_pred[8][4], side_pred[8][4];   /* Q12 */
} Zone;

typedef struct Head {
    uint32_t magic, version, total, zones, zone_at, scale_at, fir_mid_at, fir_side_at, check, rest[7];
} Head;

#define MID_TAPS  8
#define SIDE_TAPS 4
#define ROOM      8                             /* source samples one run() may use before the next refill */
#define GAIN_ONE  38000                         /* x amp (Q15) = Q31: 0.58, x 22000 / 32768 = -8 dBFS at velocity 127 */

#define EMPTY     ((uint32_t)(BL + 1) << 16)    /* a buffer position from which a refill is due */

typedef struct Lp { int32_t a, b, c; } Lp;      /* one-pole states, Q31 */

typedef struct Coef { int16_t ca, ga, cb, gb, cc, pad; } Coef __attribute__((aligned(4)));   /* Q15 corners; ga Q15, gb Q13 */

typedef struct State {
    const uint8_t *base;                        /* the pack's data, 0 = silent */
    uint32_t pack;
    uint8_t  ready;                             /* set last in onNoteOn (render can interrupt it) */
    uint8_t  zone, note, pad;
    uint16_t mid_block, side_block;             /* next block to decode */
    uint32_t mid_pos, side_pos;                 /* Q16 into the buffers */
    int32_t  tail;                              /* loop gain, Q31 */
    int32_t  damp;                              /* shelf gain of the highs: tail and dampers, Q31 */
    int32_t  strike;                            /* hammer envelope, Q31 */
    int32_t  gain;                              /* reached at the end of the last block, Q30; < 0 new note */
    int32_t  vtone;                             /* velocity's part of the tone, octaves Q16 */
    int16_t  amp;                               /* velocity x zone level, Q15 */
    int16_t  ca_mid, ca_side;                   /* shelf A's corners */
    int16_t  mid_hist[4] __attribute__((aligned(4)));
    int16_t  side_hist[4] __attribute__((aligned(4)));
    OpzMix   mix;
    Lp       lp_mid, lp_side;
    int16_t  mid[MID_TAPS + ROOM + BL];
    int16_t  side[SIDE_TAPS + ROOM / 2 + BL];
} State;

_Static_assert(sizeof(State) <= OPZ_VOICE_STATE_BYTES, "voice state must fit the OS's 280 bytes");
_Static_assert(sizeof(Zone) == 192 && sizeof(Head) == 64, "pack layout");

static const ModuleCallbackInterface *s_cb;

uint32_t initModule(uint32_t version, const ModuleCallbackInterface *cb, uint32_t *memRequest)
{
    (void)version;
    s_cb = cb;
    *memRequest = 0;
    return 1;
}

void init(void *state, uint32_t track, uint32_t arg2, void *mem, void *scratch)
{
    (void)track; (void)mem; (void)scratch;
    volatile uint8_t *p = (volatile uint8_t *)state;
    for (unsigned i = 0; i < sizeof(State); i++) p[i] = 0;
    ((State *)state)->pack = arg2;
}

/* One-pole coefficient, Q15, for a corner `oct` octaves (Q16) above 1 kHz: 1 - exp(-w), w = w1k x 2^oct. */
static int32_t corner(int32_t oct, uint32_t w1k)
{
    if (oct > 4 * 65536) oct = 4 * 65536;
    if (oct < -4 * 65536) oct = -4 * 65536;
    uint32_t w = opz_mul_u32_shr16((uint32_t)opz_exp2_q16(oct), w1k);       /* Q16 radians per sample */
    if (w > 6u * 65536u) return 32767;
    int32_t c = 32768 - (opz_exp2_q16(-(int32_t)opz_mul_u32_shr16(w, 94548)) >> 1);   /* 2^(-w log2 e) */
    return c > 32767 ? 32767 : c < 1 ? 1 : c;
}

/* Is this our pack, whole and unchanged where it steers the engine? About 1,500 words the first time it is seen at an
 * address; after that its header tells (a chord of ten would spend 100,000 cycles on it). */
static const uint8_t *s_seen;
static uint32_t s_seen_check;

static int pack_ok(const uint8_t *base, uint32_t frames)
{
    if (((uintptr_t)base & 3u) || frames < 4096 || frames > 529200) return 0;
    const Head *h = (const Head *)(const void *)base;
    if (h->magic != PACK_MAGIC || h->version != PACK_VERSION || h->zones != ZONES) return 0;
    if (h->total > frames * 2 || h->zone_at != sizeof(Head) || h->scale_at != sizeof(Head) + ZONES * sizeof(Zone)) return 0;
    if (h->fir_mid_at != h->scale_at + 128 || h->fir_side_at != h->fir_mid_at + 512 * MID_TAPS * 2) return 0;
    if (base == s_seen && h->check == s_seen_check) return 1;
    const uint32_t *w = (const uint32_t *)(const void *)(base + sizeof(Head));
    uint32_t c = 0;
    for (uint32_t i = 0; i < (ZONES * sizeof(Zone) + 128) / 4; i++) c = (c << 5) + c + w[i];
    if (c != h->check) return 0;
    const Zone *z = (const Zone *)(const void *)(base + sizeof(Head));
    for (uint32_t i = 0; i < ZONES; i++, z++) {
        if (z->mid_loop == 0 || z->side_loop == 0 || z->mid >= h->total || z->side >= h->total) return 0;
        if (z->mid + (z->mid_attack + z->mid_loop) * BB > h->total) return 0;
        if (z->side + (z->side_attack + z->side_loop) * BB > h->total) return 0;
    }
    s_seen = base;
    s_seen_check = h->check;
    return 1;
}

void onNoteOn(int note, uint8_t velocity, void *state, const uint32_t *params)
{
    State *s = state;
    s->ready = 0;
    const OpzSampleSlice *sl = s->pack && s_cb->getSample ? s_cb->getSample((int)s->pack, (uint8_t)note) : 0;
    const uint8_t *base = sl ? (const uint8_t *)sl->data : 0;
    s->base = 0;
    if (!base || !pack_ok(base, sl->frames)) return;

    uint32_t n = note < 0 ? 0 : note > 127 ? 127 : (uint32_t)note;
    uint32_t zi = n <= 21 ? 0 : ((n - 20) * 21846u) >> 16;                  /* (n - 20) / 3: 20-22 -> A0, 23-25 -> C1 */
    if (zi >= ZONES) zi = ZONES - 1;
    const Zone *z = (const Zone *)(const void *)(base + sizeof(Head)) + zi;

    uint32_t v = velocity > 127 ? 127 : velocity;
    /* level: (v/127)^1.4 ~ 0.6 v^2 + 0.4 v */
    uint32_t v15 = v * 258u;                                                /* 127 -> 32766 */
    uint32_t a = (39322u * ((v15 * v15) >> 15) + 26214u * v15) >> 16;       /* 32766 at 127 */
    s->amp = (int16_t)((a * z->norm) >> 15);
    /* tone: the source is the layer recorded around velocity 104; below it the cutoff falls as fast as
     * the softer layers do, an octave per 19 steps */
    s->vtone = v < 104 ? -(int32_t)((104 - v) * 3500u) : (int32_t)((v - 104) * 700u);
    if (v < 104) {                                                          /* the low strings lose theirs sooner */
        int32_t by = n <= 48 ? 336 : n <= 72 ? 336 - ((int32_t)n - 48) * 6 : 192;                 /* Q8 */
        s->vtone = (s->vtone >> 8) * by;
    }
    if (s->vtone < -4 * 65536) s->vtone = -4 * 65536;

    s->zone = (uint8_t)zi;
    s->note = (uint8_t)n;
    int32_t oa = ((int32_t)n - 69) * 5461 + 53477;  /* shelf A: four times the note */
    s->ca_mid = (int16_t)corner(oa, z->w1k);
    s->ca_side = (int16_t)corner(oa, z->w1k * 2);
    s->mid_block = s->side_block = 0;
    s->mid_pos = EMPTY + (11u << 16);               /* due for a refill, which leaves the first sample 1 frame ahead */
    s->side_pos = EMPTY + (11u << 15);              /* (a mid position p matches the side position p / 2 + 0.5) */
    s->tail = OPZ_Q31_ONE;
    s->damp = OPZ_Q31_ONE;
    s->strike = OPZ_Q31_ONE;
    s->gain = -1;
    s->lp_mid.a = s->lp_mid.b = s->lp_mid.c = 0;
    s->lp_side.a = s->lp_side.b = s->lp_side.c = 0;
    for (int i = 0; i < 4; i++) s->mid_hist[i] = s->side_hist[i] = 0;
    for (int i = 0; i < MID_TAPS + ROOM + BL; i++) s->mid[i] = 0;
    for (int i = 0; i < SIDE_TAPS + ROOM / 2 + BL; i++) s->side[i] = 0;
    opz_mix_start(&s->mix, params);
    s->base = base;
    s->ready = 1;
}

void onNoteOff(int note, void *state)
{
    (void)note; (void)state;                        /* the host releases the envelope; render sees stage 4 */
}

ALWAYS_INLINE int32_t sat16(int32_t x) { return x > 32767 ? 32767 : x < -32768 ? -32768 : x; }

ALWAYS_INLINE int32_t mul16(int32_t a, int32_t b) { return (int32_t)(int16_t)a * (int16_t)b; }

/* Saturating 16-bit subtract and the fractional multiply-accumulate, as the Blackfin does them: the kernels below are
 * hand-written for it and bit-identical here. */
#if !BF_ASM
ALWAYS_INLINE int32_t sat32(int64_t x) { return x > INT32_MAX ? INT32_MAX : x < INT32_MIN ? INT32_MIN : (int32_t)x; }
ALWAYS_INLINE int32_t f16(int32_t a, int32_t b) { return sat32((int64_t)mul16(a, b) * 2); }     /* R = a.L * b.L, Q31 */
ALWAYS_INLINE int32_t f16t(int32_t a, int32_t b) { return f16(a, b) >> 16; }                    /* ... (T), Q15 */
#endif

/* One coded block -> 32 samples: y = sat16(((c . last four samples) >> 12) + code x scale). */
static void predict(const uint8_t *q, const int16_t *c, int32_t scale, int16_t *hist, int16_t *out)
{
#if BF_ASM
    /* R0: c1:c0, R1: c3:c2, R2: h1:h0, R3: h3:h2, R7: byte; R6: scale; two samples
     * (one byte) per pass, 11 instructions a sample. */
    int32_t n = BL / 2;
    register int32_t r6 __asm__("R6") = scale;
    __asm__ volatile(
        "R0 = [%[c]++];\n\tR1 = [%[c]++];\n\t"
        "R2 = [%[h]];\n\tR3 = [%[h] + 4];\n\t"
        "LSETUP (1f, 2f) LC0 = %[n];\n"
        "1:\tA1 = R0.H * R2.H, A0 = R0.L * R2.L (IS);\n\t"
        "A1 += R1.H * R3.H, A0 += R1.L * R3.L (IS) || R7 = B[%[q]++] (X);\n\t"
        "R4 = (A0 += A1);\n\t"
        "R5 = R7 << 28;\n\t"
        "R4 >>>= 12;\n\t"
        "R5 >>>= 28;\n\t"
        "R3 = PACK (R3.L, R2.H);\n\t"
        "R5 = R5.L * R6.L (IS);\n\t"
        "R4 = R4 + R5;\n\t"
        "R4 = R4 << 16 (S);\n\t"
        "R2 = PACK (R2.L, R4.H) || W[%[o]++] = R4.H;\n\t"
        "A1 = R0.H * R2.H, A0 = R0.L * R2.L (IS);\n\t"
        "A1 += R1.H * R3.H, A0 += R1.L * R3.L (IS);\n\t"
        "R4 = (A0 += A1);\n\t"
        "R7 >>>= 4;\n\t"
        "R4 >>>= 12;\n\t"
        "R3 = PACK (R3.L, R2.H);\n\t"
        "R5 = R7.L * R6.L (IS);\n\t"
        "R4 = R4 + R5;\n\t"
        "R4 = R4 << 16 (S);\n"
        "2:\tR2 = PACK (R2.L, R4.H) || W[%[o]++] = R4.H;\n\t"
        "[%[h]] = R2;\n\t[%[h] + 4] = R3;"
        : [c] "+a"(c), [q] "+a"(q), [o] "+b"(out)
        : [h] "a"(hist), "d"(r6), [n] "a"(n)
        : "R0", "R1", "R2", "R3", "R4", "R5", "R7", "A0", "A1", "LC0", "LT0", "LB0", "memory");
#else
    int32_t h0 = hist[0], h1 = hist[1], h2 = hist[2], h3 = hist[3];
    for (int i = 0; i < BL; i++) {
        int32_t v = (int8_t)q[i >> 1];
        v = i & 1 ? v >> 4 : (int32_t)((uint32_t)v << 28) >> 28;
        int32_t y = sat16(((mul16(c[0], h0) + mul16(c[1], h1) + mul16(c[2], h2) + mul16(c[3], h3)) >> 12) + mul16(v, scale));
        out[i] = (int16_t)y;
        h3 = h2; h2 = h1; h1 = h0; h0 = y;
    }
    hist[0] = (int16_t)h0; hist[1] = (int16_t)h1; hist[2] = (int16_t)h2; hist[3] = (int16_t)h3;
#endif
}

/* The tone filters, in place: shelf A (corner ca, highs x ga), shelf B (corner cb, highs x gb, Q13), low-pass C. */
static void filters(int16_t *x, Lp *lp, const Coef *k)
{
#if BF_ASM
    /* A0/R2: state A, A1/R5: state B, R7: state C; R3: ga:ca, R4: gb:cb, R6: -:cc. 16 instructions a sample. */
    int16_t *o = x;
    __asm__ volatile(
        "R2 = [%[lp]];\n\tR5 = [%[lp] + 4];\n\tR7 = [%[lp] + 8];\n\t"
        "A0 = R2;\n\tA1 = R5;\n\t"
        "R3 = [%[k]];\n\tR4 = [%[k] + 4];\n\tR6 = W[%[k] + 8] (X);\n\t"
        "R0 = W[%[x]++] (X);\n\t"
        "LSETUP (1f, 2f) LC0 = %[n];\n"
        "1:\tR1.L = R0.L - R2.H (S);\n\t"
        "R2 = (A0 += R1.L * R3.L);\n\t"
        "R1.L = R0.L - R2.H (S);\n\t"
        "R1.L = R1.L * R3.H (T);\n\t"
        "R0.L = R2.H + R1.L (S);\n\t"
        "R1.L = R0.L - R5.H (S);\n\t"
        "R5 = (A1 += R1.L * R4.L);\n\t"
        "R1.L = R0.L - R5.H (S);\n\t"
        "R1 = R1.L * R4.H;\n\t"
        "R1 = R1 << 2 (S);\n\t"
        "R0.L = R5.H + R1.H (S);\n\t"
        "R1.L = R0.L - R7.H (S);\n\t"
        "R1 = R1.L * R6.L;\n\t"
        "R7 = R7 + R1 (S) || R0 = W[%[x]++] (X);\n"
        "2:\tW[%[o]++] = R7.H;\n\t"
        "[%[lp]] = R2;\n\t[%[lp] + 4] = R5;\n\t[%[lp] + 8] = R7;"
        : [x] "+a"(x), [o] "+b"(o)
        : [lp] "a"(lp), [k] "a"(k), [n] "a"(BL)
        : "R0", "R1", "R2", "R3", "R4", "R5", "R6", "R7", "A0", "A1", "LC0", "LT0", "LB0", "memory");
#else
    int64_t a = lp->a, b = lp->b;
    int32_t ra = lp->a, rb = lp->b, rc = lp->c;
    for (int i = 0; i < BL; i++) {
        int32_t v = x[i], d;
        a += f16(sat16(v - (ra >> 16)), k->ca);
        ra = sat32(a);
        d = f16t(sat16(v - (ra >> 16)), k->ga);
        v = sat16((ra >> 16) + d);
        b += f16(sat16(v - (rb >> 16)), k->cb);
        rb = sat32(b);
        d = opz_shl_q31(f16(sat16(v - (rb >> 16)), k->gb), 2) >> 16;
        v = sat16((rb >> 16) + d);
        rc = opz_add_q31(rc, f16(sat16(v - (rc >> 16)), k->cc));
        x[i] = (int16_t)(rc >> 16);
    }
    lp->a = ra; lp->b = rb; lp->c = rc;
#endif
}

ALWAYS_INLINE void decode(const uint8_t *q, const int16_t (*pred)[4], const uint16_t *scales, int16_t *hist, Lp *lp,
                          const Coef *k, int16_t *out)
{
    predict(q + 1, pred[q[0] & 7], scales[q[0] >> 3], hist, out);
    filters(out, lp, k);
}

typedef struct Ctx {                                /* what a refill needs, once per render */
    State *s;
    const Zone *z;
    const uint16_t *scales;
    const uint8_t *base;
    Coef mid, side;
} Ctx;

static void __attribute__((noinline)) refill_mid(Ctx *x)
{
    State *s = x->s;
    const Zone *z = x->z;
    for (int i = 0; i < MID_TAPS + ROOM; i++) s->mid[i] = s->mid[BL + i];
    uint32_t b = s->mid_block, at = z->mid_attack;
    if (b >= at + z->mid_loop) {
        b = at;
        for (int i = 0; i < 4; i++) s->mid_hist[i] = z->mid_hist[i];
    }
    if (b >= at) {
        if (s->tail >> 16 >= z->knee) s->tail = opz_mul_q31(s->tail, (fract32)z->decay);
        else s->tail -= opz_mul_q31(s->tail, (fract32)((uint32_t)z->slow << 7));
        s->damp -= opz_mul_q31(s->damp, (fract32)z->hf);
    }
    decode(x->base + z->mid + b * BB, z->mid_pred, x->scales, s->mid_hist, &s->lp_mid, &x->mid, s->mid + MID_TAPS + ROOM);
    s->mid_block = (uint16_t)(b + 1);
}

static void __attribute__((noinline)) refill_side(Ctx *x)
{
    State *s = x->s;
    const Zone *z = x->z;
    for (int i = 0; i < SIDE_TAPS + ROOM / 2; i++) s->side[i] = s->side[BL + i];
    uint32_t b = s->side_block;
    if (b >= z->side_attack + z->side_loop) {
        b = z->side_attack;
        for (int i = 0; i < 4; i++) s->side_hist[i] = z->side_hist[i];
    }
    decode(x->base + z->side + b * BB, z->side_pred, x->scales, s->side_hist, &s->lp_side, &x->side, s->side + SIDE_TAPS + ROOM / 2);
    s->side_block = (uint16_t)(b + 1);
}

/* A knob as -65536 .. 65536 with a dead centre (bytes 124-132, where the OS lights the dial's centre cue). */
static int32_t bipolar(uint32_t param)
{
    int32_t k = (opz_p16(param) - 32768) * 2;
    if (k > 2600) return k - 2600 + ((k - 2600) >> 4);
    if (k < -2600) return k + 2600 + ((k + 2600) >> 4);
    return 0;
}

/* (a * b) >> 32, unsigned, without libgcc */
static uint32_t umulh(uint32_t a, uint32_t b)
{
    uint32_t al = a & 0xffff, ah = a >> 16, bl = b & 0xffff, bh = b >> 16;
    uint32_t m1 = opz_mul_u16(ah, bl), m2 = opz_mul_u16(al, bh);
    uint32_t mid = (opz_mul_u16(al, bl) >> 16) + (m1 & 0xffff) + (m2 & 0xffff);
    return opz_mul_u16(ah, bh) + (m1 >> 16) + (m2 >> 16) + (mid >> 16);
}

static void tone(const State *s, const Zone *z, const uint32_t *params, int32_t hammer, Coef *mid, Coef *side)
{
    /* octaves of brightness, 0 = the recording */
    int32_t k = bipolar(params[OPZ_P_P1]);
    int32_t b = s->vtone + (k < 0 ? k * 3 + (k >> 1) : k - (k >> 4));
    int32_t st = mul16(hammer >> 2, s->strike >> 16) >> 13;             /* hammer x strike, Q16 octaves */
    b += st > 0 ? st >> 1 : st;
    if (b > 65536) b = 65536;
    if (b < -4 * 65536) b = -4 * 65536;

    int32_t ob, oc;
    if (b >= 0) {
        mid->gb = (int16_t)(8192 + (b >> 4) * 5);                       /* shelf at 1.5 kHz, up to x 3.5 */
        ob = 38336;
        oc = 4 * 65536;
    } else {
        mid->gb = 0;                                                    /* two one-poles from 10.4 kHz down, the same for every note */
        ob = oc = 221500 + b;
    }
    mid->ga = side->ga = (int16_t)(s->damp >> 16);
    side->gb = mid->gb;
    mid->ca = s->ca_mid;
    side->ca = s->ca_side;
    mid->cb = (int16_t)corner(ob, z->w1k);
    side->cb = (int16_t)corner(ob, z->w1k * 2);
    mid->cc = (int16_t)(oc >= 4 * 65536 ? 32767 : mid->cb);
    side->cc = (int16_t)(oc >= 4 * 65536 ? 32767 : side->cb);
}

/* n output frames from the two buffers: 8-tap mid, 4-tap side (sums of x h, Q15, truncated), packed as left:right =
 * mid + side : mid - side. The caller sees to it that the buffers hold what n frames need. */
typedef struct Run {
    int32_t *out;                               /* +0 */
    const int16_t *mid, *fir_mid, *side, *fir_side;
    uint32_t mp, sp, inc;                       /* +20 (32-bit pointers) */
    int32_t dinc;
    uint32_t n;                                 /* +36 */
} Run;

static void run(Run *r)
{
#if BF_ASM
    /* M0-M3: buffers and tables, I0-I3 the two FIRs' pointers; R7 mp, R6 sp, R5 inc, R4 dinc, R3 mid, R2 the 9-bit
     * phase field (position 7, length 9). Samples are only 2-byte aligned, so one product a cycle. */
    register Run *p0 __asm__("P0") = r;
    __asm__ volatile(
        "[--SP] = P5;\n\tP5 = [P0];\n\t"
        "R0 = [P0 + 4];\n\tM0 = R0;\n\tR0 = [P0 + 8];\n\tM1 = R0;\n\tR0 = [P0 + 12];\n\tM2 = R0;\n\tR0 = [P0 + 16];\n\tM3 = R0;\n\t"
        "R7 = [P0 + 20];\n\tR6 = [P0 + 24];\n\tR5 = [P0 + 28];\n\tR4 = [P0 + 32];\n\tP1 = [P0 + 36];\n\t"
        "R2 = 0x0709 (X);\n\t"
        "LSETUP (1f, 2f) LC0 = P1;\n"
        "1:\tR0 = R7 >> 16;\n\t"
        "R0 = R0 + R0;\n\t"
        "R1 = EXTRACT (R7, R2.L) (Z);\n\t"
        "R1 <<= 4;\n\t"
        "I0 = R0;\n\tI1 = R1;\n\t"
        "R0 = R6 >> 16;\n\t"
        "R0 = R0 + R0;\n\t"
        "R1 = EXTRACT (R6, R2.L) (Z);\n\t"
        "R1 <<= 3;\n\t"
        "I2 = R0;\n\tI3 = R1;\n\t"
        "I0 += M0;\n\tI1 += M1;\n\tI2 += M2;\n\tI3 += M3;\n\t"
        "R7 = R7 + R5 (NS) || R0.L = W[I0++] || R1.L = W[I1++];\n\t"
        "A0 = R0.L * R1.L || R0.L = W[I0++] || R1.L = W[I1++];\n\t"
        "A0 += R0.L * R1.L || R0.L = W[I0++] || R1.L = W[I1++];\n\t"
        "A0 += R0.L * R1.L || R0.L = W[I0++] || R1.L = W[I1++];\n\t"
        "A0 += R0.L * R1.L || R0.L = W[I0++] || R1.L = W[I1++];\n\t"
        "A0 += R0.L * R1.L || R0.L = W[I0++] || R1.L = W[I1++];\n\t"
        "A0 += R0.L * R1.L || R0.L = W[I0++] || R1.L = W[I1++];\n\t"
        "A0 += R0.L * R1.L || R0.L = W[I0++] || R1.L = W[I1++];\n\t"
        "R3.L = (A0 += R0.L * R1.L) (T) || R0.L = W[I2++] || R1.L = W[I3++];\n\t"
        "A0 = R0.L * R1.L || R0.L = W[I2++] || R1.L = W[I3++];\n\t"
        "A0 += R0.L * R1.L || R0.L = W[I2++] || R1.L = W[I3++];\n\t"
        "A0 += R0.L * R1.L || R0.L = W[I2++] || R1.L = W[I3++];\n\t"
        "R0.L = (A0 += R0.L * R1.L) (T);\n\t"
        "R1 = R5 >> 1;\n\t"
        "R6 = R6 + R1;\n\t"
        "R5 = R5 + R4;\n\t"
        "R1.L = R3.L - R0.L (S);\n\t"
        "R1.H = R3.L + R0.L (S);\n"
        "2:\t[P5++] = R1;\n\t"
        "P5 = [SP++];\n\t"
        "[P0 + 20] = R7;\n\t[P0 + 24] = R6;\n\t[P0 + 28] = R5;"
        : : "a"(p0)
        : "R0", "R1", "R2", "R3", "R4", "R5", "R6", "R7", "P1", "A0", "I0", "I1", "I2", "I3", "M0", "M1", "M2", "M3",
          "LC0", "LT0", "LB0", "memory");
#else
    for (uint32_t i = 0; i < r->n; i++) {
        const int16_t *x = r->mid + (r->mp >> 16), *h = r->fir_mid + (r->mp >> PHASE_SHIFT & 511) * MID_TAPS;
        int64_t a = 0;
        for (int k = 0; k < MID_TAPS; k++) a += (int64_t)mul16(x[k], h[k]) * 2;
        int32_t m = sat16((int32_t)(a >> 16));
        x = r->side + (r->sp >> 16), h = r->fir_side + (r->sp >> PHASE_SHIFT & 511) * SIDE_TAPS;
        a = 0;
        for (int k = 0; k < SIDE_TAPS; k++) a += (int64_t)mul16(x[k], h[k]) * 2;
        int32_t d = sat16((int32_t)(a >> 16));
        r->out[i] = (int32_t)((uint32_t)sat16(m + d) << 16 | (uint16_t)sat16(m - d));
        r->mp += r->inc;
        r->sp += r->inc >> 1;
        r->inc += (uint32_t)r->dinc;
    }
#endif
}

/* Gain, envelope and the packed left:right pairs -> 32-bit left and right.  */
ALWAYS_INLINE int32_t gains(fract32 *o, const int32_t *pair, int32_t level, int32_t coef, int32_t step, int32_t g, int32_t dg,
                            int step0)
{
    for (int i = 0; i < OPZ_BLOCK_FRAMES; i++) {
        int32_t v = opz_mul_q31_q15(level, g >> 16) >> 16;
        int32_t p = pair[i];
#if BF_ASM
        int32_t a, b;
        __asm__("%0 = %2.H * %3.L;" : "=d"(a) : "0"(0), "d"(p), "d"(v));
        __asm__("%0 = %2.L * %3.L;" : "=d"(b) : "0"(0), "d"(p), "d"(v));
#else
        int32_t a = f16(p >> 16, v), b = f16(p, v);
#endif
        o[0] = a;
        o[1] = b;
        o += 2;
        g += dg;
        level = step0 ? opz_env_tick0(level, coef) : opz_env_tick(level, coef, step);
    }
    return level;
}

void render(fract32 *out, uint32_t pitch, int32_t pitchSlope, void *state, const uint32_t *params, ADSR *env)
{
    State *s = state;
    if (OPZ_ADSR_STAGE(env) == 0) return;
    s_cb->updateParametersADSR(env, params[OPZ_P_ATTACK], params[OPZ_P_DECAY], params[OPZ_P_SUSTAIN],
                               params[OPZ_P_RELEASE]);
    int32_t stage = OPZ_ADSR_STAGE(env);
    int32_t level = OPZ_ADSR_LEVEL(env), coef = OPZ_ADSR_COEF(env), step = OPZ_ADSR_STEP(env);
    const uint8_t *base = s->base;
    if (!s->ready || !base || s->tail < 20000) {    /* no pack, a note being set up, or the sound has died away */
        for (int i = 0; i < OPZ_BLOCK_FRAMES; i++) level = opz_env_tick(level, coef, step);
        OPZ_ADSR_LEVEL(env) = level;
        return;
    }

    const Zone *z = (const Zone *)(const void *)(base + sizeof(Head)) + (s->zone < ZONES ? s->zone : 0);
    const Head *h = (const Head *)(const void *)base;
    Ctx x;
    x.s = s;
    x.z = z;
    x.base = base;
    x.scales = (const uint16_t *)(const void *)(base + h->scale_at);
    const int16_t *fm = (const int16_t *)(const void *)(base + h->fir_mid_at);
    const int16_t *fs = (const int16_t *)(const void *)(base + h->fir_side_at);

    if (stage == 4 && s->note < 91) s->damp = opz_mul_q31(s->damp, 0x7a000000);     /* the dampers take the highs first */
    int32_t hammer = bipolar(params[OPZ_P_P2]);
    tone(s, z, params, hammer, &x.mid, &x.side);

    /* source frames per output frame, Q16 */
    uint32_t pitch_end = pitch + (uint32_t)pitchSlope * OPZ_BLOCK_FRAMES;
    uint32_t st0 = umulh(pitch, z->k), st1 = umulh(pitch_end, z->k);
    if (st0 > STEP_MAX) st0 = STEP_MAX;
    if (st1 > STEP_MAX) st1 = STEP_MAX;

    /* the interpolator, in runs short enough for what the buffers keep in hand (ROOM) */
    fract32 buf[OPZ_BLOCK_FRAMES * 2];
    int32_t *pair = buf + OPZ_BLOCK_FRAMES;         /* packed pairs in the upper half: gains() expands them in place */
    uint32_t top = st0 > st1 ? st0 : st1;
    uint32_t chunk = top <= 0x10000u ? 8 : top <= 0x20000u ? 4 : 2;
    Run r;
    r.mid = s->mid;
    r.side = s->side;
    r.fir_mid = fm;
    r.fir_side = fs;
    r.mp = s->mid_pos;
    r.sp = s->side_pos;
    r.inc = st0;
    r.dinc = (int32_t)(st1 - st0) >> 6;
    r.n = chunk;
    for (uint32_t i = 0; i < OPZ_BLOCK_FRAMES; i += chunk) {
        if (r.mp >= EMPTY) { refill_mid(&x); r.mp -= BL << 16; }
        if (r.sp >= EMPTY) { refill_side(&x); r.sp -= BL << 16; }
        r.out = pair + i;
        run(&r);
    }
    s->mid_pos = r.mp;
    s->side_pos = r.sp;

    /* gain: velocity and zone x loop decay x hammer, ramped over the block; GAIN_ONE is the level of the loudest
     * recorded note at velocity 127 (its peak comes out at about -8 dBFS) */
    int32_t swing = hammer < 0 ? hammer - (hammer >> 3) : (hammer >> 1) + (hammer >> 3);    /* x 0.12 .. x 1.62 */
    int32_t f13 = 8192 + (mul16(swing >> 3, s->strike >> 16) >> 15);
    int32_t g1 = opz_shl_q31(opz_mul_q31_q15(opz_mul_q31(s->amp * GAIN_ONE, s->tail), f13), 2);
    int32_t g = s->gain < 0 ? g1 : s->gain;
    int32_t dg = (g1 - g) >> 6;
    s->gain = g1;
    s->strike = opz_mul_q31(s->strike, 0x78c00000);                     /* 25 ms */
    OPZ_ADSR_LEVEL(env) = step ? gains(buf, pair, level, coef, step, g, dg, 0) : gains(buf, pair, level, coef, 0, g, dg, 1);
    opz_mix_stereo(out, buf, &s->mix, params);
}

OPZ_EXPORTS_INSTRUMENT();

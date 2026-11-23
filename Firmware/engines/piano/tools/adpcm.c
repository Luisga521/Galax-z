/* The piano pack's codec, encoder side (built and called by build_pack.py; never on the OP-Z).
 *
 * 32 samples -> 17 bytes: a header (scale index << 3 | predictor) and 32 4-bit codes, low nibble first.
 *   x[n] = sat16(((c0 x[n-1] + ... + c[ORDER-1] x[n-ORDER]) >> 12) + code * scale)
 * with code -8..7, 8 predictors per stream (Q12) and one scale table for the whole pack. The encoder keeps the best
 * BEAM decoder states from block to block, so a block's choice also counts what it does to the next one. */
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#define BL 32
#define BEAM 12
#define SCALES 32
#ifndef ORDER
#define ORDER 4
#endif

static int sat16(int x) { return x > 32767 ? 32767 : x < -32768 ? -32768 : x; }

typedef struct { int h[ORDER]; double e[ORDER]; double cost; int parent; uint8_t code[17]; } Node;

static double run(const double *x, const int16_t *c, int scale, const int *h0, int *h, uint8_t *code, double w, double limit,
                  const double *e0, double *e, double gamma)
{
    double err = 0, f[ORDER], g = 1;
    for (int k = 0; k < ORDER; k++) { g *= gamma; f[k] = c[k] * g / 4096; }
    memcpy(h, h0, sizeof(int) * ORDER);
    memcpy(e, e0, sizeof(double) * ORDER);
    for (int i = 0; i < BL; i++) {
        int pred = 0;
        double fb = 0;                              /* noise shaped like the signal, 1 / A(z / gamma) */
        for (int k = 0; k < ORDER; k++) { pred += c[k] * h[k]; fb += f[k] * e[k]; }
        pred >>= 12;
        double want = (x[i] - fb - pred) / scale;
        int q = (int)(want + (want >= 0 ? 0.5 : -0.5));
        q = q < -8 ? -8 : q > 7 ? 7 : q;
        int y = sat16(pred + q * scale);
        double d = x[i] - y, n = d - fb;
        err += n * n * w;
        if (err > limit) return 1e300;
        if (i & 1) code[i >> 1] |= (q & 15) << 4; else code[i >> 1] = q & 15;
        memmove(h + 1, h, sizeof(int) * (ORDER - 1)); h[0] = y;
        memmove(e + 1, e, sizeof(double) * (ORDER - 1)); e[0] = d;
    }
    return err;
}

/* hist: decoder history before the first block (newest first), in; and after `mark` blocks, out (the loop start).
 * The decoder restores that history when it jumps back, so
 * every pass of the loop decodes to the same samples. */
int encode(const double *x, int blocks, double gamma, const int16_t *pred, const int *scales, int *hist, int mark, int *hmark,
           uint8_t *out, int16_t *recon)
{
    Node *nodes = malloc(sizeof(Node) * (blocks + 1) * BEAM);
    int *count = calloc(blocks + 1, sizeof(int));
    memset(&nodes[0], 0, sizeof(Node));
    memcpy(nodes[0].h, hist, sizeof nodes[0].h);
    count[0] = 1;
    for (int b = 0; b < blocks; b++) {
        Node *cur = nodes + b * BEAM, *nxt = nodes + (b + 1) * BEAM;
        const double *xb = x + b * BL;
        double pw = 1.0;
        for (int i = 0; i < BL; i++) pw += xb[i] * xb[i];
        double w = 1.0 / pw;
        int n = 0;
        for (int k = 0; k < count[b]; k++) {
            for (int p = 0; p < 8; p++) {
                const int16_t *c = pred + p * ORDER;
                double hx[ORDER], mx = 0;
                for (int j = 0; j < ORDER; j++) hx[j] = cur[k].h[j];
                for (int i = 0; i < BL; i++) {      /* open-loop residual peak */
                    double pr = 0;
                    for (int j = 0; j < ORDER; j++) pr += c[j] * hx[j] / 4096.0;
                    double r = xb[i] - pr; if (r < 0) r = -r; if (r > mx) mx = r;
                    memmove(hx + 1, hx, sizeof(double) * (ORDER - 1)); hx[0] = xb[i];
                }
                int s0 = 0; while (s0 < SCALES - 1 && scales[s0] * 7.5 < mx) s0++;
                for (int s = s0 - 4; s <= s0 + 2; s++) {
                    if (s < 0 || s >= SCALES) continue;
                    Node t; memset(&t, 0, sizeof t);
                    double lim = n >= BEAM ? nxt[n - 1].cost - cur[k].cost : 1e290;
                    double e = run(xb, c, scales[s], cur[k].h, t.h, t.code + 1, w, lim, cur[k].e, t.e, gamma);
                    if (e > 1e290) continue;
                    t.cost = cur[k].cost + e; t.parent = k; t.code[0] = (uint8_t)(s << 3 | p);
                    int dup = 0;
                    for (int j = 0; j < n; j++) if (!memcmp(nxt[j].h, t.h, sizeof t.h)) { dup = nxt[j].cost <= t.cost ? 1 : 2;
                        if (dup == 2) { memmove(nxt + j, nxt + j + 1, sizeof(Node) * (n - j - 1)); n--; dup = 0; } break; }
                    if (dup) continue;
                    int at = n; while (at > 0 && nxt[at - 1].cost > t.cost) at--;
                    if (at >= BEAM) continue;
                    int top = n < BEAM ? n : BEAM - 1;
                    memmove(nxt + at + 1, nxt + at, sizeof(Node) * (top - at));
                    nxt[at] = t; if (n < BEAM) n++;
                }
            }
        }
        if (!n) return -1;
        count[b + 1] = n;
    }
    int k = 0;
    for (int b = blocks; b > 0; b--) {
        Node *nd = &nodes[b * BEAM + k];
        memcpy(out + (b - 1) * 17, nd->code, 17);
        if (b == mark) memcpy(hmark, nd->h, sizeof nd->h);
        k = nd->parent;
    }
    /* decode, as the engine does */
    int h[ORDER]; memcpy(h, hist, sizeof h);
    for (int b = 0; b < blocks; b++) {
        const uint8_t *q = out + b * 17; const int16_t *c = pred + (q[0] & 7) * ORDER; int sc = scales[q[0] >> 3];
        for (int i = 0; i < BL; i++) {
            int v = q[1 + (i >> 1)] >> (i & 1 ? 4 : 0) & 15; v = (v ^ 8) - 8;
            int pr = 0;
            for (int k = 0; k < ORDER; k++) pr += c[k] * h[k];
            int y = sat16((pr >> 12) + v * sc);
            recon[b * BL + i] = (int16_t)y;
            memmove(h + 1, h, sizeof(int) * (ORDER - 1)); h[0] = y;
        }
    }
    free(nodes); free(count);
    return 0;
}

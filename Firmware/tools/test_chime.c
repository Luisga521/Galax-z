/* The chime on the Mac: what it sounds like, in numbers. Built and run by test_chime.py. */
#define CHIME_TEST
#include "../chime/chime.c"
#include <math.h>
#include <stdio.h>
#include <string.h>
static int fails;
#define CHECK(x) do { if (!(x)) { printf("FAILED line %d: %s\n", __LINE__, #x); fails++; } } while (0)
static double power(const double *x, int from, int n, double hz) { double s = 0, c = 0; for (int i = 0; i < n; i++) { s += x[from + i] * sin(2 * M_PI * hz * i / RATE); c += x[from + i] * cos(2 * M_PI * hz * i / RATE); } return hypot(s, c) * 2 / n; }
int main(int argc, char **argv)
{
    (void)argv;
    chime_start();
    if (argc > 1) {                                             /* the sums the Blackfin's bytes are held to */
        for (int block = 0; block < 1200; block++) {
            i32 mix[128]; u32 sum = 0; int changed = 0;
            for (int i = 0; i < 128; i++) mix[i] = (i32)((u32)((i + 16) * 7919 + block) << 8);
            chime_block(mix);
            for (int i = 0; i < 128; i++) { sum = sum * 31 + (u32)mix[i]; changed += mix[i] != (i32)((u32)((i + 16) * 7919 + block) << 8); }
            if (block % 25 == 0 || changed) printf("b %d %u %d\n", block, sum, changed);
        }
        printf("ok\n");
        return 0;
    }
    static double x[RATE * 3]; int n = 0, last = 0;
    for (int b = 0; b < RATE * 3 / FRAMES; b++) {
        i32 m[128] = { 0 };
        chime_block(m);
        for (int i = 0; i < FRAMES; i++) { CHECK(m[i * 2] == m[i * 2 + 1]); x[n++] = m[i * 2] / 2147483648.0; if (m[i * 2]) last = n; }
    }
    double peak = 0, jump = 0; for (int i = 0; i < n; i++) { peak = fmax(peak, fabs(x[i])); if (i) jump = fmax(jump, fabs(x[i] - x[i - 1])); }
    CHECK(peak < 0.0626 && peak > 0.061);                       /* -24 dB, never more */
    CHECK(jump < 0.0626 * 2 * M_PI * 2525 / RATE * 1.02);       /* no click: not steeper than the tone itself */
    for (int i = 0; i < QUIET; i++) CHECK(x[i] == 0);
    for (int i = QUIET + TONE; i < QUIET + TONE + GAP; i++) CHECK(x[i] == 0);
    CHECK(last <= QUIET + TONE + GAP + TONE && last > QUIET + TONE + GAP + TONE - 64);
    int a = QUIET + 2000, c = QUIET + TONE + GAP + 2000, w = 4410 * 2;
    CHECK(fabs(power(x, a, w, 2525) - 0.0625) < 0.002 && power(x, a, w, 2475) < 0.02 && fabs(power(x, c, w, 2475) - 0.0625) < 0.002 && power(x, c, w, 2525) < 0.02);
    for (int h = 2; h < 7; h++) CHECK(power(x, a, w, 2525 * h) < 0.0625 * 0.003);                 /* clean */
    /* loud already: it stops at full, it does not go round */
    chime_at = QUIET + 2048; i32 m[128];
    for (int i = 0; i < 128; i++) m[i] = i & 2 ? (i32)0x80000000 : 0x7fffffff;
    chime_block(m);
    for (int i = 0; i < 128; i++) CHECK(i & 2 ? m[i] < -1900000000 : m[i] > 1900000000);
    /* over, it changes nothing, for ever; nothing to write to is nothing done */
    chime_at = QUIET + 2 * TONE + GAP; for (int i = 0; i < 128; i++) m[i] = i; chime_block(m); for (int i = 0; i < 128; i++) CHECK(m[i] == i);
    /* not started (TE's setting is off): nothing, from the first block */
    chime_at = OVER; for (int i = 0; i < 128; i++) m[i] = -i; chime_block(m); for (int i = 0; i < 128; i++) CHECK(m[i] == -i);
    chime_start(); CHECK(chime_at == 0 && phase == 0); chime_at = OVER;
    u32 was = chime_at; for (int i = 0; i < 100000; i++) chime_block(m); CHECK(chime_at == was);
    chime_at = QUIET; chime_block(0); CHECK(chime_at == QUIET);
    printf(fails ? "%d FAILED\n" : "ok\n", fails);
    return fails != 0;
}

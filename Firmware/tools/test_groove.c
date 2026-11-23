/* The red page on the Mac: every groove, every progression, every dial value, beside what TO-2's rules make. Built and run by test_groove.py. */
#define PAGES_TEST
#include "../pages/pages.c"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static u8 *mem; static u32 clock_ms; static u8 rec[53 * 5], pat[0x2000];
typedef struct { int t, n, v, l; } Hit;
static Hit hits[4096]; static int nh, recs;
u8 *os_seq(void) { return mem; }
u32 os_ms(void) { return clock_ms; }
void os_play(u8 *s, i32 t, i32 n, i32 v, i32 l) { (void)s; if (nh < 4096) hits[nh++] = (Hit){ t, n, v, l }; }
void os_led(i32 i, i32 r, i32 g, i32 b, i32 w) { if (i < 0 || i > 52 || r < 0 || r > 255 || g < 0 || g > 255 || b < 0 || b > 255 || w < 0 || w > 255) abort(); rec[i*5]=r; rec[i*5+1]=g; rec[i*5+2]=b; rec[i*5+3]=w; }
u8 *os_led_record(i32 i) { return rec + i * 5; }
void os_where(u8 *s, i32 t, i32 *st, i32 *m) { (void)s; (void)t; *st = 3; *m = 0; }
void os_record(u8 *s, i32 t, i32 st, i32 m, i32 n, i32 v, i32 l) { (void)s; (void)t; (void)st; (void)m; (void)n; (void)v; (void)l; recs++; }
u8 *os_pattern(u8 *s) { (void)s; return pat; }
i32 os_slot(i32 t) { static const i32 k[] = { 0, 2, 4, 6, 8, 12, 16, 24, 28, 29 }; return k[t]; }
static void put(u32 at, i32 v) { memcpy(mem + at, &v, 4); }
#define CHECK(x) do { if (!(x)) { printf("FAILED line %d: %s\n", __LINE__, #x); fails++; } } while (0)
static int fails;

static void fresh(int track, int playing)
{
    static const u8 new[GKNOBS] = RED_NEW;
    memset(mem, 0, 0x3a0000); memset(grooves, 0, sizeof grooves); memset(euclids, 0, sizeof euclids); memset(tumblers, 0, sizeof tumblers);
    for (int t = 0; t < 8; t++) memcpy(gknob[t], new, GKNOBS);
    put(SEQ_TRACK, track); put(SEQ_PAGE, RED); put(SEQ_HELD_STEP, 31); put(SEQ_LENGTH, 16); put(SEQ_SCREEN, (i32)(__SIZE_TYPE__)(mem + SEQ_STEPS));
    mem[SEQ_PLAYING] = (u8)playing; was_playing = (u8)playing; waiting = 0; beat = 0xffffffff; nh = recs = 0; ntakes = 0; flashes = 0; shift_held = touched = 0;
    memset(pat, 0xff, sizeof pat); for (int t = 0; t < 16; t++) pat[t * 12 + 6] = 1;
}
/* a tick as the OS makes it (96 a beat) */
static u32 tk;
static void tick(void) { put(SEQ_TICK, (i32)(tk % 24)); put(SEQ_STEP, (i32)(tk / 24 % 16)); tk++; clock_ms += 5; pages_tick(mem); }
static void press(int track, int note) { pages_note(mem, track, note); }

int main(void)
{
    mem = malloc(0x3a0000);
    /* each groove, two bars at 1/16: hits and velocities as its sixteen marks */
    for (int g = 0; g < GROOVES; g++) {
        fresh(4, 0); tk = 0;
        int v = 0; while ((v * GROOVES >> 8) != g) v++;
        gknob[4][GROOVE] = (u8)v;
        press(4, 60); CHECK(grooves[4].n == 1 && nh == 0);
        for (int i = 0; i < 2 * 384; i++) {
            int was = nh; tick();
            int on = i % 24 == 0 && groove[g].hit >> (i / 24 % 16) & 1;
            CHECK(nh - was == on);
            if (on) { u32 b = 1u << (i / 24 % 16); CHECK(hits[was].n == 60 && hits[was].t == 4 && hits[was].v == (groove[g].accent & b ? 118 : groove[g].ghost & b ? 45 : 85)); CHECK(hits[was].l == 24 * (26 + (153 * 218 >> 8))); }
        }
    }
    /* every RATE: as many steps as there are */
    for (int d = 0; d < 256; d++) {
        fresh(5, 0); tk = 0; gknob[5][G_RATE] = (u8)d;
        int all = 0; while ((all * GROOVES >> 8) != 11) all++;                          /* RUN: every step */
        gknob[5][GROOVE] = (u8)all; CHECK(groove[11].hit == 0xffff);
        press(5, 64);
        for (int i = 0; i < 384; i++) tick();
        CHECK(nh == 384 / DIV[d * 1796 >> 16]);
        /* SWING keeps as many, and never reaches the next step */
        fresh(5, 0); tk = 0; gknob[5][G_RATE] = (u8)d; gknob[5][GROOVE] = (u8)all; gknob[5][SWING] = 255; press(5, 64);
        for (int i = 0; i < 384; i++) tick();
        CHECK(nh == 384 / DIV[d * 1796 >> 16]);
    }
    /* orders */
    for (int o = 0; o < 5; o++) {
        fresh(6, 0); tk = 0; int v = 0; while ((v * 5 >> 8) != o) v++; gknob[6][ORDER] = (u8)v; gknob[6][GROOVE] = 0;
        press(6, 67); press(6, 60); press(6, 64);
        for (int i = 0; i < 384; i++) tick();
        CHECK(nh == (o ? 6 : 18));
        static const int want[5][6] = { { 60, 64, 67, 60, 64, 67 }, { 60, 64, 67, 60, 64, 67 }, { 67, 64, 60, 67, 64, 60 }, { 67, 60, 64, 67, 60, 64 }, { 0 } };
        for (int i = 0; i < 6; i++) CHECK(o == 4 ? hits[i].n == 60 || hits[i].n == 64 || hits[i].n == 67 : hits[i].n == want[o][i]);
    }
    /* every progression, key, length and register: the chord's own notes, rooted at the key or within an octave under it, in range */
    static const int deg[7] = { 0, 2, 4, 5, 7, 9, 11 };
    for (int p = 1; p <= PROGS; p++) for (int key = 0; key < 12; key++) {
        fresh(7, 0);
        int v = 0; while ((v * (PROGS + 1) >> 8) != p) v++;
        gknob[7][PROG] = (u8)v; v = 0; while ((v * 12 >> 8) != key) v++; gknob[7][KEY] = (u8)v;
        int reg = (p * 7 + key * 11) % 128; press(7, reg);
        int n = prog_at[p] - prog_at[p - 1];
        for (int bar = 0; bar < n + 2; bar++) {
            beat = (u32)bar * 384 + 5;
            u8 out[8]; int m = groove_notes(7, &grooves[7], gknob[7], out);
            u8 c = prog[prog_at[p - 1] + bar % n]; const u8 *tones = chord_notes[c >> 3 & 15];
            int root = (key + deg[(c & 7) - 1] - (c >> 7) + 12) % 12, want = 0;
            while (want < 5 && tones[want] != 255) want++;
            CHECK((c & 7) >= 1 && (c >> 3 & 15) < 13 && m == want && want >= 3);
            for (int i = 0; i < m; i++) CHECK(out[i] < 128 && (out[i] - root - tones[i] + 1200) % 12 == 0);
            if (reg >= 12 && reg < 112) CHECK(out[0] <= reg && out[0] > reg - 12);
        }
    }
    /* ROYAL ROAD in C over C4: F G Em Am, a bar each; half and four bars */
    static const int roots[4] = { 53, 55, 52, 57 };
    for (int len = 0; len < 4; len++) {
        fresh(7, 0); gknob[7][PROG] = 2; gknob[7][LENGTH] = (u8)(len * 64); CHECK(progression(7, gknob[7]) == 1); press(7, 60);
        for (int k = 0; k < 8; k++) { beat = (u32)k * (192u << len) + 1; u8 out[8]; groove_notes(7, &grooves[7], gknob[7], out); CHECK(out[0] == roots[k % 4]); }
    }
    /* with a progression one key is kept; a drum track has none; again lets go; eight at the most */
    fresh(7, 0); gknob[7][PROG] = 200; press(7, 60); press(7, 67); CHECK(grooves[7].n == 1 && grooves[7].key[0] == 67); press(7, 67); CHECK(grooves[7].n == 0);
    fresh(1, 0); gknob[1][PROG] = 200; press(1, 53); press(1, 55); CHECK(grooves[1].n == 2 && !progression(1, gknob[1]));
    fresh(5, 0); for (int k = 0; k < 12; k++) press(5, 40 + k); CHECK(grooves[5].n == 8 && grooves[5].key[0] == 44); press(5, 46); CHECK(grooves[5].n == 7);
    /* only its own page and track */
    fresh(5, 0); put(SEQ_PAGE, 3); press(5, 60); CHECK(!grooves[5].n); put(SEQ_PAGE, RED); press(6, 60); CHECK(!grooves[6].n && !grooves[5].n); pages_note(mem, 9, 60); pages_note(mem, 5, 300); pages_note(mem, 5, -1); CHECK(!grooves[5].n);
    put(SEQ_PAGE, TEAL); press(5, 60); CHECK(euclids[5].n == 1 && !grooves[5].n);
    /* dials: the layer, the ends, the LEDs light green */
    fresh(5, 0);
    CHECK(pages_knob(5, 0, 300) == 1 && gknob[5][GROOVE] == 255 && pages_knob(5, 2, -999) == 1 && gknob[5][G_GATE] == 0 && pages_knob(5, 4, 1) == 0 && pages_knob(4, 0, 1) == 0);
    grooves[5].more = 1; CHECK(pages_knob(5, 0, 9) == 1 && gknob[5][PROG] == 9); CHECK(pages_dials() == 1 && rec[40 * 5 + 1] > 0 && rec[40 * 5] * 2 < rec[40 * 5 + 1] + 2 && rec[40 * 5 + 2] * 4 < rec[40 * 5 + 1] + 4);
    CHECK(pages_fade(41, 255) == 1 && rec[41 * 5 + 1] > 250 && rec[41 * 5] > 80 && rec[41 * 5] < 100 && rec[41 * 5 + 2] < 40);
    /* SHIFT alone two seconds: MORE, and back; another page forgets it */
    fresh(5, 0); mem[SEQ_SHIFT] = 1; mem[SEQ_CLEAN] = 1; tk = 0; for (int i = 0; i < 450; i++) tick(); CHECK(grooves[5].more == 1 && !mem[SEQ_CLEAN]);
    mem[SEQ_SHIFT] = 0; tick(); put(SEQ_PAGE, 0); tick(); CHECK(!grooves[5].more);
    /* the step row: the groove, its accents brighter, the step that plays marked */
    fresh(4, 0); tk = 0; gknob[4][GROOVE] = 0; press(4, 60); for (int i = 0; i < 25; i++) tick(); pages_paint();
    CHECK(rec[1] == 255 && rec[0] == 90 && rec[3 * 5 + 1] > 100 && rec[3 * 5 + 1] < 255 && rec[2 * 5 + 1] < 20 && rec[1 * 5 + 3] > 0 && rec[0 * 5 + 3] == 0);
    /* STOP on the page empties it and is all that happens; elsewhere while stopped empties everything */
    CHECK(pages_stop() == 1 && !grooves[4].n && pages_stop() == 0);
    press(4, 60); put(SEQ_PAGE, 0); CHECK(pages_stop() == 0 && !grooves[4].n);
    fresh(4, 1); press(4, 60); put(SEQ_PAGE, 0); CHECK(pages_stop() == 0 && grooves[4].n == 1);
    /* it starts with the sequencer's first step */
    fresh(4, 0); press(4, 60); tk = 20; mem[SEQ_PLAYING] = 1; was_playing = 0; nh = 0; tick(); tick(); CHECK(nh == 0); tk = 24; tick(); CHECK(nh == 1);
    /* EUCLID and a groove at once, on one grid: the second does not start it again */
    fresh(4, 0); tk = 0; press(4, 60); for (int i = 0; i < 50; i++) tick(); u32 b = beat; put(SEQ_PAGE, TEAL); put(SEQ_TRACK, 5); press(5, 62); CHECK(beat == b && euclids[5].n == 1);
    put(SEQ_PAGE, RED); press(5, 64); CHECK(beat == b && grooves[5].n == 1);
    /* with REC it goes into the pattern */
    fresh(4, 1); mem[SEQ_REC] = 1; press(4, 60); tk = 0; for (int i = 0; i < 48; i++) tick(); mem[SEQ_PLAYING] = 0; tick(); CHECK(recs > 0);
    /* a storm */
    srand(7); fresh(4, 1); tk = 0;
    for (int i = 0; i < 300000; i++) {
        switch (rand() % 14) {
        case 0: press(rand() % 10, rand() % 140 - 5); break;
        case 1: put(SEQ_TRACK, rand() % 16); break;
        case 2: put(SEQ_PAGE, rand() % 8); break;
        case 3: case 4: pages_knob(word(mem, SEQ_TRACK), rand() % 5, rand() % 61 - 30); break;
        case 5: if (rand() % 20 == 0) pages_stop(); break;
        case 6: mem[SEQ_PLAYING] ^= rand() % 30 == 0; break;
        case 7: mem[SEQ_SHIFT] ^= rand() % 10 == 0; break;
        case 8: pages_dials(); pages_paint(); pages_fade(40 + rand() % 4, rand() % 256); break;
        case 9: put(SEQ_HELD_STEP, rand() % 4 ? 31 : rand() % 16); break;
        default: tick();
        }
        if (nh > 4000) nh = 0;
    }
    for (int i = 0; i < nh; i++) CHECK(hits[i].t >= 0 && hits[i].t < 8 && hits[i].n >= 0 && hits[i].n < 128 && hits[i].v > 0 && hits[i].v < 128 && hits[i].l > 0);
    for (int t = 0; t < 8; t++) CHECK(grooves[t].n <= 8);
    printf(fails ? "%d FAILED\n" : "ok\n", fails);
    return fails != 0;
}

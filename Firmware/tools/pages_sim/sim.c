/* The pages' own Blackfin bytes (patches/pages.json, loaded at their address) run in bfin-elf-run: every hook, with
 * every register checked, and the physics over the knobs' range. Prints FAILED lines, then "ok" or a count. */
#include "block.h"
typedef unsigned int u32; typedef int i32; typedef unsigned char u8;
u32 flash_args[8], in[16], out[16], args[16], saved_sp, seen[9], play_args[13], now, hook_knob_at, at[2], rec_args[10];
static int fails, plays, vmin = 999, vmax;
extern void call_hook(void), knob_entry(void);
#define SEQ ((u8 *)0x81200000)
#define W(a) (*(volatile i32 *)(a))
#define LED(i, c) (((volatile u8 *)0x0802d3a4)[(i) * 5 + (c)])

static int sys(int nr, u32 *a) { register int r0 __asm__("R0") = (int)a; register int p0 __asm__("P0") = nr; __asm__ volatile("EXCPT 0;" : "+r"(r0), "+r"(p0) : : "R1", "R2", "R3", "P1", "P2", "cc", "memory"); return r0; }
static void put(const char *s) { u32 n = 0; while (s[n]) n++; u32 a[3] = { 1, (u32)s, n }; sys(5, a); }
static void num(i32 v) { char b[12]; int i = 11; b[i] = 0; u32 u = v < 0 ? -v : v; do { b[--i] = '0' + u % 10; u /= 10; } while (u); if (v < 0) b[--i] = '-'; put(b + i); }
void sim_exit(void) { u32 a[1] = { fails != 0 }; sys(1, a); }
#define CHECK(x) do { if (!(x)) { put("FAILED line "); num(__LINE__); put(": " #x "\n"); fails++; } } while (0)

void played(void)
{
    plays++;
    if (play_args[0] != (u32)SEQ || play_args[2] != play_args[3] || play_args[3] != play_args[4] || play_args[7] != 1 || play_args[8] || play_args[9] != 0xffffffff
        || play_args[10] != 0x2000 || play_args[11] || play_args[12]) { put("FAILED play args\n"); fails++; }
    if ((i32)play_args[5] < vmin) vmin = play_args[5];
    if ((i32)play_args[5] > vmax) vmax = play_args[5];
}

static void hook(u32 target)
{
    for (int i = 0; i < 9; i++) seen[i] = 0;
    for (int i = 0; i < 16; i++) if (i != 0 && i != 1 && i != 2 && i != 15 && i != 4 && i != 5 && i != 13 && i != 10) in[i] = 0xa5000000 + i * 0x111;
    in[15] = target;
    call_hook();
    for (int i = 4; i < 8; i++) CHECK(out[i] == in[i]);
    for (int i = 11; i < 15; i++) CHECK(out[i] == in[i]);
    CHECK(out[15] == 0);
}
static void set(u32 r0, u32 r1, u32 r2) { in[0] = r0; in[1] = r1; in[2] = r2; in[4] = 0x44444444; in[5] = 0x55555555; in[13] = 0x13131313; in[10] = 0x10101010; }

static int turn(int track, int dial, int delta)
{
    set(6, 0x81112f3c, 0); in[4] = dial; in[5] = track; in[13] = (u32)SEQ; in[10] = 0x7e57; args[0] = delta;
    hook_knob_at = HOOK_KNOB;
    hook((u32)knob_entry);
    if (seen[3] == 5) CHECK(seen[0] == 6 && seen[1] == 0x81112f3c && seen[4] == 0x345e2c && seen[5] == 0x7e57 && seen[6] == (u32)SEQ && seen[7] == (u32)dial && seen[8] == (u32)track);
    CHECK(out[0] == 0);
    return seen[3] != 5;
}
#define T(track) (TUMBLERS_AT + (track) * 168)
#define N(track) W(T(track) + 160)
#define KNOB(track) ((u8 *)KNOB_AT + (track) * 12)
#define G_N(track) (((volatile u8 *)GROOVES_AT)[(track) * 11])
#define G_KEY(track) ((u8 *)GROOVES_AT + (track) * 11 + 1)
#define G_MORE(track) (((volatile u8 *)GROOVES_AT)[(track) * 11 + 10])
#define GKNOB(track) ((u8 *)GKNOB_AT + (track) * 8)
#define E_N(track) W(EUCLIDS_AT + (track) * 60)

int main(void)
{
    for (u32 i = 0; i < 16; i++) args[i] = 0x7000 + i;
    W(0x81059d1c) = (i32)SEQ;
    W(SEQ + 0x30) = 4; W(SEQ + 0x345e2c) = 4; W(SEQ + 0x7c) = 31; W(SEQ + 0x3c) = 16; W(SEQ + 0x3463bc) = (i32)(SEQ + 0x346260); W(SEQ + 0x690) = 0;

    /* notes: each goes on to playNote as it came */
    args[0] = 60; args[1] = 60; args[2] = 100; args[3] = -1; args[4] = 1; args[5] = 0; args[6] = -1; args[7] = 0x2000; args[8] = 0; args[9] = 0;
    set((u32)SEQ, 4, 60); hook(HOOK_NOTE); CHECK(plays == 1 && play_args[1] == 4 && play_args[2] == 60 && play_args[6] == 0xffffffff); CHECK(N(4) == 1);
    set((u32)SEQ, 5, 60); hook(HOOK_NOTE); CHECK(plays == 2 && N(5) == 0);
    W(SEQ + 0x345e2c) = 3; set((u32)SEQ, 4, 60); hook(HOOK_NOTE); CHECK(N(4) == 1);

    /* dials: not ours on page 4, ours on page 5 */
    CHECK(!turn(4, 1, 3)); W(SEQ + 0x345e2c) = 4; CHECK(turn(4, 1, 3)); CHECK(KNOB(4)[1] == 156); CHECK(turn(4, 3, -500)); CHECK(KNOB(4)[3] == 0);
    W(SEQ + 0x30) = 9; CHECK(!turn(9, 0, 1)); W(SEQ + 0x30) = 4;

    /* dial LEDs and their flash (a tick first, as on the OP-Z) */
    set((u32)SEQ, 0, 0); hook(HOOK_TICK);
    set(0x1234, 0, 0); hook(HOOK_DIALS); CHECK(seen[3] == 0 && LED(40, 0) > 100 && LED(43, 0) < 12 && LED(40, 1) == 0 && LED(40, 2) > 30);
    W(SEQ + 0x345e2c) = 0; set(0x1234, 0, 0); hook(HOOK_DIALS); CHECK(seen[3] == 6 && seen[0] == 0x1234);
    set(41, 0x5f, 200); hook(HOOK_FADE); CHECK(seen[3] == 2 && seen[0] == 41 && seen[1] == 0x5f && seen[2] == 200);
    W(SEQ + 0x345e2c) = 4; LED(41, 0) = 0; set(41, 0x5f, 200); hook(HOOK_FADE); CHECK(seen[3] == 0 && LED(41, 0) == 199);

    /* the frame, the balls on the step row */
    now = 1000; set((u32)SEQ, 0, 0); hook(HOOK_TICK); CHECK(seen[3] == 1 && seen[0] == (u32)SEQ);
    plays = 0;
    for (int i = 0; i < 400; i++) { now += 5; set((u32)SEQ, 0, 0); hook(HOOK_TICK); }
    CHECK(plays > 0);
    for (int i = 0; i < 80; i++) LED(i / 5, i % 5) = 0;
    set(0x77, 0, 0); hook(HOOK_PAINT); CHECK(seen[3] == 4 && seen[0] == 0x77);
    int lit = 0; for (int i = 0; i < 16; i++) lit += LED(i, 0) > 0; CHECK(lit > 0 && lit < 4);

    /* recording: once the playhead is past */
    for (u32 i = 0; i < 10; i++) W(0x811130e8 + i * 4) = i < 5 ? i * 2 : i * 4;
    for (u32 i = 0; i < 0x2000; i++) ((u8 *)0x81240000)[i] = 0xff;
    W(SEQ + 0x690) = 0x81240000; ((u8 *)0x81240000)[4 * 12 + 6] = 1;
    W(SEQ + 0x7c) = 31; SEQ[0x1c] = 1; SEQ[0x1f] = 1; at[0] = 9; at[1] = 24;
    for (int i = 0; i < 2000 && !rec_args[9]; i++) { if (i == 400) at[1] = 32; now += 5; set((u32)SEQ, 0, 0); hook(HOOK_TICK); if (!(i & 127)) { set((u32)SEQ, 4, 60); args[0] = args[1] = 60; args[3] = -1; hook(HOOK_NOTE); } }
    CHECK(rec_args[9] >= 1 && rec_args[0] == (u32)SEQ + 0x346260 && rec_args[1] == 2 && rec_args[2] == 4 && rec_args[3] == 9 && rec_args[4] == 24 && rec_args[5] == 60 && rec_args[6] >= 38 && rec_args[6] < 128 && rec_args[7] == 36 << 8 && !rec_args[8]);
    at[1] = -20; u32 was = rec_args[9];
    for (int i = 0; i < 200; i++) { now += 5; set((u32)SEQ, 0, 0); hook(HOOK_TICK); if (!(i & 63)) { set((u32)SEQ, 4, 64); args[0] = args[1] = 64; args[3] = -1; hook(HOOK_NOTE); } }
    CHECK(rec_args[9] == was);
    at[1] = 10; set((u32)SEQ, 0, 0); hook(HOOK_TICK); CHECK(rec_args[9] > was && (i32)rec_args[4] == -20 && rec_args[3] == 9);
    SEQ[0x1f] = 0; was = rec_args[9]; for (int i = 0; i < 400; i++) { now += 5; set((u32)SEQ, 0, 0); hook(HOOK_TICK); } CHECK(rec_args[9] <= was);
    W(SEQ + 0x690) = 0;

    /* STOP */
    SEQ[0x1c] = 1; set((u32)SEQ, 0, 0); hook(HOOK_STOP); CHECK(seen[3] == 0 && N(4) == 0);
    set((u32)SEQ, 0, 0); hook(HOOK_STOP); CHECK(seen[3] == 3 && seen[0] == (u32)SEQ);
    SEQ[0x1c] = 0; N(2) = 0; set((u32)SEQ, 0, 0); hook(HOOK_STOP); CHECK(seen[3] == 3);

    /* physics, as compiled: a full hexagon at several settings */
    static const u8 kn[][4] = { {115,153,64,38}, {255,255,255,255}, {0,0,0,0}, {255,0,255,0}, {40,230,120,255} };
    for (u32 c = 0; c < sizeof kn / 4; c++) {
        for (int i = 0; i < 4; i++) KNOB(4)[i] = kn[c][i];
        N(4) = 0;
        for (int i = 0; i < 8; i++) { set((u32)SEQ, 4, 60 + i); args[0] = args[1] = 60 + i; args[3] = -1; hook(HOOK_NOTE); }
        CHECK(N(4) == 8);
        plays = 0; vmin = 999; vmax = 0;
        i32 far = 0;
        for (int i = 0; i < 2000; i++) {
            now += 5; set((u32)SEQ, 0, 0); hook(HOOK_TICK);
            for (int b = 0; b < 8; b++) { i32 x = W(T(4) + b * 20) >> 12, y = W(T(4) + b * 20 + 4) >> 12, d = x * x + y * y; if (d > far) far = d; }
        }
        CHECK(far < 3359 * 3359);       /* 0.82 */
        put("bounces in 10 s: "); num(plays); put("  velocity "); num(vmin); put(".."); num(vmax); put("\n");
    }
    /* a key: SHIFT is not alone; a MIDI note is nothing */
    *(u8 *)TOUCHED_AT = 0; args[2] = 1; set((u32)SEQ, 4, 60); hook(HOOK_ON); CHECK(seen[3] == 7 && seen[0] == (u32)SEQ && seen[1] == 4 && seen[2] == 60 && !*(u8 *)TOUCHED_AT);
    args[2] = 0x2000; set((u32)SEQ, 4, 60); hook(HOOK_ON); CHECK(seen[3] == 7 && *(u8 *)TOUCHED_AT == 1);

    /* EUCLID as compiled: E(3,8) from the first step, then a full second at every RATE, with MORE and a recorded dial */
    W(SEQ + 0x345e2c) = 5; N(4) = 0; SEQ[0x1f] = 0; SEQ[0x1c] = 0; W(SEQ + 0x690) = 0;
    set((u32)SEQ, 0, 0); hook(HOOK_TICK);
    args[0] = args[1] = 60; args[2] = 100; args[3] = -1; args[4] = 1; args[5] = 0; args[6] = -1; args[7] = 0x2000; set((u32)SEQ, 4, 60); hook(HOOK_NOTE); CHECK(E_N(4) == 1);
    SEQ[0x1c] = 1; W(SEQ + 0x40) = 20; set((u32)SEQ, 0, 0); hook(HOOK_TICK);
    plays = 0; u32 when = 0;
    for (int i = 0; i < 384; i++) { W(SEQ + 0x40) = i % 24; W(SEQ + 0x38) = i / 24; for (int t = 0; t < 8; t++) SEQ[0x345d3a + t] = i / 24 << 4; now += 5; int was_p = plays; set((u32)SEQ, 0, 0); hook(HOOK_TICK); if (plays != was_p && i < 24 * 9) when = when * 16 + i / 24; }
    CHECK(plays == 6 && when == 0x0368);
    set(0x1234, 0, 0); hook(HOOK_DIALS); CHECK(seen[3] == 0 && LED(40, 0) == 0 && LED(40, 1) > 100 && LED(40, 2) > 40);
    set(0x77, 0, 0); hook(HOOK_PAINT); int white = 0; for (int i = 0; i < 16; i++) white += LED(i, 3) > 0; CHECK(white == 1 && LED(0, 1) > 100);
    SEQ[0x14] = 1; SEQ[0x39c123] = 1; *(u8 *)TOUCHED_AT = 0;
    for (int i = 0; i < 420; i++) { now += 5; set((u32)SEQ, 0, 0); hook(HOOK_TICK); }
    CHECK(SEQ[0x39c123] == 0); SEQ[0x14] = 0; set((u32)SEQ, 0, 0); hook(HOOK_TICK);
    CHECK(turn(4, 0, 7)); CHECK(KNOB(4)[8] == 135);
    SEQ[0x1f] = 1; CHECK(turn(4, 1, -20)); CHECK(KNOB(4)[9] == 77); CHECK(((u8 *)0x80c40000)[(4 * 12 + 9) * 16 + 15] == 57); SEQ[0x1f] = 0;
    for (int d = 0; d < 256; d += 5) { KNOB(4)[7] = d; KNOB(4)[4] = 255 - d; KNOB(4)[5] = d; for (int i = 0; i < 96; i++) { now += 5; set((u32)SEQ, 0, 0); hook(HOOK_TICK); } set(0x77, 0, 0); hook(HOOK_PAINT); }
    W(SEQ + 0x30) = 1; set((u32)SEQ, 1, 53); args[0] = args[1] = 53; hook(HOOK_NOTE); CHECK(E_N(1) == 1); CHECK(turn(1, 0, -300)); CHECK(turn(1, 2, 300));
    plays = 0; for (int i = 0; i < 384; i++) { now += 5; set((u32)SEQ, 0, 0); hook(HOOK_TICK); } CHECK(plays > 8);
    set(0x1234, 0, 0); hook(HOOK_DIALS); set(0x77, 0, 0); hook(HOOK_PAINT);
    W(SEQ + 0x30) = 4; set((u32)SEQ, 0, 0); hook(HOOK_STOP); CHECK(seen[3] == 0 && E_N(4) == 0);

    /* the red page as compiled: notes, a bar of TRESILLO, dials, MORE, a progression, the LEDs, STOP */
    W(SEQ + 0x345e2c) = 6; W(SEQ + 0x30) = 7; W(SEQ + 0x7c) = 31; SEQ[0x1c] = 0; SEQ[0x1f] = 0; SEQ[0x14] = 0; W(SEQ + 0x690) = 0;
    for (int t = 0; t < 8; t++) { E_N(t) = 0; N(t) = 0; }
    set((u32)SEQ, 0, 0); hook(HOOK_TICK);
    args[0] = args[1] = 60; args[2] = 100; args[3] = -1; args[4] = 1; args[5] = 0; args[6] = -1; args[7] = 0x2000; set((u32)SEQ, 7, 60); hook(HOOK_NOTE);
    CHECK(G_N(7) == 1 && G_KEY(7)[0] == 60);
    plays = 0; when = 0;
    for (int i = 0; i < 384; i++) { now += 5; int was_p = plays; set((u32)SEQ, 0, 0); hook(HOOK_TICK); if (plays != was_p) { when |= 1u << (i / 24); CHECK(i % 24 == 0 && play_args[1] == 7 && play_args[2] == 60); } }
    CHECK(plays == 6 && when == 0x4949);
    CHECK(turn(7, 1, 5)); CHECK(GKNOB(7)[1] == 158); CHECK(turn(7, 0, -500)); CHECK(GKNOB(7)[0] == 0); CHECK(KNOB(7)[0] != 0);
    set(0x1234, 0, 0); hook(HOOK_DIALS); CHECK(seen[3] == 0 && LED(41, 1) > 100 && LED(41, 0) * 2 < LED(41, 1) && LED(41, 2) * 4 < LED(41, 1));
    LED(42, 1) = 0; set(42, 0x5f, 255); hook(HOOK_FADE); CHECK(seen[3] == 0 && LED(42, 1) > 250);
    set(0x77, 0, 0); hook(HOOK_PAINT); CHECK(LED(0, 1) > 200 && LED(3, 1) > 100 && LED(2, 1) < 20 && LED(0, 2) < 40);
    *(u8 *)TOUCHED_AT = 0; SEQ[0x14] = 1; SEQ[0x39c123] = 1;
    for (int i = 0; i < 420; i++) { now += 5; set((u32)SEQ, 0, 0); hook(HOOK_TICK); }
    SEQ[0x14] = 0; set((u32)SEQ, 0, 0); hook(HOOK_TICK); CHECK(G_MORE(7) == 1);
    CHECK(turn(7, 0, 2)); CHECK(GKNOB(7)[4] == 2);                     /* ROYAL ROAD */
    plays = 0; for (int i = 0; i < 4 * 384; i++) { now += 5; set((u32)SEQ, 0, 0); hook(HOOK_TICK); } CHECK(plays == 24 * 3);
    for (int p = 0; p < 256; p += 3) { GKNOB(7)[4] = p; GKNOB(7)[5] = 255 - p; GKNOB(7)[0] = p; GKNOB(7)[1] = p; GKNOB(7)[3] = p; GKNOB(7)[7] = p; GKNOB(7)[6] = 255 - p;
        for (int i = 0; i < 96; i++) { now += 5; set((u32)SEQ, 0, 0); hook(HOOK_TICK); CHECK((i32)play_args[2] >= 0 && (i32)play_args[2] < 128); } set(0x77, 0, 0); hook(HOOK_PAINT); set(0x1234, 0, 0); hook(HOOK_DIALS); }
    set((u32)SEQ, 0, 0); hook(HOOK_STOP); CHECK(seen[3] == 0 && G_N(7) == 0);
    set((u32)SEQ, 0, 0); hook(HOOK_STOP); CHECK(seen[3] != 0);

    /* SCREEN held (v14), as compiled: the SCREEN screen's onCC. The blue dial turns the parameter pages, both ways; the others go on to
     * TE's (CC 105-108 out); the page flashes, with TE's own flash, when SCREEN is let go */
    for (int t = 0; t < 16; t++) W(0x81112f5c + t * 4) = t < 8 ? 7 : 4;
    ((u8 *)0x811131cc)[7 * 6 + 1] = 1; ((u8 *)0x811130cc)[1] = 0x3c; W(0x81015e9c) = 0xfeed;
    W(SEQ + 0x30) = 7; W(SEQ + 0x345e2c) = 0; SEQ[0x27] = 1; flash_args[7] = 0;
#define SCREEN_TURN(c, d) (set(0x5c5c, 0x1111, (c)), args[0] = (u32)(d), hook(HOOK_SCREEN))
    SCREEN_TURN(1, 1); CHECK(seen[3] == 8 && seen[0] == 0 && seen[1] == 0x1111 && seen[2] == 1);      /* R0 = R2 - 1, as replaced */
    SCREEN_TURN(4, -1); CHECK(seen[3] == 8 && seen[0] == 3 && seen[2] == 4);
    SCREEN_TURN(2, 3); CHECK(seen[3] == 0 && out[0] == 0 && W(SEQ + 0x345e2c) == 0);
    SCREEN_TURN(2, 1); CHECK(seen[3] == 0 && out[0] == 0 && W(SEQ + 0x345e2c) == 1 && flash_args[7] == 0);
    set((u32)SEQ, 0, 0); hook(HOOK_TICK); CHECK(flash_args[7] == 0);
    SEQ[0x27] = 0; set((u32)SEQ, 0, 0); hook(HOOK_TICK);
    CHECK(flash_args[7] == 1 && flash_args[0] == 0xfeed && flash_args[1] == 2 && flash_args[2] == 500 && flash_args[3] == 1 && flash_args[4] == 0x3c && !flash_args[5] && !flash_args[6]);
    set((u32)SEQ, 0, 0); hook(HOOK_TICK); CHECK(flash_args[7] == 1);
    SEQ[0x27] = 1; SCREEN_TURN(2, -40); CHECK(W(SEQ + 0x345e2c) == 0); SCREEN_TURN(2, -4); CHECK(W(SEQ + 0x345e2c) == 6);
    W(SEQ + 0x30) = 9; W(SEQ + 0x345e2c) = 3; SCREEN_TURN(2, 4); CHECK(W(SEQ + 0x345e2c) == 0);
    SCREEN_TURN(2, 0); CHECK(seen[3] == 8);
    W(SEQ + 0x30) = 7; SEQ[0x27] = 0; set((u32)SEQ, 0, 0); hook(HOOK_TICK); W(SEQ + 0x345e2c) = 0;

    put(fails ? "FAILED\n" : "ok\n");
    return 0;
}

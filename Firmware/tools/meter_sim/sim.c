/* The meter's own Blackfin bytes (patches/meter.json) run in bfin-elf-run. Prints FAILED lines, then "ok". */
#include "block.h"
typedef unsigned int u32; typedef int i32; typedef unsigned char u8;
u32 in[16], out[16], args[16], saved_sp, seen[4], now, busy, elapsed, hook_stage_at, after[8], ons[400], offs[2];
u8 leds[53 * 5];
static int fails;
extern void call_hook(void), stage_entry(void);
#define SEQ ((u8 *)0x81200000)
#define W(a) (*(volatile i32 *)(a))
#define U(a) (*(volatile u32 *)(a))
static int sys(int nr, u32 *a) { register int r0 __asm__("R0") = (int)a; register int p0 __asm__("P0") = nr; __asm__ volatile("EXCPT 0;" : "+r"(r0), "+r"(p0) : : "R1", "R2", "R3", "P1", "P2", "cc", "memory"); return r0; }
static void put(const char *s) { u32 n = 0; while (s[n]) n++; u32 a[3] = { 1, (u32)s, n }; sys(5, a); }
static void num(u32 u) { char b[12]; int i = 11; b[i] = 0; do { b[--i] = '0' + u % 10; u /= 10; } while (u); put(b + i); }
void sim_exit(void) { u32 a[1] = { fails != 0 }; sys(1, a); }
#define CHECK(x) do { if (!(x)) { put("FAILED line "); num(__LINE__); put(": " #x "\n"); fails++; } } while (0)
static void hook(u32 target, u32 r0, u32 r1, u32 r2)
{
    for (int i = 0; i < 4; i++) seen[i] = 0;
    for (int i = 0; i < 16; i++) in[i] = 0xa5000000 + i * 0x111;
    in[0] = r0; in[1] = r1; in[2] = r2; in[15] = target;
    call_hook();
    for (int i = 4; i < 8; i++) CHECK(out[i] == in[i]);
    for (int i = 11; i < 15; i++) CHECK(out[i] == in[i]);
    CHECK(out[15] == 0);
}
static void audio(u32 turns) { busy = turns; hook(HOOK_BLOCK, 0x1234, 0x5678, 0); CHECK(seen[3] == 1 && seen[0] == 0x1234 && seen[1] == 0x5678); }
static void stage(u32 cycles)
{
    elapsed = cycles; hook_stage_at = HOOK_STAGE; hook((u32)stage_entry, 0, 0, 0);
    CHECK(after[0] == 0x10101111 && after[1] == 0x20202222 && after[2] == 0x30303333 && after[3] == 0x40404444 && after[4] == 0x20202222 && after[5] == (u32)SEQ && after[6] == after[7]);
}
static void frame(u32 ms) { now += ms; for (u32 i = 0; i < sizeof leds; i++) leds[i] = 99; hook(HOOK_FRAME, 0x77, 0, 0); CHECK(seen[3] == 3 && seen[0] == 0x77); }
static int touched(void) { int n = 0; for (int i = 0; i < 53; i++) n += leds[i * 5] != 99; return n; }
#define L(i, c) leds[(i) * 5 + (c)]
#define STAGE METER_STAGE_AT
#define TOTAL METER_TOTAL_AT

int main(void)
{
    __asm__ volatile("R0 = SYSCFG; BITSET(R0, 1); SYSCFG = R0; CSYNC;" : : : "R0");
    W(0x81059d1c) = (i32)SEQ; W(SEQ + 0x3463bc) = (i32)(SEQ + 0x346260); W(SEQ + 0x68c) = 7; now = 50000;

    /* the audio interrupt's side */
    audio(100); u32 small = U(TOTAL); CHECK(U(TOTAL + 4) == 1 && U(TOTAL + 8) == small && small > 200);
    audio(10000); u32 big = U(TOTAL) - small; CHECK(U(TOTAL + 4) == 2 && U(TOTAL + 8) == big && big > small * 20);
    audio(50); CHECK(U(TOTAL + 8) == big && U(TOTAL + 4) == 3);
    stage(1000); stage(264999); stage(5); CHECK(U(STAGE) == 1000 + 264999 + 5 && U(STAGE + 4) == 3 && U(STAGE + 8) == 264999);
    hook(HOOK_KILL, 0x99, 0, 0); CHECK(seen[3] == 2 && seen[0] == 0x99 && U(METER_KILLS_AT) == 1);

    /* off: nothing is drawn; other keys are theirs */
    frame(5); CHECK(touched() == 0);
    for (int c = 0; c < 50; c++) { hook(HOOK_KEY, (u32)SEQ, c, -1); CHECK(seen[3] == 4 && seen[0] == (u32)SEQ && seen[1] == (u32)c && seen[2] == 0xffffffff); }
    SEQ[0x22] = 1; for (int c = 0; c < 50; c++) { if (c != 49 && c != 48) { hook(HOOK_KEY, (u32)SEQ, c, -1); CHECK(seen[3] == 4); } hook(HOOK_KEY, (u32)SEQ, c, 0); CHECK(seen[3] == 4 && seen[2] == 0); }

    /* on: it starts from nothing */
    hook(HOOK_KEY, (u32)SEQ, 49, -1); CHECK(seen[3] == 0); SEQ[0x22] = 0; CHECK(U(TOTAL + 4) == 0 && U(STAGE) == 0);
    frame(5); CHECK(touched() == 20); for (int i = 0; i < 16; i++) CHECK(L(i, 0) == 0 && L(i, 1) == 0 && L(i, 3) == 0);
    /* half of the line, a block at three quarters; half of the block's time: as many steps, a white one, two dials */
#define FEED(st, st_top, to) do { U(STAGE) = (st) * 69u; U(STAGE + 4) = 69; U(STAGE + 8) = (st_top); U(TOTAL) = (to) * 69u; U(TOTAL + 4) = 69; U(TOTAL + 8) = (to) + 1000; } while (0)
    FEED(132500, 198750, 290250); frame(100);
    for (int i = 0; i < 16; i++) { if (i == 12) CHECK(L(i, 3) == 200 && L(i, 0) > 0); else CHECK(L(i, 0) == 0 && L(i, 1) == (i < 8 ? 160 : 0) && L(i, 3) == 0); }
    CHECK(L(40, 1) == 255 && L(40, 0) == 0 && L(41, 1) == 255 && L(42, 1) < 3 && L(43, 0) == 0);
    /* beyond the line: red at the end, the last dial red, never out of bounds */
    FEED(300000, 400000, 600000); frame(100); CHECK(L(15, 3) == 200 && L(14, 0) == 255 && L(14, 1) == 0 && L(13, 0) == 255 && L(11, 0) == 140 && L(9, 0) == 0 && L(9, 1) == 160 && L(43, 0) == 255 && L(43, 1) == 0);
    /* the peak stays a second and a half, then comes down */
    FEED(10000, 20000, 100000); frame(100); CHECK(L(15, 3) == 200); FEED(10000, 20000, 100000); frame(1500); CHECK(L(15, 3) == 0 && L(1, 3) == 200);
    /* a note cut off: all red for 0.4 s */
    hook(HOOK_KILL, 0x99, 0, 0); frame(5); for (int i = 0; i < 16; i++) CHECK(L(i, 0) == 255 && L(i, 1) == 0); frame(450); CHECK(L(8, 0) == 0);
    /* only on the step screen; the dials anyhow */
    W(SEQ + 0x3463bc) = 5; frame(5); CHECK(touched() == 4); W(SEQ + 0x3463bc) = (i32)(SEQ + 0x346260);
    /* no blocks: nothing to say */
    U(TOTAL + 4) = 0; frame(200); frame(200);

    /* the figures */
    u8 *r = (u8 *)REPORT_AT; CHECK(r[3] == '1' && U(r + 4) == 4 && U(r + 12) == 400000 && U(r + 20) == 601000 && U(r + 24) == 1 && U(r + 28) == 7 && U(r + 32) == 1500);
    CHECK(U(r + 8) == (132500 + 300000 + 10000 + 10000) / 4 && U(r + 16) == (290250u + 600000 + 100000 + 100000) / 4);
    SEQ[0x22] = 1; hook(HOOK_KEY, (u32)SEQ, 48, -1); CHECK(seen[3] == 0); SEQ[0x22] = 0;
    for (int i = 0; i < 100; i++) frame(0);
    CHECK(ons[0] == 80 && offs[0] == 80); u32 sum = 0, good = 1;
    for (int i = 0; i < 40; i++) { u32 a = ons[1 + i * 2], b = ons[2 + i * 2], v = ((a >> 16) - 1) << 4 | ((b >> 16) - 1); good &= (a >> 8 & 0xff) == 24u + (i * 2 & 63) && v == r[i]; if (i < 39) sum += v; else good &= (sum & 255) == v; }
    CHECK(good);
    /* off again */
    SEQ[0x22] = 1; hook(HOOK_KEY, (u32)SEQ, 49, -1); SEQ[0x22] = 0; frame(5); CHECK(touched() == 0);
    /* what it costs */
    u32 a, b; __asm__ volatile("%0 = CYCLES;" : "=d"(a)); for (int i = 0; i < 100; i++) audio(1); __asm__ volatile("%0 = CYCLES;" : "=d"(b));
    W(0x81059d1c) = 0; frame(5);
    put(fails ? "FAILED\n" : "ok\n");
    return 0;
}

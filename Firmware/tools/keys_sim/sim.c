/* The keys' own Blackfin bytes (patches/keys.json) run in bfin-elf-run: pedal, wheel, tracks. Prints FAILED lines, then "ok". */
#include "block.h"
typedef unsigned int u32; typedef int i32; typedef unsigned char u8;
typedef struct { u32 kind, r0, r1, r2, a, b, c, pad; } Call;
u32 in[16], out[16], args[16], saved_sp, now;
struct { u32 n, pad[7]; Call list[4000]; } calls;
static int fails;
extern void call_hook(void);
#define SEQ ((u8 *)0x81200000)
#define W(a) (*(volatile i32 *)(a))
#define SETTINGS (*(volatile u8 *)0x819c2bb4)
static int sys(int nr, u32 *a) { register int r0 __asm__("R0") = (int)a; register int p0 __asm__("P0") = nr; __asm__ volatile("EXCPT 0;" : "+r"(r0), "+r"(p0) : : "R1", "R2", "R3", "P1", "P2", "cc", "memory"); return r0; }
static void put(const char *s) { u32 n = 0; while (s[n]) n++; u32 a[3] = { 1, (u32)s, n }; sys(5, a); }
static void num(i32 v) { char b[12]; int i = 11; b[i] = 0; u32 u = v; do { b[--i] = '0' + u % 10; u /= 10; } while (u); put(b + i); }
void sim_exit(void) { u32 a[1] = { fails != 0 }; sys(1, a); }
#define CHECK(x) do { if (!(x)) { put("FAILED line "); num(__LINE__); put(": " #x "\n"); fails++; } } while (0)
static void hook(u32 target, u32 r1, u32 r2, u32 a, u32 b, u32 c)
{
    for (int i = 0; i < 16; i++) { in[i] = 0xa5000000 + i * 0x111; args[i] = 0x7000 + i; }
    in[0] = (u32)SEQ; in[1] = r1; in[2] = r2; in[15] = target; args[0] = a; args[1] = b; args[2] = c;
    calls.n = 0;
    call_hook();
    for (int i = 4; i < 8; i++) CHECK(out[i] == in[i]);
    for (int i = 11; i < 15; i++) CHECK(out[i] == in[i]);
    CHECK(out[15] == 0);
}
#define L calls.list
static void on(u32 ch, u32 note) { hook(HOOK_ON, ch, note, 100, 0x5c, 0x2001); const Call *k = &L[calls.n - 1]; CHECK(k->kind == 1 && k->r0 == (u32)SEQ && k->r1 == ch && k->r2 == note && k->a == 100 && k->b == 0x5c && k->c == 0x2001); }
static void off(u32 ch, u32 note) { hook(HOOK_OFF, ch, note, 0x5c, 0x2001, 0); }
static int passed(u32 track, u32 note) { return calls.n == 1 && L[0].kind == 2 && L[0].r0 == (u32)SEQ && L[0].r1 == track && L[0].r2 == note && L[0].a == 0x5c && L[0].b == 0x2001 && L[0].c == 0; }
static void cc(u32 ch, u32 c, u32 v) { hook(HOOK_CONTROL, ch, c, v, 0x5c, 0x2001); }
static void frame(u32 ms) { now += ms; hook(HOOK_FRAME, 0, 0, 0, 0, 0); CHECK(calls.n >= 1 && L[0].kind == 6); }

int main(void)
{
    W(0x81059d1c) = (i32)SEQ; W(0x11900000) = 0x4242; W(SEQ + 0x30) = 5; SETTINGS = 1 | 2 | 4;

    /* no pedal: as it was; a key of channel 1 ends where it began */
    on(0, 60); CHECK(calls.n == 1); off(0, 60); CHECK(passed(5, 60));
    on(0, 61); W(SEQ + 0x30) = 6; off(0, 61); CHECK(passed(5, 61)); off(0, 61); CHECK(passed(0, 61));   /* one it did not see begin: TE's way */
    on(3, 62); off(3, 62); CHECK(passed(3, 62));
    SETTINGS = 4; on(0, 63); W(SEQ + 0x30) = 2; off(0, 63); CHECK(passed(0, 63)); SETTINGS = 7;         /* channel 1 is track 1 */

    /* the pedal: ends wait, for their channel, and come when it does */
    W(SEQ + 0x30) = 5; cc(0, 64, 127); CHECK(calls.n == 0);
    on(0, 60); on(0, 64); on(0, 67); off(0, 60); CHECK(calls.n == 0); W(SEQ + 0x30) = 7; off(0, 64); CHECK(calls.n == 0);
    on(2, 50); off(2, 50); CHECK(passed(2, 50));                                                      /* another channel's pedal is up */
    cc(0, 64, 63); CHECK(calls.n == 2 && L[0].kind == 2 && L[0].r1 == 5 && L[0].r2 == 60 && L[0].a == 0x5c && L[0].b == 0x2001 && L[1].r1 == 5 && L[1].r2 == 64);
    off(0, 67); CHECK(passed(5, 67)); cc(0, 64, 0); CHECK(calls.n == 0);
    /* played again while it waits: ended first, once */
    cc(0, 64, 64); on(0, 60); off(0, 60); on(0, 60); CHECK(calls.n == 2 && L[0].kind == 2 && L[0].r2 == 60 && L[0].r1 == 7 && L[1].kind == 1); off(0, 60); CHECK(calls.n == 0); cc(0, 64, 0); CHECK(calls.n == 1);
    /* more than can wait: the rest end at once */
    cc(0, 64, 127); for (int i = 0; i < 64; i++) { on(0, 10 + i); off(0, 10 + i); CHECK(calls.n == 0); } on(0, 100); off(0, 100); CHECK(passed(7, 100)); cc(0, 64, 0); CHECK(calls.n == 64);
    /* HOST and INSTRUMENT switched: what waits ends, the pedal is up */
    cc(0, 64, 127); on(0, 60); off(0, 60); frame(5); CHECK(calls.n == 1); SETTINGS = 3; frame(5); CHECK(calls.n == 2 && L[1].kind == 2 && L[1].r2 == 60); on(0, 61); off(0, 61); CHECK(passed(7, 61));
    /* out of range: theirs */
    off(16, 60); CHECK(passed(16, 60)); off(0, 200); CHECK(passed(0, 200)); hook(HOOK_ON, 99, 60, 1, 2, 3); CHECK(calls.n == 1);

    /* controls that are not ours, and modulation in HOST */
    for (u32 c = 0; c < 128; c++) if (c != 64 && c != 1) { cc(0, c, 5); CHECK(calls.n == 1 && L[0].kind == 3 && L[0].r1 == 0 && L[0].r2 == c && L[0].a == 5 && L[0].b == 0x5c && L[0].c == 0x2001); }
    SETTINGS = 7; frame(5); cc(0, 1, 90); CHECK(calls.n == 1 && L[0].kind == 3); frame(5); CHECK(calls.n == 1);
    /* in INSTRUMENT: vibrato on the selected track, 5.5 a second, 50 cents; on the pitch wheel; off again at rest */
    SETTINGS = 3; frame(5); cc(3, 1, 90); CHECK(calls.n == 1 && L[0].kind == 3); cc(0, 1, 127); CHECK(calls.n == 0);
    i32 top = 0, low = 0, last = 0, turns = 0;
    for (int i = 0; i < 400; i++) { frame(5); CHECK(calls.n == 2 && L[1].kind == 5 && L[1].r0 == 0x4242 && L[1].r1 == 7 && L[1].a == 0); i32 b = (i32)L[1].r2; if (b > top) top = b; if (b < low) low = b; if (last < 0 && b >= 0) turns++; last = b; }
    CHECK(top > 520000000 && top < 545000000 && low < -520000000 && low > -545000000); CHECK(turns >= 10 && turns <= 12);
    hook(HOOK_BEND, 0, 0, 0x60, 0x5c, 0x2001); CHECK(calls.n == 1 && L[0].kind == 4 && L[0].r1 == 0 && L[0].r2 == 0 && L[0].a == 0x60 && L[0].b == 0x5c && L[0].c == 0x2001);
    top = -2147483647 - 1; low = 2147483647; for (int i = 0; i < 400; i++) { frame(5); i32 b = (i32)L[1].r2; if (b > top) top = b; if (b < low) low = b; }
    CHECK(low > 570000000 && low < 610000000 && top > 1640000000 && top < 1690000000);
    hook(HOOK_BEND, 0, 127, 127, 0x5c, 0x2001); top = 0; low = 2147483647; for (int i = 0; i < 100; i++) { frame(5); i32 b = (i32)L[1].r2; if (b < low) low = b; CHECK(b > 0); }
    CHECK(low < 2147483647);
    hook(HOOK_BEND, 0, 0, 0x40, 0x5c, 0x2001);
    W(SEQ + 0x30) = 4; frame(5); CHECK(calls.n == 3 && L[1].kind == 5 && L[1].r1 == 7 && L[1].r2 == 0 && L[2].r1 == 4);        /* another track: the last is put straight */
    cc(0, 1, 0); frame(5); CHECK(calls.n == 2 && L[1].r1 == 4 && L[1].r2 == 0); frame(5); CHECK(calls.n == 1);
    cc(0, 1, 127); frame(50); SETTINGS = 7; frame(5); CHECK(calls.n == 2 && L[1].r2 == 0); frame(5); CHECK(calls.n == 1);
    SETTINGS = 3; frame(5); cc(0, 1, 127); W(SEQ + 0x30) = 14; frame(5); CHECK(calls.n == 1);
    W(0x81059d1c) = 0; frame(5);
    put(fails ? "FAILED\n" : "ok\n");
    return 0;
}

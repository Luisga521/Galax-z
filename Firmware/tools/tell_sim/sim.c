/* tell's own Blackfin bytes (patches/tell.json) beside the pages' (patches/pages.json), run in bfin-elf-run. Prints the messages it
 * sent ("70 ..."), FAILED lines, then "ok". */
#include "block.h"
typedef unsigned int u32; typedef int i32; typedef unsigned char u8;
u32 in[16], out[16], args[16], saved_sp, seen[4], now;
static int fails, sends;
static struct { u32 obj; i32 id, n, a, b; u8 bytes[128]; } sent[8];
extern void call_hook(void);
#define SEQ ((u8 *)0x81200000)
#define S (SEQ + 0x3463c0)
#define W(a) (*(volatile i32 *)(a))
#define B8(a) (*(volatile u8 *)(a))
static int sys(int nr, u32 *a) { register int r0 __asm__("R0") = (int)a; register int p0 __asm__("P0") = nr; __asm__ volatile("EXCPT 0;" : "+r"(r0), "+r"(p0) : : "R1", "R2", "R3", "P1", "P2", "cc", "memory"); return r0; }
static void put(const char *s) { u32 n = 0; while (s[n]) n++; u32 a[3] = { 1, (u32)s, n }; sys(5, a); }
static void num(u32 u) { char b[12]; int i = 11; b[i] = 0; do { b[--i] = '0' + u % 10; u /= 10; } while (u); put(b + i); }
static void hex(u32 v) { char b[3] = { "0123456789abcdef"[v >> 4 & 15], "0123456789abcdef"[v & 15], 0 }; put(b); }
void sim_exit(void) { u32 a[1] = { fails != 0 }; sys(1, a); }
#define CHECK(x) do { if (!(x)) { put("FAILED line "); num(__LINE__); put(": " #x "\n"); fails++; } } while (0)
void c_send(u32 obj, const u8 *p, i32 n, i32 id, i32 a, i32 b)
{
    if (sends >= 8 || n > 128) { fails++; return; }
    sent[sends].obj = obj; sent[sends].id = id; sent[sends].n = n; sent[sends].a = a; sent[sends].b = b;
    for (int i = 0; i < n; i++) sent[sends].bytes[i] = p[i];
    sends++;
}
static void tick(u32 ms)
{
    now += ms; sends = 0;
    for (int i = 0; i < 16; i++) in[i] = 0xa5000000 + i * 0x111;
    in[0] = (u32)S; in[15] = HOOK_SESSION;
    call_hook();
    CHECK(seen[3] == 1 && seen[0] == (u32)S);       /* the OS's own came first */
    for (int i = 4; i < 8; i++) CHECK(out[i] == in[i]);
    for (int i = 11; i < 15; i++) CHECK(out[i] == in[i]);
    CHECK(out[15] == 0);
}
static void show(int i) { hex(sent[i].id); put(" "); for (int k = 0; k < sent[i].n; k++) hex(sent[i].bytes[k]); put("\n"); }
typedef struct { i32 x, y, vx, vy; u8 note, flash, rest, pad; } Ball;
typedef struct { Ball ball[8]; i32 n; u32 rot; } Tumbler;
typedef struct { u8 key, steps, pulses, rot; } Ring;
typedef struct { i32 n; Ring ring[8]; i32 next, pulses; u8 pick, more, turned[2]; i32 slack[3]; } Euclid;
#define T ((volatile Tumbler *)TUMBLERS)
#define E ((volatile Euclid *)EUCLIDS)
#define D ((volatile u8 (*)[12])NOW)
typedef struct { u8 n, key[8], next, more; } Groove;
#define G ((volatile Groove *)GROOVES)
#define R ((volatile u8 (*)[8])GKNOB)

int main(void)
{
    W(0x81059d1c) = (i32)SEQ; W(0x81018320) = 0x7777; W(SEQ + 0x30) = 5; W(SEQ + 0x345e2c) = 4; W(S + 0x34) = 11; W(S + 0x38) = 22;
    for (int k = 0; k < 12; k++) D[5][k] = (u8)(k * 20);
    now = 70000;
    /* no app; TE's app; another's: nothing at all */
    W(S + 0x3c) = -1; tick(20); CHECK(sends == 0);
    W(S + 0x3c) = 0x1234; T[5].n = 3; for (int i = 0; i < 100; i++) { tick(20); CHECK(sends == 0); }
    T[5].n = 0;
    /* ours: at once, then once a second while nothing changes */
    W(S + 0x3c) = 0x4242; tick(20); CHECK(sends == 1 && sent[0].id == 0x70 && sent[0].n == 20 && sent[0].obj == 0x7777 && sent[0].a == 11 && sent[0].b == 22);
    CHECK(sent[0].bytes[0] == 1 && sent[0].bytes[1] == 4 && sent[0].bytes[2] == 5 && sent[0].bytes[3] == 0 && sent[0].bytes[8 + 3] == 60);
    int n = 0; for (int i = 0; i < 100; i++) { tick(20); n += sends; } CHECK(n == 2);
    /* a dial turning: 13 a second at the most, and the last value gets there */
    n = 0; for (int i = 0; i < 50; i++) { D[5][1] = (u8)(50 + i); tick(20); n += sends; } CHECK(n >= 10 && n <= 14);
    i32 value = -1; for (int i = 0; i < 5; i++) { tick(20); if (sends) value = sent[0].bytes[9]; } CHECK(value == 99);
    /* balls: 17 a second (every third of the 20 ms), in the app's units; one more when the last is gone */
    T[5].n = 2; T[5].rot = 0x40000000;
    T[5].ball[0].x = 1 << 23; T[5].ball[0].y = -(1 << 23); T[5].ball[0].vx = 5 << 24; T[5].ball[0].vy = -(5 << 24); T[5].ball[0].note = 60; T[5].ball[0].flash = 255;
    T[5].ball[1].x = 0x7fffffff; T[5].ball[1].y = (i32)0x80000000; T[5].ball[1].vx = 0x7fffffff; T[5].ball[1].vy = 1 << 23; T[5].ball[1].note = 67;
    T[2].n = 1;
    n = 0; int both = 0; for (int i = 0; i < 100; i++) { tick(20); for (int k = 0; k < sends; k++) n += sent[k].id == 0x71; if (sends == 2) { both++; show(0); show(1); } if (i == 99) CHECK(1); }
    CHECK(n >= 33 && n <= 34 && both >= 1);
    for (int i = 0; i < 3; i++) { tick(20); if (sends && sent[sends - 1].id == 0x71) break; }
    CHECK(sends >= 1); int k = sends - 1; CHECK(sent[k].id == 0x71 && sent[k].n == 8 + 12 && sent[k].bytes[0] == 5 && sent[k].bytes[1] == 2 && sent[k].bytes[2] == 0 && sent[k].bytes[3] == 0x40);
    u8 *q = sent[k].bytes + 8; CHECK(q[0] == 64 && q[1] == (u8)-64 && q[2] == 80 && q[3] == (u8)-80 && q[4] == 60 && q[5] == 255);
    CHECK(q[6] == 127 && q[7] == (u8)-127 && q[8] == 127 && q[9] == 8 && q[10] == 67);
    T[5].n = 0; n = 0; for (int i = 0; i < 40; i++) { tick(20); for (int j = 0; j < sends; j++) if (sent[j].id == 0x71) { n++; CHECK(sent[j].bytes[1] == 0); } } CHECK(n == 1);
    /* another track's balls are only in the mask */
    for (int i = 0; i < 100; i++) { tick(20); for (int j = 0; j < sends; j++) { CHECK(sent[j].id == 0x70 && sent[j].bytes[3] == 4); } }
    /* EUCLID: its rings, and its steps as they go */
    W(SEQ + 0x30) = 1; W(SEQ + 0x345e2c) = 5; E[1].n = 3; E[1].pick = 2; E[1].more = 1; B8(WAITING) = 1; D[1][7] = 153;      /* RATE 153: a sixteenth, 24 ticks */
    for (int i = 0; i < 3; i++) { E[1].ring[i].key = (u8)(50 + i); E[1].ring[i].steps = 16; E[1].ring[i].pulses = (u8)(4 + i); E[1].ring[i].rot = (u8)i; }
    W(BEAT) = -1; tick(100); CHECK(sends >= 1 && sent[0].id == 0x70 && sent[0].n == 32 && sent[0].bytes[4] == 2 && sent[0].bytes[5] == 3 && sent[0].bytes[6] == 2 && sent[0].bytes[7] == 3 && sent[0].bytes[20] == 50 && sent[0].bytes[31] == 2);
    show(0); B8(WAITING) = 0;
    tick(100);
    for (int i = 0; i < 40; i++) { W(BEAT) = i * 24 + 5; tick(125); int got = -1; for (int j = 0; j < sends; j++) if (sent[j].id == 0x71) got = sent[j].bytes[4] | sent[j].bytes[5] << 8; if (i) CHECK(got == i); }
    W(BEAT) = 24 * 70000; tick(125); CHECK(sends && sent[sends - 1].id == 0x71); CHECK((sent[sends - 1].bytes[4] | sent[sends - 1].bytes[5] << 8 | sent[sends - 1].bytes[6] << 16) == 70000); show(sends - 1);
    /* every RATE is one of the seven */
    for (int v = 0; v < 256; v++) { D[1][7] = (u8)v; W(BEAT) = 96 * (100 + v); tick(125); CHECK(sends); }
    /* a track with no pages, and figures that make no sense: nothing is read past its end */
    for (int t = 8; t < 16; t++) { W(SEQ + 0x30) = t; tick(125); CHECK(sends == 1 && sent[0].id == 0x70 && sent[0].n == 20 && sent[0].bytes[7] == 0); }
    W(SEQ + 0x30) = -1; tick(1100); CHECK(sends == 1 && sent[0].n == 20);
    W(SEQ + 0x30) = 1; E[1].n = 1000; T[1].n = -5; tick(1100); CHECK(sent[0].n == 20); E[1].n = 0; T[1].n = 99; tick(1100); CHECK(sent[0].n == 20); T[1].n = 8; tick(100); CHECK(sent[sends - 1].id == 0x71 && sent[sends - 1].n == 56);
    /* the red page: its dials, its step as it goes; off it with nothing kept, nothing; figures that make no sense */
    T[1].n = 0; W(SEQ + 0x30) = 4; W(SEQ + 0x345e2c) = 6; W(BEAT) = -1; tick(1100);
    { int at72 = -1; for (int j = 0; j < sends; j++) if (sent[j].id == 0x72) at72 = j; CHECK(at72 >= 0 && sent[at72].n == 12 && sent[at72].bytes[0] == 4 && sent[at72].bytes[1] == 0 && sent[at72].bytes[3] == 255 && sent[at72].bytes[4 + 1] == 153); }
    n = 0; for (int i = 0; i < 100; i++) { tick(20); for (int j = 0; j < sends; j++) n += sent[j].id == 0x72; } CHECK(n == 2);
    G[4].n = 2; G[4].key[0] = 60; G[4].key[1] = 67; G[4].more = 1; R[4][4] = 9; tick(100);
    CHECK(sends == 1 && sent[0].id == 0x72 && sent[0].n == 14 && sent[0].bytes[2] == 1 && sent[0].bytes[8] == 9 && sent[0].bytes[12] == 60 && sent[0].bytes[13] == 67); show(0);
    for (int i = 0; i < 40; i++) { W(BEAT) = i * 24 + 3; tick(60); int got = -1; for (int j = 0; j < sends; j++) if (sent[j].id == 0x72) got = sent[j].bytes[3]; CHECK(got == (i & 15)); }
    W(SEQ + 0x345e2c) = 0; W(BEAT) = 24 * 5; tick(60); n = 0; for (int j = 0; j < sends; j++) n += sent[j].id == 0x72; CHECK(n == 1);      /* another page, still playing */
    G[4].n = 0; for (int i = 0; i < 60; i++) { tick(20); for (int j = 0; j < sends; j++) CHECK(sent[j].id != 0x72); }
    G[4].n = 200; W(SEQ + 0x345e2c) = 6; tick(1100); for (int j = 0; j < sends; j++) if (sent[j].id == 0x72) CHECK(sent[j].n == 12); G[4].n = 0;
    for (int v = 0; v < 256; v++) { R[4][1] = (u8)v; G[4].n = 1; W(BEAT) = 96 * (7 + v); tick(125); CHECK(sends); } G[4].n = 0;
    W(SEQ + 0x345e2c) = 5; W(SEQ + 0x30) = 1; T[1].n = 8; tick(1100);
    /* the app goes: silence, and at its return all of it again */
    W(S + 0x3c) = -1; tick(20); CHECK(sends == 0); W(S + 0x3c) = 0x4242; tick(20); CHECK(sends >= 1 && sent[0].id == 0x70);
    W(0x81059d1c) = 0; tick(20); CHECK(sends == 0); W(0x81059d1c) = (i32)SEQ;
    u32 a, b; W(SEQ + 0x30) = 5; T[5].n = 8; __asm__ volatile("R0 = SYSCFG; BITSET(R0, 1); SYSCFG = R0; CSYNC;" : : : "R0");
    W(S + 0x3c) = -1; __asm__ volatile("%0 = CYCLES;" : "=d"(a)); tick(20); __asm__ volatile("%0 = CYCLES;" : "=d"(b)); put("cycles no app "); num(b - a); put("\n");
    W(S + 0x3c) = 0x4242; tick(1100); __asm__ volatile("%0 = CYCLES;" : "=d"(a)); tick(1100); __asm__ volatile("%0 = CYCLES;" : "=d"(b)); put("cycles most "); num(b - a); put("\n");
    put(fails ? "FAILED\n" : "ok\n");
    return 0;
}

/* The USB host's own Blackfin bytes (patches/usbhost.json) run in bfin-elf-run, against the OP-Z's descriptor records as they lie
 * in its memory: a Motif 6, a standard keyboard, others; packets; the switch. Prints FAILED lines, then "ok" or a count. */
#include "block.h"
typedef unsigned int u32; typedef int i32; typedef unsigned short u16; typedef unsigned char u8;
u32 in[16], out[16], args[16], saved_sp, seen[9], now, light[6], offs[1100], ons[1100];
i32 parse_result, start_result;
static int fails, no_memory, allocs;
extern void call_hook(void);
#define SEQ ((u8 *)0x81200000)
#define W(a) (*(volatile i32 *)(a))
static int sys(int nr, u32 *a) { register int r0 __asm__("R0") = (int)a; register int p0 __asm__("P0") = nr; __asm__ volatile("EXCPT 0;" : "+r"(r0), "+r"(p0) : : "R1", "R2", "R3", "P1", "P2", "cc", "memory"); return r0; }
static void put(const char *s) { u32 n = 0; while (s[n]) n++; u32 a[3] = { 1, (u32)s, n }; sys(5, a); }
static void num(i32 v) { char b[12]; int i = 11; b[i] = 0; u32 u = v; do { b[--i] = '0' + u % 10; u /= 10; } while (u); put(b + i); }
void sim_exit(void) { u32 a[1] = { fails != 0 }; sys(1, a); }
#define CHECK(x) do { if (!(x)) { put("FAILED line "); num(__LINE__); put(": " #x "\n"); fails++; } } while (0)
static u8 heap[4096];
u8 *alloc(i32 n) { if (no_memory) return 0; u8 *p = heap + allocs++ * 64; for (int i = 0; i < 64; i++) p[i] = i < n ? 0xee : 0x77; return p; }
static void hook(u32 target, u32 r0, u32 r1, u32 r2)
{
    for (int i = 0; i < 9; i++) seen[i] = 0;
    for (int i = 0; i < 16; i++) in[i] = 0xa5000000 + i * 0x111;
    in[0] = r0; in[1] = r1; in[2] = r2; in[15] = target;
    call_hook();
    for (int i = 4; i < 8; i++) CHECK(out[i] == in[i]);
    for (int i = 11; i < 15; i++) CHECK(out[i] == in[i]);
    CHECK(out[15] == 0);
}

/* a device as the OP-Z keeps it */
static u8 dev[0x100] __attribute__((aligned(4))), cfg[0x40] __attribute__((aligned(4))), ifs[0x18 * 4] __attribute__((aligned(4))), alts[0x18 * 4] __attribute__((aligned(4))), eps[0x10 * 8] __attribute__((aligned(4))), was[0x18 * 4];
/* a Motif 6, as the Mac reads it */
static const u8 motif_jacks[] = { 7, 0x24, 1, 0, 1, 0xf7, 0,  6, 0x24, 2, 1, 1, 0,  6, 0x24, 2, 1, 2, 0,  6, 0x24, 2, 1, 3, 0,  9, 0x24, 3, 1, 1, 1, 1, 1, 0,  9, 0x24, 3, 1, 2, 1, 1, 1, 0,
    9, 0x24, 3, 1, 3, 1, 1, 1, 0,  9, 0x24, 3, 1, 4, 1, 1, 1, 0,  9, 0x24, 3, 1, 5, 1, 1, 1, 0,  9, 0x24, 3, 1, 6, 1, 1, 1, 0,  9, 0x24, 3, 1, 7, 1, 1, 1, 0,  9, 0x24, 3, 1, 8, 1, 1, 1, 0 };
static const u8 bare_jacks[] = { 4, 0x24, 2, 1,  4, 0x24, 3, 1 };
static const u8 general[] = { 5, 0x25, 1, 1, 1 };
static const u8 roland[] = { 6, 0x24, 0xf1, 2, 1, 1 };
static const u8 liar[] = { 0, 0x24, 2, 1, 1, 1 }, over[] = { 200, 0x24, 2, 1 };
static void device(u32 vendor, u32 product, u32 cls, u32 sub, int neps, const u8 *extra, int n, const u8 *ep_extra, int en)
{
    for (u32 i = 0; i < sizeof dev; i++) dev[i] = 0;
    for (u32 i = 0; i < sizeof alts; i++) alts[i] = ifs[i % sizeof ifs] = 0;
    for (u32 i = 0; i < sizeof eps; i++) eps[i] = 0;
    W(dev + 0x74) = (i32)cfg; *(u16 *)(dev + 0x64) = vendor; *(u16 *)(dev + 0x66) = product;
    cfg[4] = 2; W(cfg + 0xc) = (i32)ifs;
    u8 *f = ifs + 0x18; W(f) = (i32)alts; W(f + 8) = 2;                     /* interface 1, two settings */
    for (int a = 0; a < 2; a++) { u8 *t = alts + a * 0x18; t[0] = 9; t[1] = 4; t[2] = 1; t[3] = a; t[4] = neps; t[5] = cls; t[6] = sub; t[7] = 0xff; W(t + 0xc) = (i32)(eps + a * 0x40); W(t + 0x10) = (i32)extra; W(t + 0x14) = n; }
    for (int a = 0; a < 2; a++) for (int e = 0; e < neps; e++) { u8 *t = eps + a * 0x40 + e * 0x10; t[0] = 7; t[1] = 5; t[2] = e & 1 ? 0x82 : 1; t[3] = 2; t[4] = 64; W(t + 8) = (i32)ep_extra; W(t + 0xc) = en; }
    for (u32 i = 0; i < sizeof alts; i++) was[i] = alts[i];
}
static int adopted(u32 number)
{
    hook(HOOK_ADOPT, (u32)dev, number, 0x33);
    CHECK(seen[3] == 1 && seen[0] == (u32)dev && seen[1] == number);
    int same = 1; for (u32 i = 0; i < sizeof alts; i++) same &= alts[i] == was[i];
    if (same) return 0;
    for (int a = 0; a < 2; a++) CHECK(alts[a * 0x18 + 5] == 1 && alts[a * 0x18 + 6] == 3 && alts[a * 0x18 + 7] == 0 && W(alts + a * 0x18 + 0x14) == 0 && alts[a * 0x18 + 4] == 2);
    CHECK(W(eps + 0xc) == 0 && W(eps + 0x1c) == 0 && eps[2] == 1 && eps[0x12] == 0x82);
    return 1;
}

int main(void)
{
    W(0x81059d1c) = (i32)SEQ;

    /* the Motif 6: vendor specific, jacks, two bulk endpoints, nothing after them; its sisters; other makers */
    device(0x0499, 0x1005, 0xff, 0, 2, motif_jacks, sizeof motif_jacks, 0, 0); CHECK(!adopted(0)); CHECK(adopted(1));
    device(0x0499, 0x1021, 0xff, 0xff, 2, bare_jacks, sizeof bare_jacks, 0, 0); CHECK(adopted(1));
    device(0x0582, 0x0012, 0xff, 3, 2, roland, sizeof roland, 0, 0); CHECK(adopted(1));
    device(0x1234, 0x0001, 0xff, 3, 2, 0, 0, general, sizeof general); CHECK(adopted(1));
    /* not these: a standard keyboard, another class, another maker's vendor interface, no jacks, one way only, made-up lengths */
    device(0x0499, 0x1005, 1, 3, 2, motif_jacks, sizeof motif_jacks, general, sizeof general); CHECK(!adopted(1)); CHECK(W(alts + 0x14) == sizeof motif_jacks && W(eps + 0xc) == sizeof general);
    device(0x0499, 0x1005, 8, 0, 2, motif_jacks, sizeof motif_jacks, 0, 0); CHECK(!adopted(1));
    device(0x0403, 0x6001, 0xff, 0xff, 2, 0, 0, 0, 0); CHECK(!adopted(1));
    device(0x1234, 0x1005, 0xff, 0, 2, motif_jacks, sizeof motif_jacks, 0, 0); CHECK(!adopted(1));
    device(0x0499, 0x1005, 0xff, 0, 2, 0, 0, 0, 0); CHECK(!adopted(1));
    device(0x0499, 0x1005, 0xff, 0, 1, motif_jacks, sizeof motif_jacks, 0, 0); CHECK(!adopted(1));
    device(0x0499, 0x1005, 0xff, 0, 2, liar, sizeof liar, 0, 0); CHECK(!adopted(1));
    device(0x0499, 0x1005, 0xff, 0, 2, over, sizeof over, 0, 0); CHECK(!adopted(1));
    device(0x0499, 0x1005, 0xff, 0, 2, motif_jacks, sizeof motif_jacks, 0, 0); eps[3] = eps[0x13] = eps[0x43] = eps[0x53] = 1; CHECK(!adopted(1));      /* isochronous */
    device(0x0499, 0x1005, 0xff, 0, 2, motif_jacks, sizeof motif_jacks, 0, 0); W(dev + 0x74) = 0; CHECK(!adopted(1));
    device(0x0499, 0x1005, 0xff, 0, 2, motif_jacks, sizeof motif_jacks, 0, 0); CHECK(!adopted(2)); CHECK(!adopted(0xffffffff)); W(ifs + 0x18) = 0; CHECK(!adopted(1));
    hook(HOOK_ADOPT, 0, 1, 0); CHECK(seen[3] == 1);

    /* endpoints with no port count get one the OS can free; those with one keep it */
    static u8 audio[0x100] __attribute__((aligned(4))), midi[0x130] __attribute__((aligned(4)));
    W(audio + 0x60) = (i32)midi; W(midi + 0x104) = (i32)eps; W(midi + 0x10c) = (i32)(eps + 0x10);
    hook(HOOK_ENDPOINTS, (u32)audio, 0, 0); CHECK(seen[3] == 4 && seen[0] == (u32)audio && out[0] == 0 && allocs == 2);
    u8 *g = (u8 *)W(midi + 0x108); CHECK(g == heap && g[3] == 16 && g[1] == 0x25 && g[0x14] == 0x77 && W(midi + 0x110) == (i32)heap + 64);
    hook(HOOK_ENDPOINTS, (u32)audio, 0, 0); CHECK(allocs == 2 && out[0] == 0);
    W(midi + 0x108) = 0; no_memory = 1; hook(HOOK_ENDPOINTS, (u32)audio, 0, 0); CHECK((i32)out[0] == -1); no_memory = 0;
    parse_result = -1; W(midi + 0x108) = 0; hook(HOOK_ENDPOINTS, (u32)audio, 0, 0); CHECK((i32)out[0] == -1 && allocs == 2); parse_result = 0;
    W(audio + 0x60) = 0; hook(HOOK_ENDPOINTS, (u32)audio, 0, 0); CHECK(out[0] == 0);

    /* packets */
    hook(HOOK_NEW, (u32)dev, 0, 0);
    static u8 p[64] __attribute__((aligned(4))) = { 9, 0x90, 60, 100, 0x19, 0x90, 61, 100, 0, 0, 0, 0, 8, 0x80, 60, 0, 0xf, 0xfe, 0, 0, 0x2f, 1, 2, 3, 1, 1, 1, 1 };
    hook(HOOK_TIDY, 0x7777, (u32)p, 28); CHECK(seen[3] == 2 && seen[0] == 0x7777 && seen[1] == (u32)p && seen[2] == 12 && p[0] == 9 && p[2] == 60 && p[4] == 8 && p[5] == 0x80 && p[8] == 0xf && p[9] == 0xfe);
    hook(HOOK_TIDY, 1, (u32)p, 12); CHECK(seen[2] == 12); hook(HOOK_TIDY, 1, (u32)p, 7); CHECK(seen[2] == 7); hook(HOOK_TIDY, 1, (u32)p, 0); CHECK(seen[2] == 0);
    for (int i = 0; i < 64; i++) p[i] = 0;
    hook(HOOK_TIDY, 1, (u32)p, 64); CHECK(seen[2] == 0);
    static const u8 sysex[] = { 4, 0xf0, 0x43, 0x10, 4, 1, 2, 3, 7, 4, 5, 0xf7 };
    for (int i = 0; i < 12; i++) p[i] = sysex[i];
    hook(HOOK_TIDY, 1, (u32)p, 12); CHECK(seen[2] == 12); for (int i = 0; i < 12; i++) CHECK(p[i] == sysex[i]);

    /* SHIFT, then PROJECT */
    u8 *settings = (u8 *)0x819c2bb4;
#define KEY(control, value) do { hook(HOOK_KEY, (u32)SEQ, control, value); } while (0)
#define THEIRS(control, value) do { KEY(control, value); CHECK(seen[3] == 3 && seen[0] == (u32)SEQ && seen[1] == (u32)(control) && seen[2] == (u32)(value)); } while (0)
#define OURS(control, value) do { KEY(control, value); CHECK(seen[3] == 0); } while (0)
    W(0x81015e9c) = 0x1234; *settings = 0xfc;                                  /* all but channel 1 to the selected track, and incoming */
    W(SEQ + 0x68c) = 2; SEQ[0x114 + 0x10] = 5; SEQ[0x114 + 0x12] = 64; SEQ[0x114 + 0x1c + 0x10] = 7; SEQ[0x114 + 0x1c + 0x12] = 67;
    for (int c = 0; c < 50; c++) { THEIRS(c, -1); THEIRS(c, 0); THEIRS(c, 1); }
    SEQ[0x22] = 1; for (int c = 0; c < 50; c++) { if (c != 5 && c != 6) THEIRS(c, -1); THEIRS(c, 0); THEIRS(c, 1); }
    CHECK(*settings == 0xfc && light[5] == 0);
    OURS(5, -1); CHECK(*settings == ((0xfc & ~(4 | 16 | 64)) | 3) && light[5] == 1 && light[0] == 0x1234 && light[1] == 3 && light[2] == 600 && light[3] == 0 && light[4] == 0x2f);
    CHECK(offs[0] == 2 && offs[1] == (5 | 64 << 8) && offs[2] == (7 | 67 << 8));
    THEIRS(5, 0); *settings ^= 0x20;
    OURS(5, -1); CHECK(*settings == (0xfc ^ 0x20) && light[5] == 2 && light[4] == 0x1f && offs[0] == 2);    /* what else was set meanwhile stays */
    SEQ[0x22] = 0; THEIRS(5, -1); CHECK(light[5] == 2);
    SEQ[0x22] = 1; W(SEQ + 0x68c) = 9999; SEQ[0x114 + 0x10] = 200; OURS(5, -1); CHECK(light[5] == 3 && offs[0] < 2 + 51);
    hook(HOOK_KEY, 0, 5, -1); CHECK(seen[3] == 3);
    /* ours is heard on every port */
    device(0x0499, 0x1005, 0xff, 0, 2, motif_jacks, sizeof motif_jacks, 0, 0); CHECK(adopted(1));
    static const u8 ports[8] = { 0x19, 0x90, 60, 1, 0x28, 0x80, 60, 0 };
    for (int i = 0; i < 8; i++) p[i] = ports[i];
    hook(HOOK_TIDY, 1, (u32)p, 8); CHECK(seen[2] == 8 && p[0] == 9 && p[4] == 8);

    /* what happened, and its telling */
    static u8 message[16] __attribute__((aligned(4))); message[12] = 1; message[13] = 2; message[14] = 0x22; message[15] = 4;
    for (int i = 0; i < 9; i++) { message[15] = i; hook(HOOK_ROLE, 0x88, (u32)message, 0); CHECK(seen[3] == 5 && seen[0] == 0x88 && seen[1] == (u32)message); }
    static u8 raw[300]; static u32 raws[1]; raws[0] = (u32)raw; for (int i = 0; i < 300; i++) raw[i] = i;
    device(0x0499, 0x1005, 0xff, 0, 2, motif_jacks, sizeof motif_jacks, 0, 0); W(dev + 0x78) = (i32)raws; *(u16 *)(cfg + 2) = 300; dev[0x5c] = 18;
    start_result = -1; hook(HOOK_NEW, (u32)dev, 0, 0); CHECK(seen[3] == 6 && seen[0] == (u32)dev && (i32)out[0] == -1);
    start_result = 0; hook(HOOK_NEW, (u32)dev, 0, 0); CHECK(out[0] == 0);
    u8 *r = (u8 *)REPORT_AT;
    CHECK(r[0] == 'G' && r[4] == 9 && r[5] == 3 && r[16 + 2] == 0x22 && r[16 + 3] == 8 && r[48] == 0 && r[52] == 18 && r[52 + 8] == 0x99 && r[52 + 9] == 4 && r[70] == 300 % 256 && r[72 + 255] == 255);
    for (int i = 0; i < 8; i++) p[i] = ports[i];
    hook(HOOK_TIDY, 1, (u32)p, 8); CHECK(r[12] == 1 && r[14] == 8 && r[328] == 0x19 && r[332] == 0x28);
    for (int k = 0; k < 20; k++) { for (int i = 0; i < 64; i++) p[i] = 9; hook(HOOK_TIDY, 1, (u32)p, 64); }
    CHECK(r[12] == 21 && r[328] == 0x19);
    hook(HOOK_FRAME, 0x55, 0, 0); CHECK(seen[3] == 7 && seen[0] == 0x55 && ons[0] == 0);
    SEQ[0x22] = 1; OURS(6, -1); offs[0] = 0;
    for (int i = 0; i < 1000; i++) hook(HOOK_FRAME, 0x55, 0, 0);
    CHECK(ons[0] == REPORT_SIZE * 2 && offs[0] == REPORT_SIZE * 2);
    u32 sum = 0, good = 1; for (int i = 0; i < REPORT_SIZE; i++) { u32 a = ons[1 + i * 2], b = ons[2 + i * 2]; u32 v = ((a >> 16) - 1) << 4 | ((b >> 16) - 1); good &= (a & 0xff) == 0 && (a >> 8 & 0xff) == 24u + ((i * 2) & 63) && v == r[i]; if (i < REPORT_SIZE - 1) sum += v; else good &= (sum & 255) == v; }
    CHECK(good);
    put(fails ? "FAILED\n" : "ok\n");
    return 0;
}

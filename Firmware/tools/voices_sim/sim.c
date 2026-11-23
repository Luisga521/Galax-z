/* The voices' own Blackfin bytes (patches/voices.json) run in bfin-elf-run. Prints FAILED lines, then "ok". */
#include "block.h"
typedef unsigned int u32; typedef int i32; typedef unsigned char u8;
u32 in[16], out[16], args[16], saved_sp, killed[100], kills;
static int fails;
extern void call_hook(void);
#define REC 0x17c
#define MGR 0x0800452cu
#define LIVE ((u8 *)VOICE_RECORDS_AT)
static u8 pattern[44 * REC] __attribute__((aligned(4)));
static u32 frame[32];
static int sys(int nr, u32 *a) { register int r0 __asm__("R0") = (int)a; register int p0 __asm__("P0") = nr; __asm__ volatile("EXCPT 0;" : "+r"(r0), "+r"(p0) : : "R1", "R2", "R3", "P1", "P2", "cc", "memory"); return r0; }
static void put(const char *s) { u32 n = 0; while (s[n]) n++; u32 a[3] = { 1, (u32)s, n }; sys(5, a); }
static void num(u32 u) { char b[12]; int i = 11; b[i] = 0; do { b[--i] = '0' + u % 10; u /= 10; } while (u); put(b + i); }
void sim_exit(void) { u32 a[1] = { fails != 0 }; sys(1, a); }
#define CHECK(x) do { if (!(x)) { put("FAILED line "); num(__LINE__); put(": " #x "\n"); fails++; } } while (0)
static void hook(u32 target, u32 r0, u32 r1, u32 r2, int all)
{
    for (int i = 0; i < 16; i++) in[i] = 0xa5000000 + i * 0x111;
    in[0] = r0; in[1] = r1; in[2] = r2; in[15] = target; in[14] = (u32)(frame + 16);
    call_hook();
    for (int i = all ? 2 : 4; i < 8; i++) CHECK(out[i] == in[i]);
    for (int i = all ? 10 : 11; i < 15; i++) CHECK(out[i] == in[i]);
    CHECK(out[15] == 0);
}
static u32 start(u32 t, u32 l) { hook(HOOK_START, 1, t, l, 1); return out[0]; }
static u32 end(u32 t, u32 l) { hook(HOOK_END, 1, t, l, 1); return out[0]; }
static u32 memory(u32 number) { hook(HOOK_MEMORY, 7, 0x1111, number << 13, 1); CHECK(out[1] == 0x1111); return out[0] + out[2]; }
static void set(u8 *r, u32 track, i32 stage, i32 level, u32 age) { r[0x10] = track; *(i32 *)(r + 0x40) = stage; *(i32 *)(r + 0x34) = level; *(u32 *)(r + 0x18) = age; }
static void overload(u32 cycles) { kills = 0; frame[16 - 8] = cycles; hook(HOOK_OVERLOAD, (u32)pattern, 0, 0, 0); }

int main(void)
{
    /* layer 0 is the OS's 22 in its order; layer 1 is 40 of ours, one after the other */
    static const u8 first[8] = { 0, 2, 4, 6, 8, 10, 14, 16 }, n0[8] = { 2, 2, 2, 2, 2, 4, 2, 6 }, n1[8] = { 2, 2, 2, 2, 6, 10, 6, 10 };
    u32 at = (VOICE_RECORDS_AT - MGR) / REC, got = 0;
    CHECK((VOICE_RECORDS_AT - MGR) % REC == 0);
    for (u32 t = 0; t < 8; t++) {
        CHECK(start(t, 0) == first[t] && end(t, 0) == first[t] + n0[t]);
        CHECK(start(t, 1) == at + got && end(t, 1) == at + got + n1[t]);
        for (u32 i = start(t, 1); i < end(t, 1); i++, got++) {
            CHECK(MGR + (u32)((i32)i * (i32)REC) == (u32)(LIVE + got * REC));
            CHECK(memory(i) == 0x80cd0000u + got * 8192);
        }
    }
    CHECK(got == 40);
    for (u32 i = 0; i < 44; i++) CHECK(memory(i) == 0x8156fab8u + i * 8192);

    /* what a record is after the OS's constructor */
    for (u32 i = 0; i < 40; i++) for (u32 k = 0; k < REC; k++) CHECK(LIVE[i * REC + k] == (k == 0x10 || k == 0x25 ? 0xff : k == 0x28 ? 0x10 : 0));
    for (u32 i = 0; i < 44; i++) pattern[i * REC + 0x10] = 0xff;

    /* nothing sounds: nothing is cut */
    overload(500000); CHECK(kills == 0); hook(HOOK_OFF, (u32)pattern, 0, 0, 0); CHECK(kills == 0);
    /* held notes are not, up to 340,000; then the oldest live one, never a pattern's */
    set(pattern, 0, 3, 5, 99999); set(LIVE + 20 * REC, 5, 3, 1000, 50); set(LIVE + 39 * REC, 7, 2, 500, 70); set(LIVE + 38 * REC, 7, 1, 0, 2);
    overload(340000); CHECK(kills == 0);
    overload(340001); CHECK(kills == 1 && killed[0] == (u32)(LIVE + 39 * REC));
    /* it fades: it is the one again, as the OS has it; then the quietest of what fades, in either layer, by size */
    overload(340001); CHECK(kills == 1 && killed[0] == (u32)(LIVE + 39 * REC));
    set(LIVE + 39 * REC, 7, 5, -500, 70); set(pattern + 21 * REC, 7, 4, 400, 3); overload(270000); CHECK(kills == 1 && killed[0] == (u32)(pattern + 21 * REC));
    set(LIVE + 1 * REC, 0, 4, -399, 3); overload(270000); CHECK(kills == 1 && killed[0] == (u32)(LIVE + 1 * REC));
    set(LIVE + 1 * REC, 0, 4, (i32)0x80000000, 3); overload(270000); CHECK(killed[0] == (u32)(pattern + 21 * REC));
    LIVE[1 * REC + 0x10] = 0xff; set(LIVE + 1 * REC, 0xff, 4, 1, 3); overload(270000); CHECK(killed[0] == (u32)(pattern + 21 * REC));
    /* all off: each that sounds, once */
    kills = 0; hook(HOOK_OFF, (u32)pattern, 0, 0, 0); CHECK(kills == 5 && killed[0] == (u32)pattern && killed[1] == (u32)(pattern + 21 * REC) && killed[4] == (u32)(LIVE + 39 * REC));
    /* no note at all is the same as before: no write outside the records */
    put(fails ? "FAILED\n" : "ok\n");
    return 0;
}

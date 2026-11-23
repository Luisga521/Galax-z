/* The chime's own Blackfin bytes (patches/chime.json) in bfin-elf-run: every register, every sample of the first 1.7 s beside the C on the
 * Mac (a sum a block, printed), the guard words round the mix, and how many blocks it took. */
#include "block.h"
typedef unsigned int u32; typedef int i32;
u32 in[16], out[16], args[16], saved_sp, seen[4];
static int fails;
extern void call_hook(void);
static int sys(int nr, u32 *a) { register int r0 __asm__("R0") = (int)a; register int p0 __asm__("P0") = nr; __asm__ volatile("EXCPT 0;" : "+r"(r0), "+r"(p0) : : "R1", "R2", "R3", "P1", "P2", "cc", "memory"); return r0; }
static void put(const char *s) { u32 n = 0; while (s[n]) n++; u32 a[3] = { 1, (u32)s, n }; sys(5, a); }
static void num(u32 u) { char b[12]; int i = 11; b[i] = 0; do { b[--i] = '0' + u % 10; u /= 10; } while (u); put(b + i); }
void sim_exit(void) { u32 a[1] = { fails != 0 }; sys(1, a); }
#define CHECK(x) do { if (!(x)) { put("FAILED line "); num(__LINE__); put(": " #x "\n"); fails++; } } while (0)
static i32 mix[16 + 128 + 16];
int main(void)
{
    for (u32 i = 0; i < 16; i++) args[i] = 0x7000 + i;
    for (int block = -20; block < 1200; block++) {
        if (!block) {                                          /* where TE's start sound would be: every register kept, TE's not played */
            for (int i = 0; i < 16; i++) in[i] = 0xa5000000 + i * 0x111;
            in[0] = 0x0802ee3c; in[2] = 50; in[15] = HOOK_START; seen[3] = 0;
            call_hook();
            CHECK(seen[3] == 0 && out[15] == 0);
            for (int i = 4; i < 8; i++) CHECK(out[i] == in[i]);
            for (int i = 11; i < 15; i++) CHECK(out[i] == in[i]);
        }
        for (int i = 0; i < 160; i++) mix[i] = i < 16 || i >= 144 ? 0x5a5a0000 + i : (i * 7919 + block) << 8;
        for (int i = 0; i < 16; i++) in[i] = 0xa5000000 + i * 0x111;
        in[0] = 0x0802ee5c; in[1] = (u32)(mix + 16); in[2] = 1; in[15] = HOOK_MIX; seen[3] = 0;
        call_hook();
        CHECK(seen[3] == 1 && seen[0] == 0x0802ee5c && seen[1] == (u32)(mix + 16));
        for (int i = 4; i < 8; i++) CHECK(out[i] == in[i]);
        for (int i = 11; i < 15; i++) CHECK(out[i] == in[i]);
        CHECK(out[15] == 0);
        for (int i = 0; i < 16; i++) CHECK(mix[i] == 0x5a5a0000 + i && mix[144 + i] == 0x5a5a0000 + 144 + i);
        u32 sum = 0; int changed = 0;
        for (int i = 0; i < 128; i++) { sum = sum * 31 + (u32)mix[16 + i]; changed += mix[16 + i] != ((i + 16) * 7919 + block) << 8; }
        if (block < 0) { CHECK(!changed); continue; }           /* not started: nothing */
        if (block % 25 == 0 || changed) { put("b "); num(block); put(" "); num(sum); put(" "); num(changed); put("\n"); }
        if (fails > 5) break;
    }
    put(fails ? "FAILED\n" : "ok\n");
    return 0;
}

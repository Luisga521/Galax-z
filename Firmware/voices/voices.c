/* Galax-z voices: more notes at once, live.
 *
 * The OS has 22 voice records a layer (0: the pattern, 1: what is played live), 44 in a row from 0x0800452c, 0x17c bytes each with the
 * engine's state in them, and 8 KB of an engine's own memory each from 0x8156fab8, by number. A record is only ever reached as
 * base + number x 0x17c, the numbers from getVoiceStart/EndIndex. Those two are ours now (voices.S): layer 0 keeps its 22 (lead 4, chord 6 of them), layer 1
 * gets 40 of its own here: 2 a drum track, bass 6, lead 10, arp 6, chord 10. Its first number is so large that base + number x 0x17c lands in
 * this block (32-bit arithmetic). Nothing is added to what the OS does for a voice.
 *
 * The OS's two loops over all 44 are done here instead: all notes off, and the overload's choice of a note to cut. New in the latter: when nothing
 * is fading and the instruments took more than 340,000 cycles, the oldest note played live is let go, so that held keys cannot starve the OS. */
typedef unsigned char u8; typedef int i32; typedef unsigned int u32;

#define RECORD 0x17c
#define PATTERN 22
#define LIVE 40
#define TOO_MUCH 340000u

extern u8 voice_records[LIVE][RECORD];

static void kill(u8 *record) { ((void (*)(u8 *))0x8012dfae)(record); }

/* all notes off: 0x8012d10c; mgr = the first record */
void voices_off(u8 *mgr)
{
    for (u32 i = 0; i < PATTERN; i++) if (mgr[i * RECORD + 0x10] != 0xff) kill(mgr + i * RECORD);
    for (u32 i = 0; i < LIVE; i++) if (voice_records[i][0x10] != 0xff) kill(voice_records[i]);
}

/* the quietest of n records whose note is past its held part */
static void quietest(u8 *r, u32 n, u8 **best, i32 *least)
{
    for (; n; n--, r += RECORD) {
        if (r[0x10] == 0xff || *(i32 *)(r + 0x40) < 4) continue;
        i32 level = *(i32 *)(r + 0x34);
        if (level < 0) level = level == (i32)0x80000000 ? 0x7fffffff : -level;
        if (level < *least) { *least = level; *best = r; }
    }
}

/* 0x8012d142: the instruments took too long (in the audio interrupt) */
void voices_overload(u8 *mgr, u32 cycles)
{
    u8 *best = 0;
    i32 least = 0x7fffffff;
    quietest(mgr, PATTERN, &best, &least);
    quietest(voice_records[0], LIVE, &best, &least);
    if (!best && cycles > TOO_MUCH) {
        u32 oldest = 0;                             /* + 0x18: the blocks it has sounded; every voice's is raised as it renders */
        for (u32 i = 0; i < LIVE; i++) {
            u8 *r = voice_records[i];
            if (r[0x10] != 0xff && *(i32 *)(r + 0x40) >= 1 && *(u32 *)(r + 0x18) > oldest) { oldest = *(u32 *)(r + 0x18); best = r; }
        }
    }
    if (best) kill(best);
}

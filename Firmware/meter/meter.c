/* Galax-z meter: how hard the OP-Z works, measured by the OP-Z itself.
 *
 * SHIFT held, then TEMPO (the third key on the top): the step row and the dials show it; again: off.
 *  - The step row is the instruments' time of the OS's limit for it (265,000 cycles of each block of 64 samples; above that it
 *    starts to cut off fading notes): the bar is the average of the last tenth of a second, green, orange from 10, red from 13; the
 *    white step the highest block of the last second and a half. All red: notes were cut off.
 *  - The dials are the whole of the audio work (effects, tape, master too) of the time there is (580,499 cycles a block), a quarter
 *    each. What is left is for everything else: sequencer, keys, LEDs, USB.
 * SHIFT held, then SCREEN (the fourth): the figures since the meter was switched on go out as notes, a nibble each
 * (tools/load_report.py reads them on the Mac; HOST mode).
 *
 * meter_block (meter.S) runs in the audio interrupt and only adds up; the rest is in the UI/sequencer task.
 * Compiled by tools/meter_build.py. */

typedef signed int i32;
typedef unsigned int u32;
typedef unsigned char u8;

static inline u8 *os_seq(void) { return *(u8 *volatile *)0x81059d1c; }
static inline u32 os_ms(void) { return ((u32(*)(void))0x80028294)(); }
static inline void os_led(i32 led, i32 r, i32 g, i32 b, i32 w) { ((void (*)(i32, i32, i32, i32, i32))0x8003d3be)(led, r, g, b, w); }
static inline void os_note_on(i32 track, i32 note, i32 vel)
{
    ((void (*)(i32, i32, i32, i32, i32, i32, i32))0x80042140)(track, note, vel, -1, 0x2000, 1, ((u8 *)0x819c2a94)[track]);
}
static inline void os_note_off(i32 track, i32 note)
{
    ((void (*)(i32, i32, i32, i32, i32, i32))0x800421b8)(track, note, -1, 0x2000, 1, ((u8 *)0x819c2a94)[track]);
}
#define STATE __attribute__((section(".data")))
#define SEQ_SHIFT_KEY 0x22
#define SEQ_SOUNDING 0x68c
#define SEQ_STEPS 0x346260
#define SEQ_SCREEN 0x3463bc
#define SCREEN 48
#define TEMPO 49
#define PRESSED -1
#define LINE 265000                     /* the OS's line for the instruments, cycles a block */
#define BLOCK 580499                    /* a block: 64 samples at 44.1 kHz, 400 MHz */

/* the audio interrupt's side; meter.S knows the order */
typedef struct { u32 sum, n, top; } Sum;
Sum STATE meter_stage = { 0 }, STATE meter_total = { 0 };
u32 STATE meter_kills = 0;

typedef struct {
    u8 magic[4];                        /* GZL1 */
    u32 tenths;                         /* since the meter was switched on */
    u32 stage_mean, stage_top, total_mean, total_top;       /* cycles a block */
    u32 kills, voices_top, gap_top;     /* notes cut off; most notes at once; longest wait for a UI frame, ms */
    u8 end[3], sum;
} Report;
Report STATE report = { .magic = { 'G', 'Z', 'L', '1' } };

static u8 STATE on = 0;
static u32 STATE last_ms = 0, STATE frame_ms = 0, STATE top_ms = 0, STATE kill_ms = 0, STATE kills_seen = 0;
static u32 STATE stage = 0, STATE stage_top = 0, STATE total = 0;       /* as shown */
static u32 STATE stage_acc = 0, STATE total_acc = 0;                    /* the means', of `acc_n` tenths */
static u32 STATE acc_n = 0;
static i32 STATE telling = -1;

static u32 divide(u32 n, u32 d)
{
    u32 q = 0, r = 0;
    for (i32 i = 31; i >= 0; i--) {
        r = r << 1 | (n >> i & 1);
        q <<= 1;
        if (r >= d) { r -= d; q |= 1; }
    }
    return q;
}

static Sum take(Sum *from)              /* and start again: the interrupt adds to it, so it is kept out for a moment */
{
    Sum s;
    u32 mask;
    __asm__ volatile("CLI %0;" : "=d"(mask));
    s = *(volatile Sum *)from;
    ((volatile Sum *)from)->sum = ((volatile Sum *)from)->n = ((volatile Sum *)from)->top = 0;
    __asm__ volatile("STI %0;" : : "d"(mask));
    return s;
}

static void start(void)
{
    take(&meter_stage); take(&meter_total);
    stage = stage_top = total = stage_acc = total_acc = acc_n = 0;
    report.tenths = report.stage_mean = report.stage_top = report.total_mean = report.total_top = report.voices_top = report.gap_top = 0;
    report.kills = 0;
    kills_seen = meter_kills;
    last_ms = frame_ms = top_ms = os_ms();
    kill_ms = last_ms - 10000;
}

static void measure(const u8 *seq, u32 ms)
{
    u32 gap = ms - frame_ms;
    frame_ms = ms;
    if (gap > report.gap_top) report.gap_top = gap;
    u32 voices = *(const u32 *)(seq + SEQ_SOUNDING);
    if (voices > report.voices_top && voices < 1000) report.voices_top = voices;
    u32 kills = meter_kills;
    if (kills != kills_seen) { report.kills += kills - kills_seen; kills_seen = kills; kill_ms = ms; }
    if (ms - last_ms < 100) return;
    last_ms = ms;
    Sum s = take(&meter_stage), t = take(&meter_total);
    if (!t.n || t.n > 100000) return;
    total = divide(t.sum, t.n);
    stage = s.n ? divide(s.sum, s.n) : 0;
    if (s.top >= stage_top || ms - top_ms > 1500) { stage_top = s.top; top_ms = ms; }
    if (s.top > report.stage_top) report.stage_top = s.top;
    if (t.top > report.total_top) report.total_top = t.top;
    report.tenths++;
    stage_acc += stage; total_acc += total; acc_n++;
    if (acc_n >= 4096) { stage_acc >>= 1; total_acc >>= 1; acc_n >>= 1; }       /* ~7 minutes: the older half counts half */
    report.stage_mean = divide(stage_acc, acc_n);
    report.total_mean = divide(total_acc, acc_n);
}

static u32 sixteenths(u32 cycles) { u32 v = divide(cycles * 16, LINE); return v > 15 ? 15 : v; }

static void show(const u8 *seq, u32 ms)
{
    if (*(const i32 *)(seq + SEQ_SCREEN) == (i32)(seq + SEQ_STEPS)) {
        i32 cut = ms - kill_ms < 400;
        u32 bar = divide(stage * 16 + LINE / 2, LINE), peak = sixteenths(stage_top);
        for (u32 i = 0; i < 16; i++) {
            if (cut) os_led((i32)i, 255, 0, 0, 0);
            else if (i == peak && stage_top) os_led((i32)i, 8, 8, 8, 200);      /* not pure white: the A/B bars have been already */
            else if (i >= bar) os_led((i32)i, 0, 0, 0, 0);
            else if (i < 10) os_led((i32)i, 0, 160, 0, 0);
            else if (i < 13) os_led((i32)i, 140, 160, 0, 0);
            else os_led((i32)i, 255, 0, 0, 0);
        }
    }
    u32 quarter = BLOCK / 4;
    for (u32 d = 0; d < 4; d++) {
        u32 from = d * quarter, v = total <= from ? 0 : total - from >= quarter ? 255 : divide((total - from) * 255, quarter);
        os_led((i32)(40 + d), d == 3 ? (i32)v : d == 2 ? (i32)(v >> 1) : 0, d == 3 ? 0 : (i32)v, 0, 0);
    }
}

void meter_frame(void)                  /* every UI frame, after the screens drew */
{
    u8 *seq = os_seq();
    if (!seq) return;
    if (on) {
        u32 ms = os_ms();
        measure(seq, ms);
        show(seq, ms);
    }
    if (telling < 0) return;
    if (telling) os_note_off(0, 24 + ((telling - 1) & 63));
    if (telling >= (i32)sizeof report * 2) { telling = -1; return; }
    u8 b = ((u8 *)&report)[telling >> 1];
    os_note_on(0, 24 + (telling & 63), 1 + (telling & 1 ? b & 15 : b >> 4));
    telling++;
}

i32 meter_key(u8 *seq, i32 control, i32 value)          /* a control was pressed or let go. 1: it was ours, and that was all */
{
    if (value != PRESSED || !seq || !seq[SEQ_SHIFT_KEY]) return 0;
    if (control == TEMPO) {
        on ^= 1;
        if (on) start();
        return 1;
    }
    if (control == SCREEN) {
        u8 sum = 0;
        for (u32 i = 0; i < sizeof report - 1; i++) sum += ((u8 *)&report)[i];
        report.sum = sum;
        telling = 0;
        return 1;
    }
    return 0;
}

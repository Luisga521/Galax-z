/* TO-2's tombola and EUCLID (floating point) beside the pages' fixed point, and the pages' behaviour, on the Mac. Built and
 * run by test_pages.py. */
#define PAGES_TEST
#include "../pages/pages.c"
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static u8 *mem; static u32 clock_ms; static u8 rec[53 * 5];
static int plays, last_note, last_vel, last_len, last_track, vmin = 999, vmax;
u8 *os_seq(void) { return mem; }
u32 os_ms(void) { return clock_ms; }
void os_play(u8 *s, i32 t, i32 n, i32 v, i32 l) { (void)s; plays++; last_track = t; last_note = n; last_vel = v; last_len = l; if (v < vmin) vmin = v; if (v > vmax) vmax = v; }
void os_led(i32 i, i32 r, i32 g, i32 b, i32 w) { rec[i*5]=r; rec[i*5+1]=g; rec[i*5+2]=b; rec[i*5+3]=w; rec[i*5+4]=0; }
u8 *os_led_record(i32 i) { return rec + i * 5; }
static i32 at_step, at_micro; static int recs, r_step, r_micro, r_note, r_vel, r_len, r_track; static u8 pat[0x2000];
void os_where(u8 *s, i32 t, i32 *st, i32 *m) { (void)s; (void)t; *st = at_step; *m = at_micro; }
void os_record(u8 *s, i32 t, i32 st, i32 m, i32 n, i32 v, i32 l) { (void)s; recs++; r_track = t; r_step = st; r_micro = m; r_note = n; r_vel = v; r_len = l; pat[0xc0 + (st * 55 + os_slot(t)) * 8 + 4] = n; }
u8 *os_pattern(u8 *s) { (void)s; return pat; }
i32 os_slot(i32 t) { static const i32 k[] = { 0, 2, 4, 6, 8, 12, 16, 24, 28, 29 }; return k[t]; }
static int flash_n, flash_page, flash_colour;
i32 os_pages(i32 t) { return t < 8 ? 7 : 4; }
i32 os_page_colour(i32 t, i32 p) { (void)t; return p == 3 ? -1 : 0x10 + p; }
void os_flash(i32 p, i32 c) { flash_n++; flash_page = p; flash_colour = c; }
static void put(u32 at, i32 v) { memcpy(mem + at, &v, 4); }
#define CHECK(x) do { if (!(x)) { printf("FAILED line %d: %s\n", __LINE__, #x); fails++; } } while (0)
static int fails;

/* ---- TO-2, in doubles ---- */
typedef struct { double x, y, vx, vy; int n; } B2;
static double rnd(void) { return rand() / (double)RAND_MAX * 2 - 1; }
static int ref(double G, double Bo, double S, double Sc, int nb, double secs, double *meanvel)
{
    B2 b[8]; double rot = 0; int hits = 0; double vs = 0;
    for (int i = 0; i < nb; i++) b[i] = (B2){ rnd() * .25, -.3, rnd() * .5, .1 + rnd() * .2, i };
    double w = S * 2.2, g = 1.5 + G * 10, e = .3 + Bo * .62, r = .075, dt = 1 / 240.0;
    for (int s = 0; s < secs * 240; s++) {
        rot += w * dt;
        double hx[7], hy[7];
        for (int k = 0; k <= 6; k++) { double a = rot + k * M_PI / 3; hx[k] = cos(a) * .86; hy[k] = sin(a) * .86; }
        for (int i = 0; i < nb; i++) {
            B2 *p = &b[i]; p->vy += g * dt; p->x += p->vx * dt; p->y += p->vy * dt;
            for (int k = 0; k < 6; k++) {
                double ex = hx[k+1]-hx[k], ey = hy[k+1]-hy[k], t = ((p->x-hx[k])*ex+(p->y-hy[k])*ey)/(ex*ex+ey*ey);
                t = fmin(1, fmax(0, t));
                double cx = hx[k]+ex*t, cy = hy[k]+ey*t, nx = p->x-cx, ny = p->y-cy, d = hypot(nx, ny);
                if (d < 1e-9) { nx = -cx; ny = -cy; d = hypot(nx, ny); }
                nx /= d; ny /= d; double pen = r - d; if (pen <= 0) continue;
                double wx = -w*cy, wy = w*cx, rx = p->vx-wx, ry = p->vy-wy, vn = rx*nx+ry*ny;
                p->x += nx*pen; p->y += ny*pen; if (vn >= 0) continue;
                double ox, oy;
                if (-vn > .35) {
                    ox = rx-(1+e)*vn*nx; oy = ry-(1+e)*vn*ny;
                    double tx=-ny, ty=nx, vt=(ox*tx+oy*ty)*.88+rnd()*Sc*.8, vnn=ox*nx+oy*ny;
                    ox = nx*vnn+tx*vt; oy = ny*vnn+ty*vt; hits++; vs += fmin(1, -vn*.38+.3);
                } else { ox = (rx-vn*nx)*.998; oy = (ry-vn*ny)*.998; }
                p->vx = wx+ox; p->vy = wy+oy;
            }
            double sp = hypot(p->vx, p->vy); if (sp > 5) { p->vx *= 5/sp; p->vy *= 5/sp; }
        }
        for (int i = 0; i < nb-1; i++) for (int j = i+1; j < nb; j++) {
            double dx=b[j].x-b[i].x, dy=b[j].y-b[i].y, d=hypot(dx,dy); if (d >= 2*r || d < 1e-6) continue;
            double nx=dx/d, ny=dy/d, o=(2*r-d)/2; b[i].x-=nx*o; b[i].y-=ny*o; b[j].x+=nx*o; b[j].y+=ny*o;
            double vn=(b[j].vx-b[i].vx)*nx+(b[j].vy-b[i].vy)*ny;
            if (vn<0) { double m=-(1+e*.9)*vn/2; b[i].vx-=nx*m; b[i].vy-=ny*m; b[j].vx+=nx*m; b[j].vy+=ny*m; }
        }
    }
    *meanvel = hits ? vs / hits : 0;
    return hits;
}

static long velsum;
static int ours(int g, int bo, int sp, int sc, int nb, double secs, double *meanvel, double *worst)
{
    Tumbler *t = &tumblers[4]; t->n = 0; knob[4][0]=g; knob[4][1]=bo; knob[4][2]=sp; knob[4][3]=sc; running = 0; plays = 0; velsum = 0;
    for (int i = 0; i < nb; i++) drop(t, 60 + i);
    int before = 0;
    for (double ms = 0; ms < secs * 1000; ms += 1 + rand() % 3) {
        clock_ms = 77777 + (u32)ms; pages_tick(mem);
        if (plays != before) { velsum += (long)last_vel * (plays - before); before = plays; }
        for (int i = 0; i < t->n; i++) { double d = hypot(t->ball[i].x, t->ball[i].y) / ONE; if (d > *worst) *worst = d; }
    }
    *meanvel = plays ? velsum / 127.0 / plays : 0;
    return plays;
}

int main(void)
{
    mem = calloc(1, 0x3a0000);
    /* the host's pointers are 64-bit: the screen test compares the low 32 bits, so write those */
    put(SEQ_SCREEN, (i32)(__SIZE_TYPE__)(mem + SEQ_STEPS)); put(SEQ_TRACK, 4); put(SEQ_PAGE, PINK); put(SEQ_HELD_STEP, 31);

    for (u32 a = 0; a < 4096; a++) { double w = sin(a / 4096.0 * 2 * M_PI), v = sin31(a << 20) / 2147483648.0; if (fabs(w - v) > 2e-4) { printf("sine %u %g %g\n", a, w, v); fails++; break; } }
    for (u32 i = 0; i < 100000; i++) { u32 v = (u32)rand() * 2 + 1, r = root(v); if ((unsigned long long)r*r > v || (unsigned long long)(r+1)*(r+1) <= v) { fails++; break; } }
    for (u32 i = 0; i < 100000; i++) { u32 n = (u32)rand() >> 1, d = (u32)rand() % 10000 + 1; if (divide(n, d) != n / d) { fails++; break; } }

    /* as many bounces as TO-2, about as loud, over the knobs' whole range; never out of the hexagon */
    int kn[][4] = {{115,153,64,38},{0,0,0,0},{255,255,255,255},{115,153,255,38},{0,255,0,0},{255,0,255,0},{40,230,120,255},{200,100,30,10},{0,0,255,0},{255,255,0,0}};
    for (unsigned c = 0; c < sizeof kn / sizeof *kn; c++) for (int nb = 1; nb <= 8; nb += 7) {
        double mv, rv, worst = 0, rvs = 0; int h = 0, n = 0;
        for (int k = 0; k < 8; k++) { n += ours(kn[c][0],kn[c][1],kn[c][2],kn[c][3],nb,30,&mv,&worst); h += ref(kn[c][0]/255.,kn[c][1]/255.,kn[c][2]/255.,kn[c][3]/255.,nb,30,&rv); rvs += rv; }
        printf("g%3d b%3d s%3d x%3d balls %d: %6.1f bounces/s (TO-2 %6.1f), loudness %.2f (TO-2 %.2f), farthest %.3f\n", kn[c][0],kn[c][1],kn[c][2],kn[c][3],nb,n/240.,h/240.,mv,rvs/8,worst);
        CHECK(worst < .82);
        CHECK(n <= 240 * 25 * nb);
    }

    /* the page, the keys, the dials, STOP */
    for (int i = 0; i < 8; i++) { tumblers[i].n = 0; }
    pages_note(mem, 4, 60); CHECK(tumblers[4].n == 1);
    pages_note(mem, 5, 60); CHECK(tumblers[5].n == 0);                 /* another track's note (MIDI) */
    put(SEQ_PAGE, 3); pages_note(mem, 4, 60); CHECK(tumblers[4].n == 1); CHECK(!pages_dials() && !pages_knob(4, 0, 1) && !pages_fade(40, 9) && !pages_stop());
    put(SEQ_PAGE, PINK); mem[SEQ_PLAYING] = 1;
    put(SEQ_TRACK, 8); CHECK(!pages_dials() && !pages_knob(8, 0, 1)); pages_note(mem, 8, 60); put(SEQ_TRACK, -1); CHECK(!pages_dials()); put(SEQ_TRACK, 4);
    for (int i = 0; i < 12; i++) pages_note(mem, 4, 40 + i);
    CHECK(tumblers[4].n == 8 && tumblers[4].ball[0].note == 44 && tumblers[4].ball[7].note == 51);
    knob[4][1] = 100; u8 k0 = 100; CHECK(pages_knob(4, 1, 5) && knob[4][1] == k0 + 5); CHECK(pages_knob(4, 1, 1000) && knob[4][1] == 255); CHECK(pages_knob(4, 1, -1000) && knob[4][1] == 0);
    CHECK(knob[0][1] == 153);                                   /* each track its own */
    CHECK(pages_dials() && rec[40*5] > 0 && rec[41*5] == 8 && rec[40*5+3] == 0);
    memset(rec, 0, sizeof rec); CHECK(pages_fade(42, 255) && rec[42*5] >= 254 && rec[42*5+1] == 0);
    for (int i = 0; i < 200; i++) { clock_ms += 5; pages_tick(mem); }
    memset(rec, 0, sizeof rec); pages_paint(); int lit = 0; for (int i = 0; i < 16; i++) lit += rec[i*5] > 0; CHECK(lit >= 1 && lit <= 16); for (int i = 16; i < 53; i++) CHECK(rec[i*5] == 0);
    put(SEQ_SCREEN, 5); memset(rec, 0, sizeof rec); pages_paint(); for (int i = 0; i < 16; i++) CHECK(rec[i*5] == 0);
    put(SEQ_TRACK, 5); pages_note(mem, 5, 62); put(SEQ_TRACK, 4);
    CHECK(pages_stop() == 1 && tumblers[4].n == 0 && tumblers[5].n == 1);
    CHECK(pages_stop() == 0 && tumblers[5].n == 1);                    /* playing: the next STOP is TE's */
    mem[SEQ_PLAYING] = 0; CHECK(pages_stop() == 0 && tumblers[5].n == 0);
    put(SEQ_SOUNDING, 45); knob[4][1] = 200; drop(&tumblers[4], 60); plays = 0; for (int i = 0; i < 2000; i++) { clock_ms += 2; pages_tick(mem); } CHECK(plays == 0);
    put(SEQ_SOUNDING, 0); drop(&tumblers[4], 60); for (int i = 0; i < 2000; i++) { clock_ms += 2; pages_tick(mem); } CHECK(plays > 0 && last_note == 60 && last_track == 4 && last_len == 36 << 8);
    /* recording: at_step / at_micro is the playhead; a take is written once the playhead is past it */
    for (int i = 0; i < 8; i++) tumblers[i].n = 0;
    memset(pat, 0xff, sizeof pat); mem[SEQ_PLAYING] = 1; put(SEQ_HELD_STEP, 31); put(SEQ_TRACK, 4); recs = 0;
#define GO(st, mi) (at_step = (st), at_micro = (mi), pages_tick(mem))
    play(mem, 4, 60, 90, 36 << 8); GO(3, 90); CHECK(recs == 0 && !ntakes);        /* REC off */
    mem[SEQ_REC] = 1; GO(3, 20); play(mem, 4, 60, 90, 36 << 8); GO(3, 20); CHECK(recs == 0); GO(3, 28); CHECK(recs == 1 && r_track == 4 && r_step == 3 && r_micro == 20 && r_note == 60 && r_vel == 90 && r_len == 36 << 8);
    play(mem, 4, 60, 90, 36 << 8); GO(4, -90); CHECK(recs == 1 && !ntakes);       /* the step has it */
    GO(4, -90); play(mem, 4, 62, 90, 36 << 8); play(mem, 5, 64, 90, 36 << 8); CHECK(ntakes == 1);  /* not the selected track */
    GO(4, -10); GO(4, 0); GO(4, 7); CHECK(recs == 1); GO(4, 8); CHECK(recs == 2 && r_step == 4 && r_micro == -90);
    GO(4, 92); play(mem, 4, 63, 90, 36 << 8); GO(5, -92); CHECK(recs == 3 && r_step == 4 && r_micro == 92);
    GO(15, -5); play(mem, 4, 70, 90, 36 << 8); GO(0, -80); CHECK(recs == 4 && r_step == 15);
    GO(7, -5); play(mem, 4, 71, 90, 36 << 8); mem[SEQ_PLAYING] = 0; GO(7, -5); CHECK(recs == 5 && r_step == 7); play(mem, 4, 72, 90, 36 << 8); CHECK(recs == 5 && !ntakes);
    mem[SEQ_PLAYING] = 1; put(SEQ_HELD_STEP, 2); play(mem, 4, 73, 90, 36 << 8); put(SEQ_HELD_STEP, 31); put(SEQ_ERASING, 1); play(mem, 4, 73, 90, 36 << 8); put(SEQ_ERASING, 0);
    GO(-1, 0); play(mem, 4, 73, 90, 36 << 8); GO(16, 0); play(mem, 4, 73, 90, 36 << 8); CHECK(recs == 5 && !ntakes);
    GO(1, -3); for (int i = 0; i < 40; i++) play(mem, 4, 20 + i, 90, 36 << 8); CHECK(ntakes == TAKES && recs == 5 + 40 - TAKES); GO(1, 50); CHECK(ntakes == 0 && recs == 45);
    GO(1, -3); for (int i = 0; i < 40; i++) play(mem, 4, 100, 90, 36 << 8); CHECK(ntakes == 1); GO(1, 50); CHECK(recs == 46);
    mem[SEQ_REC] = 0; mem[SEQ_REC_HELD] = 1; GO(2, 0); play(mem, 4, 60, 90, 36 << 8); GO(2, 8); CHECK(recs == 47); mem[SEQ_REC_HELD] = 0; mem[SEQ_PLAYING] = 0;
#include "test_euclid.h"
    clock_ms += 100000000; pages_tick(mem); CHECK(acc < 1000);         /* a long gap: no burst */
    CHECK(vmin >= 38 && vmax <= 127);
    /* SCREEN held (v14): on the SCREEN screen the blue dial turns the parameter pages, both ways; the flash comes when SCREEN is let go */
    put(SEQ_TRACK, 4); put(SEQ_PAGE, 0); mem[SEQ_SCREEN_KEY] = 1; flash_n = 0;
    CHECK(!pages_screen(1, 1) && !pages_screen(3, 1) && !pages_screen(4, -1) && !pages_screen(2, 0));   /* the others: TE's */
    CHECK(pages_screen(2, 3) && word(mem, SEQ_PAGE) == 0); CHECK(pages_screen(2, 1) && word(mem, SEQ_PAGE) == 1 && flash_n == 0);
    pages_tick(mem); CHECK(flash_n == 0);                                           /* still down */
    mem[SEQ_SCREEN_KEY] = 0; pages_tick(mem); CHECK(flash_n == 1 && flash_page == 1 && flash_colour == 0x11); pages_tick(mem); CHECK(flash_n == 1);
    mem[SEQ_SCREEN_KEY] = 1;
    CHECK(pages_screen(2, -40) && word(mem, SEQ_PAGE) == 0);                        /* a page at a time, however fast */
    CHECK(pages_screen(2, -4) && word(mem, SEQ_PAGE) == 6);                         /* round to the last */
    CHECK(pages_screen(2, 4) && word(mem, SEQ_PAGE) == 0);
    CHECK(pages_screen(2, 2)); mem[SEQ_SCREEN_KEY] = 0; pages_tick(mem); mem[SEQ_SCREEN_KEY] = 1;
    CHECK(pages_screen(2, 2) && word(mem, SEQ_PAGE) == 0);                          /* let go: the clicks so far are gone */
    put(SEQ_PAGE, 2); CHECK(pages_screen(2, 4) && word(mem, SEQ_PAGE) == 3);
    flash_n = 0; mem[SEQ_SCREEN_KEY] = 0; pages_tick(mem); CHECK(flash_n == 0);      /* no kind there: no flash */
    put(SEQ_TRACK, 9); put(SEQ_PAGE, 3); mem[SEQ_SCREEN_KEY] = 1; CHECK(pages_screen(2, 4) && word(mem, SEQ_PAGE) == 0);     /* four pages there */
    { u8 k0 = knob[4][0]; put(SEQ_TRACK, 4); put(SEQ_PAGE, 0); CHECK(!pages_knob(4, 0, 6) && knob[4][0] == k0); }      /* DefaultContext's dials as they were */
    mem[SEQ_SCREEN_KEY] = 0; pages_tick(mem); put(SEQ_PAGE, 0);
    printf(fails ? "%d FAILED\n" : "ok\n", fails);
    return fails != 0;
}

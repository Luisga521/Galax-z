    /* ---- EUCLID, inside test_pages.c's main ---- */
    {
        /* TO-2's numbers (enum Euclid, euclidPulse) for every position of every dial */
        static const double divs[7] = { 2, 3, 4, 6, 8, 12, 16 };
        int off = 0;
        for (int b = 0; b < 256; b++) {
            float v = b / 255.0f;
            int n2 = (int)(v * 14.99f); if (n2 > 14) n2 = 14; n2 += 2;
            CHECK(e_steps(b) == n2);
            for (int n = 2; n <= 16; n++) {
                int k2 = 1 + (int)(v * n * 0.999f); if (k2 > n) k2 = n;
                int r2 = (int)(v * n * 0.999f); if (r2 > n - 1) r2 = n - 1;
                off += e_pulses(b, n) != k2; off += e_rot(b, n) != r2;      /* rounding at an edge, at most one place */
                CHECK(abs(e_pulses(b, n) - k2) <= 1 && abs(e_rot(b, n) - r2) <= 1);
            }
            knob[4][RATE] = (u8)b; set_now(mem); int d = (int)(v * 6.99f); if (d > 6) d = 6;
            CHECK(step_ticks(4) == (int)(192 / divs[d]));
        }
        printf("pulses and rotation differ from TO-2's by one at %d of %d dial positions\n", off, 256 * 15 * 2);
        CHECK(off < 256 * 15 * 2 / 50);
        for (int n = 2; n <= 16; n++) for (int k = 1; k <= n; k++) for (int r = 0; r < n; r++) { int c = 0; for (int i = 0; i < n; i++) { CHECK(is_pulse(i, n, k, r) == (((i + r) % n) * k % n < k)); c += is_pulse(i, n, k, r); } CHECK(c == k); }

        /* E(3,8) at 16ths on two notes, from the OP-Z's first step */
        mem[SEQ_PLAYING] = 0; mem[SEQ_REC] = mem[SEQ_REC_HELD] = 0; put(SEQ_PAGE, TEAL); put(SEQ_TRACK, 5); put(SEQ_SCREEN, (i32)(__SIZE_TYPE__)(mem + SEQ_STEPS)); put(SEQ_HELD_STEP, 31); put(SEQ_SOUNDING, 0); put(SEQ_LENGTH, 16); put(SEQ_PATTERN, 33);
        for (int t = 0; t < 8; t++) { tumblers[t].n = euclids[t].n = 0; static const u8 as_new[KNOBS] = AS_NEW; memcpy(knob[t], as_new, KNOBS); }
        ntakes = 0; clock_ms += 5000; pages_tick(mem);
        int tick = 23, step = 15, total = 0, at[400], notes[400], vels[400], lens[400], np = 0;
        pages_note(mem, 5, 60); pages_note(mem, 5, 67); CHECK(euclids[5].n == 2);
        pages_note(mem, 6, 60); CHECK(euclids[6].n == 0);
        mem[SEQ_PLAYING] = 1; put(SEQ_TICK, 20); pages_tick(mem);       /* pressed play: not yet on a step */
#define RUN(nticks) do { np = 0; for (total = 0; total < (nticks); total++) { if (++tick == 24) { tick = 0; step = (step + 1) & 15; } put(SEQ_TICK, tick); put(SEQ_STEP, step); for (int t = 0; t < 8; t++) mem[SEQ_TRACK_STEP + t] = (u8)(step << 4); \
            int was = plays; clock_ms += 5; pages_tick(mem); if (plays != was && np < 400) { at[np] = total; notes[np] = last_note; vels[np] = last_vel; lens[np++] = last_len; } } } while (0)
        RUN(384);
        CHECK(np == 6);
        static const int where[6] = { 0, 3 * 24, 6 * 24, 192, 192 + 72, 192 + 144 };
        for (int i = 0; i < np && i < 6; i++) { CHECK(at[i] == where[i] && notes[i] == (i & 1 ? 67 : 60)); CHECK(vels[i] == (i % 3 ? 114 - (77 * 57 >> 8) : 114 + (77 * 13 >> 8))); CHECK(lens[i] == 24 * (26 + (128 * 218 >> 8))); }
        /* played again from the top in the middle of a bar: back on the grid */
        RUN(100); tick = 23; step = 15; RUN(96); CHECK(np >= 2 && at[0] == 0 && at[1] == 72);
        /* chance 0, octaves, the longest and the shortest */
        tick = 23; step = 15; knob[5][CHANCE] = 0; RUN(384); CHECK(np == 0); knob[5][CHANCE] = 128; RUN(384 * 8); CHECK(np > 12 && np < 36); knob[5][CHANCE] = 255;
        tick = 23; step = 15; knob[5][OCTAVES] = 255; euclids[5].pulses = 0; euclids[5].next = 0; RUN(384); CHECK(np == 6 && notes[0] == 60 && notes[1] == 79 && notes[2] == 84 && notes[3] == 103 && notes[4] == 60); knob[5][OCTAVES] = 0;
        knob[5][STEPS] = knob[5][PULSES] = knob[5][RATE] = knob[5][GATE] = 255; tick = 23; step = 15; RUN(384); CHECK(np == 32 && lens[0] == 12 * 243); knob[5][GATE] = 0; RUN(24); CHECK(lens[0] == 12 * 26);
        /* stopped: goes on; the first note of all starts it at once */
        mem[SEQ_PLAYING] = 0; euclids[5].n = 0; RUN(50); CHECK(np == 0); pages_note(mem, 5, 50); RUN(13); CHECK(np == 2 && at[0] == 0 && at[1] == 12);
        /* let go of a note; the ninth pushes the first out */
        pages_note(mem, 5, 50); CHECK(euclids[5].n == 0); for (int i = 0; i < 9; i++) pages_note(mem, 5, 40 + i); CHECK(euclids[5].n == 8 && euclids[5].ring[0].key == 41 && euclids[5].ring[7].key == 48);
        euclids[5].n = 0;

        /* a drum track: a ring a key, 16/4 and 16/3 on one clock; pick, then leave */
        put(SEQ_TRACK, 0); pages_note(mem, 0, 53); pages_note(mem, 0, 55); CHECK(euclids[0].n == 2 && euclids[0].ring[0].pulses == 4 && euclids[0].ring[1].pulses == 3 && euclids[0].pick == 1);
        pages_note(mem, 0, 53); CHECK(euclids[0].n == 2 && euclids[0].pick == 0);
        CHECK(pages_knob(0, 0, -8) && euclids[0].ring[0].steps == 15 && pages_knob(0, 1, 7) && euclids[0].ring[0].pulses == 4 && pages_knob(0, 1, 1) && euclids[0].ring[0].pulses == 5);
        CHECK(pages_knob(0, 0, -1000) && euclids[0].ring[0].steps == 2 && euclids[0].ring[0].pulses == 2); CHECK(pages_knob(0, 2, 1000) && euclids[0].ring[0].rot == 1); CHECK(pages_knob(0, 0, 8));
        mem[SEQ_PLAYING] = 1; put(SEQ_TICK, 20); pages_tick(mem); tick = 23; step = 15; plays = 0; RUN(384); CHECK(plays == 3 + 10 && lens[0] == 24 << 8);    /* 16/3, and 3/2 turned by 1 */
        pages_note(mem, 0, 53); CHECK(euclids[0].n == 1 && euclids[0].ring[0].key == 55 && euclids[0].pick == 0);
        CHECK(pages_dials() && rec[40*5] == 0 && rec[40*5+1] > 200 && rec[40*5+2] > 60);
        for (int i = 0; i < 80; i++) rec[i] = 9; pages_paint(); int white = 0; for (int i = 0; i < 16; i++) white += rec[i*5+3] > 0; CHECK(white == 1);
        put(SEQ_SCREEN, 5); for (int i = 0; i < 80; i++) rec[i] = 9; pages_paint(); CHECK(rec[0] == 9); put(SEQ_SCREEN, (i32)(__SIZE_TYPE__)(mem + SEQ_STEPS));
        mem[SEQ_PLAYING] = 1; CHECK(pages_stop() == 1 && euclids[0].n == 0 && pages_stop() == 0);
        pages_note(mem, 0, 53); put(SEQ_PAGE, 0); mem[SEQ_PLAYING] = 0; CHECK(pages_stop() == 0 && euclids[0].n == 0); put(SEQ_PAGE, TEAL);

        /* SHIFT for 2 s: MORE and back, its release not turning the page; not with a key, not let go early, not on another page */
        put(SEQ_TRACK, 6); mem[SEQ_CLEAN] = 1;
#define HOLD(ms) do { mem[SEQ_SHIFT] = 1; mem[SEQ_CLEAN] = 1; for (int m = 0; m <= (ms); m += 5) { clock_ms += 5; pages_tick(mem); } } while (0)
#define LET_GO() do { mem[SEQ_SHIFT] = 0; pages_tick(mem); } while (0)
        HOLD(1900); CHECK(!euclids[6].more && mem[SEQ_CLEAN] == 1); LET_GO();
        HOLD(2100); CHECK(euclids[6].more && mem[SEQ_CLEAN] == 0 && flashes == 2);
        int seen_on[8] = { 0 }, seen_off[8] = { 0 }, last = -1, ons = 0; for (int m = 0; m < 1000; m += 5) { clock_ms += 5; pages_dials(); int lit = rec[40*5+1] >= 254; if (lit && last != 1) ons++; last = lit; } (void)seen_on; (void)seen_off; CHECK(ons == 2 && flashes == 0);
        HOLD(5000); CHECK(euclids[6].more == 1); LET_GO();                       /* only once a press */
        CHECK(pages_knob(6, 0, 9) && knob[6][GATE] == 137 && knob[6][STEPS] == 115);
        HOLD(2100); CHECK(!euclids[6].more && flashes == 1); ons = 0; last = -1; for (int m = 0; m < 1000; m += 5) { clock_ms += 5; pages_dials(); int lit = rec[40*5+1] >= 254; if (lit && last != 1) ons++; last = lit; } CHECK(ons == 1); LET_GO();
        mem[SEQ_SHIFT] = 1; touched = 1; HOLD(3000); CHECK(!euclids[6].more); LET_GO(); CHECK(!touched);
        mem[SEQ_SHIFT] = 1; mem[SEQ_CLEAN] = 0; for (int m = 0; m < 3000; m += 5) { clock_ms += 5; pages_tick(mem); } CHECK(!euclids[6].more); LET_GO();
        put(SEQ_PAGE, PINK); HOLD(3000); CHECK(!euclids[6].more); LET_GO(); put(SEQ_PAGE, TEAL);
        HOLD(2100); CHECK(euclids[6].more); LET_GO(); put(SEQ_PAGE, 0); pages_tick(mem); CHECK(!euclids[6].more); put(SEQ_PAGE, TEAL);

        /* dials recorded: a value a step, for a second after the last turn, back to the dial elsewhere; in this pattern only */
        clock_ms += 5000; mem[SEQ_PLAYING] = 1; mem[SEQ_REC] = 1; tick = 23; step = 15; knob[6][STEPS] = 100; knob[6][PULSES] = 50; RUN(24 * 2 + 1); CHECK(now[6][STEPS] == 100);
        CHECK(pages_knob(6, 0, 20) && knob[6][STEPS] == 100 && now[6][STEPS] == 120);    /* step 2 */
        clock_ms += 5; CHECK(pages_knob(6, 0, 20) && now[6][STEPS] == 140);
        RUN(24); CHECK(now[6][STEPS] == 140); CHECK(pages_knob(6, 0, 10));               /* step 3 */
        clock_ms += 2000; RUN(24); CHECK(now[6][STEPS] == 100);                          /* step 4: let go of */
        mem[SEQ_REC] = 0; RUN(24 * 14); CHECK(step == 2 && now[6][STEPS] == 140); RUN(24); CHECK(now[6][STEPS] == 150); RUN(24); CHECK(now[6][STEPS] == 100);
        u8 *row = lock_row(mem, 6, STEPS); CHECK(row && row[2] == 140 && row[3] == 150 && row[4] == 255 && row[1] == 255 && !lock_row(mem, 6, PULSES) && !lock_row(mem, 5, STEPS));
        CHECK(pages_knob(6, 0, 5) && knob[6][STEPS] == 105);                             /* REC off: the dial itself */
        put(SEQ_PATTERN, 34); RUN(24 * 16); CHECK(now[6][STEPS] == 105 && !lock_row(mem, 6, STEPS)); put(SEQ_PATTERN, 33);
        put(SEQ_PATTERN, 9999); CHECK(!lock_row(mem, 6, STEPS)); mem[SEQ_REC] = 1; CHECK(pages_knob(6, 0, 5)); mem[SEQ_REC] = 0; put(SEQ_PATTERN, -1); pages_tick(mem); put(SEQ_PATTERN, 33); hands = 0;
        mem[SEQ_PLAYING] = 0; pages_tick(mem); CHECK(now[6][STEPS] == knob[6][STEPS]);
        /* a held step takes the value, and is not switched when let go */
        put(SEQ_HELD_STEP, 9); put(SEQ_STEPS + 0xc, 15); mem[SEQ_STEPS + 0x15] = 1; CHECK(pages_knob(6, 1, 30) && knob[6][PULSES] == 50 && lock_row(mem, 6, PULSES)[9] == 80 && !word(mem, SEQ_STEPS + 0xc) && !mem[SEQ_STEPS + 0x15]);
        CHECK(pages_knob(6, 1, 30) && lock_row(mem, 6, PULSES)[9] == 110 && shown(mem, 6, PULSES) == 110 && shown(mem, 6, STEPS) == knob[6][STEPS]); put(SEQ_HELD_STEP, 31);
        /* the tumbler's dials too */
        put(SEQ_PAGE, PINK); mem[SEQ_PLAYING] = 1; mem[SEQ_REC] = 1; RUN(5); u8 g0 = knob[6][SPIN]; CHECK(pages_knob(6, SPIN, 50) && knob[6][SPIN] == g0 && lock_row(mem, 6, SPIN)[step] == g0 + 50); put(SEQ_PAGE, TEAL);
        /* REC with -: a dial's values go */
        put(SEQ_ERASING, 1); CHECK(pages_knob(6, 0, 1) && !lock_row(mem, 6, STEPS) && lock_row(mem, 6, PULSES)); put(SEQ_ERASING, 0); hands = 0;
        /* EUCLID's notes are recorded */
        memset(pat, 0xff, sizeof pat); recs = 0; at_step = 3; at_micro = 0; knob[6][STEPS] = 115; knob[6][PULSES] = 77; knob[6][RATE] = 153; pages_note(mem, 6, 61); tick = 23; step = 15; RUN(30); CHECK(ntakes == 1 && recs == 0); at_micro = 20; RUN(1); CHECK(recs == 1 && r_note == 61 && r_track == 6 && r_step == 3);
        mem[SEQ_REC] = 0; mem[SEQ_PLAYING] = 0; euclids[6].n = 0; put(SEQ_PAGE, PINK); put(SEQ_TRACK, 4);
    }

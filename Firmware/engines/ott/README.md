# ott: three-band upward and downward compression, for FX1 and FX2

Brings quiet detail up and loud peaks down in three bands at once (Linkwitz-Riley, 150 Hz and 2.5 kHz). Ours from the ground up;
the method is the well-known "over the top" one. **On the author's unit since 2026-11-22**
(FX2 key 10, where glue was; read back), works there; its preset is in the boot file.

| Knob | Left | Centre | Right |
|---|---|---|---|
| **P1 depth** | nothing | half, in dB | all: -60 dBFS comes up to about -34, a band at -15 stays |
| **P2 time** | x 1/4: pumping, gritty | attack 40 / 20 / 12 ms, release 280 / 250 / 130 ms | x 4: smooth |

The FX track's dry level (hold its key + red dial) at 0 makes it an insert, as the preset has it; its bands turn the phase, so
much dry beside it thins the sound around 150 Hz and 2.5 kHz. Silence stays silent: below -63 dBFS it lifts less and less.

Plug 61105, memory slot 67 (5 KB), 3,812 bytes, no FX buffer, 440 cycles a sample (worst block 516; target 600).
Build and tests: op-free's `opz_build.py`, `opz_cycles.py`, `sim/tests/golden.py`.

# piano: a sampled grand for the OP-Z

A Yamaha C5 grand for the lead, arp and chord tracks (and bass): 30 recorded notes in stereo, in the plug's sample pack,
played by an engine of ours. **v1 installed on the author's unit 2026-11-22**; **works there**, but sounded like an electric piano. **v2 installed 2026-11-22** (pack and engine held, record v2, boot file held);
**works there**. Its registration was dropped by the OP-Z twice without an error (patch.json fetched, plugs.json still v1); the same bytes sent again took. The numbers
below are from the simulators and op-free's reading of the OS.

Samples: **Salamander Grand Piano V3 by Alexander Holm, CC BY 3.0**
(https://creativecommons.org/licenses/by/3.0/, https://github.com/sfzinstruments/SalamanderGrandPiano), cut, levelled,
re-tuned, compressed and re-encoded here. `opzk_piano.aif` is a derivative under the same licence: keep this credit with it.

| Knob | Left | Centre (detent) | Right |
|---|---|---|---|
| **P1 tone** | dark, felt-like | the recording | bright (+11 dB above 1.5 kHz) |
| **P2 hammer** | soft attack | the recording | hard attack |

Velocity sets level and tone: below 104 (the recorded layer) it darkens as Salamander's softer layers do, low notes sooner. Filter, resonance
and the sends are the OS's. The envelope page works on top of the piano's own decay (sustain 255 = natural, release ~20 =
dampers, 120 = pedal). Level and pan as TE's engines. Poly, mono and portamento work; legato only bends the sounding note.
Presets on every track: grand, bright, felt, staccato, pedal.

| | |
|---|---|
| Plug | id 61204, flags 24 (both knobs bipolar), `samplepacks/opzk_piano.aif` |
| Memory slot | 30 (10 KB class, unused by TE, op-free's table and the author's unit on 2026-11-21) |
| Engine | 4,472 bytes; state 256-280 B a voice; 776 B of stack |
| Pack | 1053852 bytes: the 12 s an OP-1 drum pack can hold, used as data |
| CPU | 116-141 cycles a sample a voice, worst block 155 (budget 167); 9 voices (lead 3, arp 2, chord 4) 89,000 cycles a block |

## Install

`opz.py install` refuses it (it wants a sample plug first); `install_piano.py` does the same checks, uploads the pack, proves
it is there, then installs:

```bash
$OPFREE/.venv/bin/python install_piano.py --dry-run
```

Presets live in RAM: after a restart, `.venv/bin/python tools/opz.py presets push <this folder>` in op-free. Off again:
`install_piano.py --uninstall` (the engine file stays, as with every engine).

## The pack

The OS loads the whole pack into RAM as 16-bit words and locks it while a note sounds; the engine gets its address from
`getSample` and reads it as: header (64 bytes: "PANO", version, length, checksum), 30 zones of 192 bytes, 32 scales,
interpolation tables (512 phases: 8-tap, 4-tap), streams. `onNoteOn` checks the header, every offset and a checksum, and
stays silent on anything else; no pack, no sound (the OS drops the notes).

- Each note has a mid stream (19-33 kHz) and a side stream at half that rate, 4.25 bits a sample: four-tap prediction, 8
  predictors a stream, 32-sample blocks, noise shaped per stream by a masking model (`tools/adpcm.c`).
- The first 0.3-1.95 s are the recording; then a loop made of the note's own partials, moved at most half a loop
  harmonic, in phase at the join, with the measured decay applied by the engine.
- Before that, per note: phase between the microphones softened (left + right must not cancel on the speaker), an
  evened loudness curve, first partial at equal temperament plus a mild stretch (-9 cents at A0, +16 at C8).
- **v2** (against the samples, velocity 104): the recorded decay (v1 evened it: C4 fell 16 dB in a second, the grand 21), a decay in two
  slopes after the loop starts, as strings have (`two_slopes`), the loop's beating .22 -> .04 (C3 held: 1.0 dB of wobble, now 0.2; the
  grand 0.07), more of the stereo kept (C5 side/mid 2.6 -> 5.1 dB; the grand 6.9), low notes darker when soft. Note-on checks the
  pack once, not each time (10,948 -> 779 cycles).

Rebuild: `tools/get_samples.py DIR 13`, `tools/build_pack.py DIR opzk_piano.aif` (numpy, scipy, soundfile), then
`tools/opz_build.py` in op-free. The kernels in `piano.c` are hand-written Blackfin with C twins (`PIANO_NO_ASM`), bit-identical.

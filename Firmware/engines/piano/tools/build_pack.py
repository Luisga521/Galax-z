#!/usr/bin/env python3
"""Build the piano's sample pack (opzk_piano.aif) from the Salamander Grand Piano V3 samples.

    build_pack.py SAMPLES_DIR OUT.aif [--report R.json] [--previews DIR]

SAMPLES_DIR holds <note>v13.flac (30 notes, A0 to C8 in minor thirds; tools/get_samples.py fetches them). Needs numpy,
scipy and soundfile. What it does, per note: trim, level, gentle re-tuning, inter-channel phase (so the OP-Z's speaker
keeps every partial), mid + half-rate side, a loop resynthesised from the note's own partials, the measured decay
after the loop starts, 4-bit adaptive prediction (adpcm.c), and one blob of at most 1,058,400 bytes that is stored as
the 16-bit samples of an OP-1 drum pack. Format: ../README.md.
"""
import argparse, ctypes, json, os, struct, subprocess, sys, tempfile
import numpy as np, scipy.signal as ss, soundfile as sf

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.environ.get("OPFREE", os.path.expanduser("~/Desktop/op-free-main")) + "/tools")
import opz_samples  # noqa: E402

NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
ZONES = list(range(21, 109, 3))
LAYER = 13
TIME = 0.81                                        # scales how long each note plays before its loop, to fill the pack
MAGIC, VERSION = 0x4F4E4150, 2                      # "PANO"
BLOB_MAX = 529200 * 2
BL, BB = 32, 17
SUSTAIN = float(os.environ.get("SUSTAIN", 1.0))     # 1: the recorded decay; below: evened (v1 had .74, which made it an electric piano)
SWELL = float(os.environ.get("SWELL", .04))         # how much the loop's partials beat (v1: .22, a tremolo)
FULL = 22000                                       # a stream's peak: room for the bright end of the tone knob
PHASES, TAPS_M, TAPS_S = 512, 8, 4
ORDER = int(os.environ.get("ORDER", 4))
GAMMAS = (0, .1, .2, .3, .45, .6, .75)              # noise shaping tried per stream: 0 white, 1 like the signal
SCALES = np.round(np.geomspace(1, 4000, 32)).astype(int)
for i in range(1, 32):
    SCALES[i] = max(SCALES[i], SCALES[i - 1] + 1)


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def tune_cents(m):
    """Where each note's first partial ends up: a mild stretch (the source's is about twice this)."""
    return 16 * ((m - 60) / 48) ** 2 if m > 60 else -9 * ((60 - m) / 39) ** 2


def plan(m):
    """(rate of the mid channel, seconds before the loop, loop seconds)"""
    t = TIME * np.interp(m, [21, 33, 45, 57, 63, 69, 75, 81, 87, 93, 99, 108], [2.1, 2.35, 2.45, 2.3, 1.85, 1.6, 1.35, 1.1, .9, .72, .55, .42])
    l = np.interp(m, [21, 57, 69, 81, 93, 108], [.85, .8, .6, .4, .25, .18])
    rate = np.interp(m, [21, 36, 39, 57, 60, 72, 75, 93, 96, 108], [19000, 19000, 22050, 22050, 26000, 26000, 29400, 29400, 33000, 33000])
    return float(rate), float(t), float(l)


def load(d, m):
    x, sr = sf.read(os.path.join(d, f"{NAMES[m % 12]}{m // 12 - 1}v{LAYER}.flac"))
    x = x - x.mean(0)
    x = ss.sosfiltfilt(ss.butter(2, min(30.0, max(14.0, hz(m) * .5)), "hp", fs=sr, output="sos"), x, axis=0)
    e = np.abs(x).max(1)
    on = int(np.argmax(e > .02 * e.max()))
    pre = int(.0025 * sr)
    x = x[max(0, on - pre):]
    n = min(pre, len(x))
    x[:n] *= (.5 - .5 * np.cos(np.pi * np.arange(n) / n))[:, None]
    return x, sr


def first_partial(x, sr, m):
    a, t, r = (.12, 1.8, .04) if m < 72 else (.12, .6, .04) if m < 99 else (.008, .25, .08)
    seg = x[int(a * sr):int((a + t) * sr)]
    n = 1 << 20
    p = (np.abs(np.fft.rfft(seg * np.hanning(len(seg))[:, None], n, axis=0)) ** 2).sum(1)
    f = np.arange(len(p)) * sr / n
    i = np.abs(f - hz(m)) < r * hz(m)
    return float(f[np.argmax(np.where(i, p, 0))])


def partials(x, sr, t0, dur, f1, limit=140):
    """(freq, complex amplitude at t0 per channel) of the spectral peaks of x[t0 : t0 + dur]."""
    a, n = int(t0 * sr), int(dur * sr)
    seg = x[a:a + n]
    if len(seg) < n:
        seg = np.vstack([seg, np.zeros((n - len(seg), x.shape[1]))])
    w = ss.windows.blackmanharris(n)[:, None]
    N = 1 << int(np.ceil(np.log2(n * 8)))
    X = np.fft.rfft(seg * w, N, axis=0) * 2 / w.sum()
    P = (np.abs(X) ** 2).sum(1)
    df = sr / N
    pk = ss.find_peaks(P, distance=int(4.5 * N / n))[0]
    pk = pk[(pk * df > .6 * f1) & (pk * df < sr * .45)]
    pk = pk[P[pk] > P.max() * 10 ** -8.2]
    pk = pk[np.argsort(-P[pk])][:limit]
    out = []
    for k in pk:
        u, v, w3 = np.log(P[k - 1:k + 2] + 1e-30)
        out.append(((k + .5 * (u - w3) / (u - 2 * v + w3)) * df, X[k] * 1.0))
    return out


def soften_phase(x, sr, m):
    """Shrink the phase difference between the two microphones, partial by partial, so left + right does not cancel.
    A fixed filter per note (the mean cross-spectrum of the first second), only as strong as the note is high."""
    alpha = float(np.interp(m, [36, 60, 72], [.95, .75, .65]))
    n = 1 << int(np.ceil(np.log2(len(x) + sr)))
    seg = x[:int(min(1.2, len(x) / sr) * sr)]
    X = np.fft.rfft(seg, n, axis=0)
    f = np.arange(n // 2 + 1) * sr / n
    C = X[:, 1] * np.conj(X[:, 0])
    bw = max(hz(m) * .22, 8.0)                       # smooth the cross-spectrum around each partial
    k = max(1, int(bw / (sr / n)))
    ker = np.hanning(2 * k + 1); ker /= ker.sum()
    C = ss.fftconvolve(C, ker, mode="same")
    ph = np.angle(C) * (1 - alpha)
    fade = np.clip((7000 - f) / 2000, 0, 1) * np.clip((f - 60) / 40, 0, 1)
    ph = ph * fade
    rot = np.exp(1j * ph / 2)
    # limit how long the filter rings (pre-echo): window its impulse response
    def limit(H):
        h = np.fft.irfft(H, n)
        r = int(min(.012, 1.2 / hz(m)) * sr)
        w = np.zeros(n); t = np.arange(-r, r + 1); w[t % n] = .5 + .5 * np.cos(np.pi * t / (r + 1))
        return np.fft.rfft(h * w, n)
    Y = np.fft.rfft(x, n, axis=0)
    y = np.stack([np.fft.irfft(Y[:, 0] * limit(rot), n), np.fft.irfft(Y[:, 1] * limit(np.conj(rot)), n)], 1)[:len(x)]
    return y


def resample_to(x, ratio):
    """Band-limited resampling by `ratio` (new/old rate) with an FFT, exact to ~1e-7."""
    n0 = len(x)
    best = None
    for pad in range(4096, 4096 + 4000):
        n = n0 + pad
        k = round(n * ratio)
        err = abs(k / n / ratio - 1)
        if best is None or err < best[0]:
            best = (err, n, k)
            if err < 2e-8:
                break
    _, n, k = best
    X = np.fft.rfft(np.vstack([x, np.zeros((n - n0, x.shape[1]))]), axis=0)
    Y = np.zeros((k // 2 + 1, x.shape[1]), complex)
    c = min(len(X), len(Y))
    f = np.arange(c) / len(Y) if ratio < 1 else np.arange(c) / len(X)
    Y[:c] = X[:c] * np.where(f > .93, .5 + .5 * np.cos(np.pi * np.clip((f - .93) / .07, 0, 1)), 1)[:, None]
    return np.fft.irfft(Y, k, axis=0)[:int(n0 * ratio)] * (k / n)


def band_db(x, sr, t0, t1, f0, f1):
    s = x[int(t0 * sr):int(t1 * sr)]
    if len(s) < 64:
        return -200.0
    P = (np.abs(np.fft.rfft(s * np.hanning(len(s))[:, None], axis=0)) ** 2).sum(1) / len(s) ** 2
    f = np.arange(len(P)) * sr / len(s)
    return 10 * np.log10(P[(f >= f0) & (f < f1)].sum() + 1e-20)


def sustain(x, sr, m):
    """A slow, gentle compressor: the recorded decay is kept at SUSTAIN of its dB, so notes carry on a small speaker.
    The first 25 ms keep their shape; the lift is at most 9 dB and never raises the noise at the end."""
    e = np.sqrt((x ** 2).sum(1))
    k = int(.03 * sr)
    w = np.hanning(2 * k + 1); w /= w.sum()
    env = np.sqrt(np.maximum(ss.fftconvolve(e ** 2, w, mode="same"), 1e-14))
    db = 20 * np.log10(env)
    ref = db[:int(.12 * sr)].max()
    fall = np.maximum(ref - db, 0)
    fall[:int(np.argmax(db[:int(.12 * sr)]))] = 0
    lift = np.minimum(fall * (1 - SUSTAIN), 9.0)
    b = ss.butter(2, 4.0, "lp", fs=sr, output="sos")      # no pumping with the beating
    lift = ss.sosfiltfilt(b, np.concatenate([np.zeros(sr // 4), lift]))[sr // 4:]
    t = np.arange(len(x)) / sr
    lift = np.maximum(lift, 0) * np.clip((t - .005) / .06, 0, 1)
    return x * 10 ** (lift / 20)[:, None]


def two_slopes(y, rate, t0, win, f1, guess):
    """(dB/s from t0, dB/s later, the level between them in dB): a note falls fast, then its strings fall out of step and
    it falls slowly. Two joined lines through the level above the rumble, minus the noise at the recording's end."""
    tot = len(y) / rate
    ts = np.arange(t0, min(tot - win - .7, t0 + (7.0 if m_low(f1) else 4.5)), .08)
    e = lambda t: 10 ** (band_db(y, rate, t, t + win, .6 * f1, min(8 * f1, rate * .45)) / 10)
    floor = e(tot - win - .05)
    v = np.array([e(t) for t in ts])
    ok = v > 3 * floor
    n = int(np.argmin(ok)) if not ok.all() else len(ok)
    if n < 12:
        return guess, guess * .6, -60.0
    t, d = ts[:n] - t0, 10 * np.log10(v[:n] - floor)
    best = None
    for k in t[3:-4]:
        A = np.stack([np.ones(n), t, np.maximum(t - k, 0)], 1)
        c, *_ = np.linalg.lstsq(A, d, rcond=None)
        s1, s2 = -c[1], -(c[1] + c[2])
        if s1 < 1.0 or not .2 * s1 <= s2 <= s1:
            continue
        r = ((A @ c - d) ** 2).sum()
        if best is None or r < best[0]:
            best = (r, s1, s2, -s1 * k)
    if best is None:
        s = float(np.clip(-np.polyfit(t, d, 1)[0], 1.5, 60))
        return s, s, -60.0
    return float(np.clip(best[1], 1.0, 60)), float(np.clip(best[2], .8, 18)), float(np.clip(best[3], -60, -.5))


def m_low(f1):
    return f1 < 260


def prepare(d, m, gain_db):
    x, sr = load(d, m)
    f1 = first_partial(x, sr, m)
    target = hz(m) * 2 ** (tune_cents(m) / 1200)
    x = sustain(soften_phase(x, sr, m), sr, m) * 10 ** (gain_db / 20)
    rate, tatt, tloop = plan(m)
    tl = round(tloop * f1) / f1
    ll = max(128, round(tl * rate / 64) * 64)
    rate = ll / tl                                    # the loop holds whole cycles of the first partial
    y = resample_to(x[:int((tatt + 3 * tl + 8.5) * sr)], rate / sr)
    # join where the note's level is on its trend, not in a dip or a swell of its beating strings
    k = int(max(.05, 2 / f1) * rate)
    lev = 10 * np.log10(ss.fftconvolve((y ** 2).sum(1), np.ones(k) / k, mode="same") + 1e-14)
    hop = 64
    cand = np.arange(round(tatt * .86 * rate / hop) * hop, round(tatt * rate / hop) * hop + 1, hop)
    span = np.arange(int(tatt * .6 * rate), min(len(y) - k, int((tatt * 1.35 + .3) * rate)), hop)
    tr = np.polyfit(span, lev[span], 1)
    dev = np.abs(lev[cand] - np.polyval(tr, cand)) + .8 * (cand[-1] - cand) / rate / tatt
    a = int(cand[int(np.argmin(dev))])
    t0 = a / rate
    # decay after the loop start: a line through each octave band's level; the strongest bands set the loop's decay,
    # the bands above five times the note how much faster its highs fall
    win = max(.3, 4 / f1)
    end = min(len(y) / rate - win - .05, t0 + (6.0 if m < 60 else 3.5 if m < 84 else 1.8))
    ts = np.arange(t0, end, .15)
    rows = []
    for o in range(6):
        lo, hi = f1 * 2 ** (o - .5), f1 * 2 ** (o + .5)
        if hi > rate * .45:
            break
        v = np.array([band_db(y, rate, t, t + win, lo, hi) for t in ts])
        floor = band_db(y, rate, max(0, len(y) / rate - .6), len(y) / rate, lo, hi) + 6
        ok = (v > max(floor, v[0] - 45)) & (v > -105)
        n_ok = int(np.argmin(ok)) if not ok.all() else len(ok)
        if n_ok >= 4:
            rows.append((lo, v[0], -np.polyfit(ts[:n_ok], v[:n_ok], 1)[0]))
    w = np.array([10 ** (r[1] / 20) for r in rows]); sl = np.array([r[2] for r in rows])
    slope = float(np.clip((w * sl).sum() / w.sum(), 1.8, 60.0)) if rows else 25.0
    slope, slow, knee = two_slopes(y, rate, t0, win, f1, slope)
    top = [r for r in rows if r[0] > 2.5 * f1]
    hs = float(np.clip(np.mean([r[2] for r in top]) - slope, 0.0, 10.0)) if top else 0.0
    # the loop: the note's partials, moved to the loop's own harmonics (at most 1/(2 loop) Hz away), in phase at t0
    dur = min(max(tl * 1.6, .35), len(y) / rate - t0 - .05)
    flat = y.copy()
    tt = np.arange(len(y)) / rate - t0
    flat *= np.clip(10 ** (slope * np.clip(tt, -1, None) / 20), 0, 1e4)[:, None]
    pk = partials(flat, rate, t0, dur, f1)
    nb = round(dur * rate)
    tones = {}
    rng = np.random.default_rng(m)
    # phases at t0 from a short window around it; magnitudes from the long one after it
    h = int(min(max(.06, 5 / f1), .16) * rate)
    loc = np.arange(-h, h + 1)
    wl = np.hanning(2 * h + 3)[1:-1]
    seg = flat[a - h:a + h + 1]
    for f, A in pk:
        k = round(f * ll / rate)
        if 0 < k < ll * .46:
            L = (seg * (wl * np.exp(-2j * np.pi * f / rate * loc))[:, None]).sum(0) * 2 / wl.sum()
            A = np.abs(A) * np.exp(1j * np.angle(L))
            tones.setdefault(k, []).append((f, A))
    n = np.arange(-round(.35 * rate), ll)
    syn = np.zeros((len(n), 2))
    for k, parts in tones.items():
        A = sum(q for _, q in parts)
        f = parts[0][0]
        # a slow swell like two strings a little apart: a side line one loop harmonic away
        rho = SWELL * np.exp(2j * np.pi * rng.random(2))
        kk = k + (1 if rng.random() < .5 else -1)
        main = A / (1 + rho)
        c = np.exp(2j * np.pi * k * n / ll)[:, None] * main + np.exp(2j * np.pi * kk * n / ll)[:, None] * (main * rho)
        # before t0 (the crossfade) each partial keeps its own pitch, so it meets the recording in phase
        back = n < 0
        c[back] = np.exp(2j * np.pi * f / rate * n[back])[:, None] * A
        syn += c.real
    xf = min(round(.22 * rate), a // 3)
    lead = -n[0]
    out = np.zeros((a + ll, 2))
    out[:a] = y[:a]
    g = (.5 - .5 * np.cos(np.pi * (np.arange(xf) + .5) / xf))[:, None]
    env = 10 ** (-slope * (np.arange(-xf, 0) / rate) / 20)[:, None]
    out[a - xf:a] = y[a - xf:a] * (1 - g) + syn[lead - xf:lead] * env * g
    out[a:] = syn[lead:]
    return dict(m=m, rate=rate, a=a, ll=ll, f1=f1, target=target, slope=slope, slow=slow, knee=knee, hs=hs, x=out, src=y, n_tones=len(tones))


def decimate2(sig, a, ll):
    """Half-rate copy of sig (attack a, loop ll): its loop is again exactly periodic."""
    reps = 3 + 4096 // ll
    u = np.concatenate([sig] + [sig[a:]] * reps)
    h = ss.firwin(127, .46, window=("kaiser", 8.0))
    v = np.convolve(u, h)[63:63 + len(u)][::2]
    out = v[:(a + ll) // 2].copy()
    la = a // 2
    out[la:] = v[la + ll // 2:la + ll]                # second pass: no memory of the attack
    return out


def train(sig, count=8, order=None, iters=14):
    """`count` predictors for the blocks of sig (LBG on covariance matrices, each block weighted by 1 / its power)."""
    order = order or ORDER
    s = np.concatenate([np.zeros(order), sig])
    nb = len(sig) // BL
    V = np.stack([s[order - k:len(s) - k] for k in range(order + 1)], 1)[:nb * BL].reshape(nb, BL, order + 1)
    R = np.einsum("bni,bnj->bij", V, V)
    pw = R[:, 0, 0] + BL * 4.0
    R = R / pw[:, None, None] + np.eye(order + 1) * 2e-6 * 1.0
    def solve(M):
        return np.linalg.solve(M[1:, 1:] + np.eye(order) * 1e-9, M[1:, 0])
    cb = [solve(R.sum(0))]
    def err(c):
        v = np.concatenate([[1], -c])
        return np.einsum("i,bij,j->b", v, R, v)
    while len(cb) < count:
        cb = [c * g for c in cb for g in (1.0, .985)][:count]
        for _ in range(iters):
            E = np.stack([err(c) for c in cb], 1)
            who = E.argmin(1)
            w = 1 / np.sqrt(E.min(1))
            for i in range(len(cb)):
                sel = who == i
                cb[i] = solve((R[sel] * w[sel, None, None]).sum(0)) if sel.sum() > 3 else cb[int(np.argmax(np.bincount(who)))] * (1 + .01 * np.random.default_rng(i).standard_normal(order))
    q = np.round(np.array(cb) * 4096).astype(int)
    for i in range(len(q)):
        while np.abs(q[i]).sum() > 62000 or np.abs(q[i]).max() > 32767:
            q[i] = np.round(q[i] * .98)
    return q.astype(np.int16)


LIB = None


def codec():
    global LIB
    if LIB is None:
        so = os.path.join(tempfile.mkdtemp(), "adpcm.dylib")
        subprocess.run(["clang", "-O2", "-DORDER=%d" % ORDER, "-shared", "-o", so, os.path.join(HERE, "adpcm.c")], check=True)
        LIB = ctypes.CDLL(so)
    return LIB


def nmr(sig, rec, sr, masker=None):
    """Per 2,048-sample frame: the worst band's noise above a simple masking threshold, dB (<= 0: inaudible)."""
    n = 2048
    f = np.arange(n // 2 + 1) * sr / n
    bark = 13 * np.arctan(.00076 * f) + 3.5 * np.arctan((f / 7500) ** 2)
    B = np.arange(.5, bark[-1], 1.0)
    bands = np.array([(bark >= b - .5) & (bark < b + .5) for b in B], float)
    spread = np.array([[10 ** -(2.5 * max(bs - bt, 0) + 1.2 * max(bt - bs, 0)) for bs in B] for bt in B])
    w = np.hanning(n)
    quiet = (32768 * 10 ** (-92 / 20)) ** 2 * n * n / 32
    out = []
    for i in range(0, len(rec) - n, n):
        P = lambda z: bands @ np.abs(np.fft.rfft(z[i:i + n] * w)) ** 2
        s = P(sig) + (P(masker) if masker is not None else 0)
        thr = np.maximum(spread @ s * 10 ** -1.4, quiet)
        out.append(10 * np.log10((P(sig - rec) + 1e-9) / thr).max())
    return np.array(out) if out else np.zeros(1)


def encode_best(sig, loop_block, sr, masker=None):
    """encode() with the noise shaping that leaves the least audible noise."""
    best = None
    for g in GAMMAS:
        r = encode(sig, loop_block, g)
        q = nmr(sig[:len(r[3])], r[3].astype(float), sr, None if masker is None else masker[:len(r[3])])
        cost = float(np.mean(np.maximum(q, -4) ** 2 * np.sign(np.maximum(q, -4))))
        if best is None or cost < best[0]:
            best = (cost, g, float(np.median(q)), float(np.percentile(q, 95)), r)
    return best


def encode(sig, loop_block, gamma):
    """(stream bytes, predictors, history at the loop start, decoded signal)"""
    nb = len(sig) // BL
    x = np.ascontiguousarray(sig[:nb * BL], float)
    pred = train(x)
    out = np.zeros(nb * BB, np.uint8); rec = np.zeros(nb * BL, np.int16)
    hist = (ctypes.c_int * ORDER)(); hm = (ctypes.c_int * ORDER)()
    sc = np.ascontiguousarray(SCALES, np.int32)
    p = lambda a, t: a.ctypes.data_as(ctypes.POINTER(t))
    r = codec().encode(p(x, ctypes.c_double), nb, ctypes.c_double(gamma), p(pred, ctypes.c_int16), p(sc, ctypes.c_int), hist, loop_block, hm,
                       p(out, ctypes.c_uint8), p(rec, ctypes.c_int16))
    assert r == 0
    return out.tobytes(), pred, list(hm), rec


def fir_tables(psd_mid, psd_side):
    """Interpolation filters, best in the least-squares sense for signals with these spectra (power per bin, 0 .. half
    the stream's rate): for each phase the taps that predict the value between the samples."""
    def table(taps, psd):
        n = len(psd)
        psd = psd / psd.max() + 10 ** (-7.2)
        psd[int(.93 * n):] = 10 ** (-9)                 # nothing is recorded there: let the images go
        f = (np.arange(n) + .5) / n / 2
        rho = lambda t: (psd * np.cos(2 * np.pi * f * t)).sum() / psd.sum()
        k = np.arange(taps)
        R = np.array([[rho(i - j) for j in k] for i in k])
        t = np.array([np.linalg.solve(R, np.array([rho(i - (taps // 2 - 1) - p / PHASES) for i in k])) for p in range(PHASES)])
        t /= t.sum(1, keepdims=True)
        q = np.round(t * 32767)
        assert np.abs(q).max() <= 32767 and np.abs(q).sum(1).max() < 65536
        return q.astype(np.int16)
    return table(TAPS_M, psd_mid), table(TAPS_S, psd_side)


def spectrum(x):
    n = 512
    w = np.hanning(n)
    fr = [np.abs(np.fft.rfft(x[i:i + n] * w)[:-1]) ** 2 for i in range(0, len(x) - n, n // 2)]
    return np.mean(fr, 0)


def level_db(d, m):
    """Loudness of a prepared note's first 0.4 s, A-weighted, both microphones."""
    x, sr = load(d, m)
    x = sustain(soften_phase(x, sr, m), sr, m)
    s = x[:int(.4 * sr)]
    P = (np.abs(np.fft.rfft(s * np.hanning(len(s))[:, None], axis=0)) ** 2).sum(1) / len(s) ** 2
    f = np.arange(len(P)) * sr / len(s) + 1e-9
    A = (12194 ** 2 * f ** 4 / ((f * f + 20.6 ** 2) * np.sqrt((f * f + 107.7 ** 2) * (f * f + 737.9 ** 2)) * (f * f + 12194 ** 2))) ** 2
    return 10 * np.log10((P * A).sum() + 1e-20)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("samples"); ap.add_argument("out")
    ap.add_argument("--report"); ap.add_argument("--previews")
    ap.add_argument("--zones", help="comma list of root notes, for trying things out")
    a = ap.parse_args()
    zones = [int(z) for z in a.zones.split(",")] if a.zones else ZONES
    lv = np.array([level_db(a.samples, m) for m in ZONES])
    u = (np.array(ZONES) - 64) / 44
    fit = np.polyval(np.polyfit(u, lv, 3), u)
    gains = dict(zip(ZONES, fit - lv))
    prep = [prepare(a.samples, m, gains[m]) for m in zones]
    peak = max(np.abs(p["x"]).max() for p in prep)
    report, psd_m, psd_s = [], [], []
    for p in prep:
        M, S = (p["x"][:, 0] + p["x"][:, 1]) / 2, (p["x"][:, 0] - p["x"][:, 1]) / 2
        pk = np.abs(p["x"]).max()                       # left and right, so mid + side never clips
        p["norm"] = pk
        M, S = M / pk * FULL, S / pk * FULL
        Sd = decimate2(S, p["a"], p["ll"])
        psd_m.append(spectrum(M)); psd_s.append(spectrum(Sd))
        Md = decimate2(M, p["a"], p["ll"])
        _, gm, m50, m95, (bm, pm, hm, rm) = encode_best(M, p["a"] // BL, p["rate"])
        _, gs, s50, s95, (bs, ps, hs, rs) = encode_best(Sd, p["a"] // 2 // BL, p["rate"] / 2, Md)
        snr = lambda o, r: 10 * np.log10((o[:len(r)] ** 2).sum() / (((o[:len(r)] - r) ** 2).sum() + 1e-9))
        seg = lambda o, r: float(np.median([snr(o[i:i + 1024], r[i:i + 1024]) for i in range(0, len(r) - 1023, 1024)]))
        p.update(bm=bm, pm=pm, hm=hm, bs=bs, ps=ps, hsd=hs, rm=rm, rs=rs)
        report.append(dict(note=p["m"], rate=round(p["rate"], 2), attack_s=round(p["a"] / p["rate"], 3), loop_s=round(p["ll"] / p["rate"], 3),
                           bytes=len(bm) + len(bs), f1=round(p["f1"], 3), decay_db_s=round(p["slope"], 2), slow_db_s=round(p["slow"], 2), knee_db=round(p["knee"], 1), hf_db_s=round(p["hs"], 2),
                           tones=p["n_tones"], shape=(gm, gs), nmr_mid=(round(m50), round(m95)), nmr_side=(round(s50), round(s95)), snr_mid=round(float(snr(M, rm)), 1), snr_side=round(float(snr(Sd, rs)), 1),
                           norm_db=round(float(20 * np.log10(pk / peak)), 1), level_fix_db=round(float(gains[p["m"]]), 1)))
        print(report[-1], flush=True)
    # ---- the blob ----------------------------------------------------------------------------------------------
    fm, fs = fir_tables(np.mean([q / q.sum() for q in psd_m], 0), np.mean([q / q.sum() for q in psd_s], 0))
    head = 64
    zsize = 192
    off = head + zsize * len(prep) + 128          # zones, then 64 bytes of scales and 64 of padding
    off_fm = off; off += fm.nbytes
    off_fs = off; off += fs.nbytes
    recs, body = [], b""
    for p in prep:
        o = off + len(body)
        # the engine's step, Q16 source frames per output frame, is (pitch word * k) >> 32. Played at its root, the
        # note's first partial (f1 in the stream) must land on `target`, so k = rate / f1 * target / nominal.
        k = p["rate"] / p["f1"] * p["target"] / hz(p["m"]) * 65536
        dec_m = 10 ** (-p["slope"] / 20 * BL / p["rate"])   # per mid block
        z = struct.pack("<8I", p["m"], o, p["a"] // BL, p["ll"] // BL, o + len(p["bm"]), p["a"] // 2 // BL, p["ll"] // 2 // BL, round(k))
        slow = round((1 - 10 ** (-p["slow"] / 20 * BL / p["rate"])) * 2 ** 24)
        assert 0 < slow < 65536
        knee = round(10 ** (p["knee"] / 20) * 32767)
        z += struct.pack("<2I", round(dec_m * 0x7fffffff), knee << 16 | round(p["norm"] / peak * 32767))
        z += struct.pack("<2I", slow << 16 | round(2 * np.pi * 1000 * 65536 / p["rate"]), round((1 - 10 ** (-p["hs"] / 20 * BL / p["rate"])) * 2 ** 31))
        z += struct.pack("<4h", *p["hm"]) + struct.pack("<4h", *p["hsd"])
        z += p["pm"].astype("<i2").tobytes() + p["ps"].astype("<i2").tobytes()
        assert len(z) == 48 + 16 + 128
        recs.append(z)
        body += p["bm"] + p["bs"]
        while len(body) % 4: body += b"\0"
    total = off + len(body)
    table = b"".join(recs)
    scale = struct.pack("<32H", *SCALES)
    pad = b"\0" * (128 - 64)
    mid = table + scale + pad + fm.astype("<i2").tobytes() + fs.astype("<i2").tobytes()
    chk = 0
    for w, in struct.iter_unpack("<I", (table + scale + pad)):
        chk = (chk * 33 + w) & 0xffffffff
    header = struct.pack("<16I", MAGIC, VERSION, total, len(prep), head, head + zsize * len(prep), off_fm, off_fs, chk, *([0] * 7))
    blob = header + mid + body
    assert len(blob) == total
    print("blob", total, "of", BLOB_MAX, "free", BLOB_MAX - total)
    if total > BLOB_MAX:
        sys.exit("too big")
    blob += b"\0" * (-len(blob) % 4096 % 4096)
    blob = blob[:BLOB_MAX]
    pcm = np.frombuffer(blob, "<i2")
    with open(a.out, "wb") as f:
        f.write(opz_samples.build_drum_pack([pcm.tolist()], "piano"))
    info = opz_samples.parse(open(a.out, "rb").read())
    assert not info["errors"], info["errors"]
    if a.report:
        json.dump(dict(total=total, zones=report), open(a.report, "w"), indent=1)
    if a.previews:
        os.makedirs(a.previews, exist_ok=True)
        np.savez(os.path.join(a.previews, "prep.npz"), **{f"src{p['m']}": p["src"] for p in prep}, **{f"x{p['m']}": p["x"] for p in prep})


if __name__ == "__main__":
    main()

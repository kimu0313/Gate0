#!/usr/bin/env python3
"""
gen_sfx.py -- procedural sound effects for GATE 0 (Godot 4.7 prototype).

Pure standard-library Python 3.12 (no numpy / scipy).  Every sound is synthesised
from noise, oscillators, filters and a small feedback-delay-network reverb, then
written as 16-bit PCM mono 44.1 kHz little-endian RIFF WAV into
<project>/assets/audio/sfx/.

Loops (``*_loop.wav``)
    * exactly N samples; periodic material (tones, clacks, beats, LFOs) is rendered
      circularly with periods that divide N, aperiodic noise beds are rendered as
      N + C samples and the last C samples are equal-power crossfaded into the first C.
    * carry a RIFF ``smpl`` chunk with one forward loop (type 0, start 0, end N-1), so
      Godot's WAV importer ("Detect From WAV") loops them automatically.
    * RMS normalised to about -20 dBFS (ambience beds -24 dBFS), peak <= -3 dBFS.

One-shots
    * 2 ms fade-in, short fade-out, 18 Hz DC-blocking high-pass, peak normalised to
      -1 dBFS (a few are deliberately quieter, see ``peak_db`` in the registry).

Every sound uses a fixed random seed (CRC32 of its name) so output is deterministic.

Usage (from the project root):
    py -I tools\\gen_sfx.py                 generate everything, then verify + print table
    py -I tools\\gen_sfx.py chime belt      only sounds whose name contains a filter word
    py -I tools\\gen_sfx.py --verify        only verify the files already on disk
    py -I tools\\gen_sfx.py -j 1            disable the process pool (serial run)
"""

import cmath
import math
import operator
import os
import random
import struct
import sys
import time
import zlib
from array import array
from itertools import accumulate, repeat

SR = 44100
PI = math.pi
TAU = 2.0 * math.pi
_sin = math.sin
_cos = math.cos
_exp = math.exp
_tanh = math.tanh

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT_DIR = os.path.join(ROOT, "assets", "audio", "sfx")


# =============================================================================
# basic helpers
# =============================================================================

def ns(sec):
    """seconds -> samples"""
    return int(round(sec * SR))


def db(v):
    return 10.0 ** (v / 20.0)


def lin2db(v):
    return 20.0 * math.log10(v) if v > 0 else -999.0


def mtof(m):
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


def zeros(n):
    return [0.0] * n


def addv(a, b, g=1.0):
    if g == 1.0:
        return [x + y for x, y in zip(a, b)]
    return [x + g * y for x, y in zip(a, b)]


def mul(a, b):
    return [x * y for x, y in zip(a, b)]


def scale(a, g):
    return [g * x for x in a]


def peak(x):
    return max(max(x), -min(x)) if x else 0.0


def rms(x):
    return math.sqrt(sum(map(operator.mul, x, x)) / len(x)) if x else 0.0


def nrm(x, target=1.0):
    """peak-normalise"""
    p = peak(x)
    if p <= 0.0:
        return list(x)
    g = target / p
    return [v * g for v in x]


def nrm_rms(x, target=1.0):
    r = rms(x)
    if r <= 0.0:
        return list(x)
    g = target / r
    return [v * g for v in x]


def sat(x, drive=2.0):
    """tanh soft clip, unity gain for full-scale input"""
    t = _tanh
    k = 1.0 / _tanh(drive)
    return [t(drive * v) * k for v in x]


def smoothstep(u):
    if u <= 0.0:
        return 0.0
    if u >= 1.0:
        return 1.0
    return u * u * (3.0 - 2.0 * u)


def mix(dst, src, start=0, g=1.0):
    """add src*g into dst at sample offset start (in place, clipped to dst)"""
    if start < 0:
        src = src[-start:]
        start = 0
    end = min(len(dst), start + len(src))
    if end <= start:
        return dst
    seg = dst[start:end]
    if g == 1.0:
        dst[start:end] = [a + b for a, b in zip(seg, src)]
    else:
        dst[start:end] = [a + g * b for a, b in zip(seg, src)]
    return dst


def mix_circ(dst, src, start, g=1.0):
    """add src*g into the circular buffer dst (wraps around the end)"""
    n = len(dst)
    start %= n
    pos = 0
    total = len(src)
    while pos < total:
        seg = min(total - pos, n - start)
        part = src[pos:pos + seg]
        dst[start:start + seg] = [a + g * b for a, b in zip(dst[start:start + seg], part)]
        pos += seg
        start = 0
    return dst


def fade_in(x, sec):
    m = min(len(x), ns(sec))
    if m > 0:
        x[:m] = [v * (0.5 - 0.5 * _cos(PI * i / m)) for i, v in enumerate(x[:m])]
    return x


def fade_out(x, sec):
    m = min(len(x), ns(sec))
    if m > 0:
        n = len(x)
        x[n - m:] = [v * (0.5 + 0.5 * _cos(PI * (i + 1) / m)) for i, v in enumerate(x[n - m:])]
    return x


def fit(x, n):
    """pad / truncate to n samples"""
    if len(x) >= n:
        return x[:n]
    return x + [0.0] * (n - len(x))


# =============================================================================
# noise
# =============================================================================

def white(n, rng):
    r = rng.random
    return [r() * 2.0 - 1.0 for _ in range(n)]


def pink(n, rng):
    """Paul Kellet's refined pink noise filter"""
    r = rng.random
    out = [0.0] * n
    b0 = b1 = b2 = b3 = b4 = b5 = b6 = 0.0
    for i in range(n):
        w = r() * 2.0 - 1.0
        b0 = 0.99886 * b0 + w * 0.0555179
        b1 = 0.99332 * b1 + w * 0.0750759
        b2 = 0.96900 * b2 + w * 0.1538520
        b3 = 0.86650 * b3 + w * 0.3104856
        b4 = 0.55000 * b4 + w * 0.5329522
        b5 = -0.7616 * b5 - w * 0.0168980
        out[i] = (b0 + b1 + b2 + b3 + b4 + b5 + b6 + w * 0.5362) * 0.2
        b6 = w * 0.115926
    return out


def brown(n, rng, leak=0.996):
    """leaky-integrated white noise (corner ~28 Hz)"""
    r = rng.random
    out = [0.0] * n
    b = 0.0
    for i in range(n):
        b = b * leak + (r() * 2.0 - 1.0) * 0.12
        out[i] = b
    return out


def smooth_rand(n, npts, rng, periodic=False):
    """smooth random control signal in [-1, 1] (cosine-interpolated random points)"""
    pts = [rng.uniform(-1.0, 1.0) for _ in range(npts + 1)]
    if periodic:
        pts[-1] = pts[0]
    out = [0.0] * n
    seg = n / float(npts)
    for k in range(npts):
        i0 = int(round(k * seg))
        i1 = n if k == npts - 1 else int(round((k + 1) * seg))
        m = i1 - i0
        if m <= 0:
            continue
        a = pts[k]
        d = pts[k + 1] - a
        c = PI / m
        out[i0:i1] = [a + d * (0.5 - 0.5 * _cos(c * j)) for j in range(m)]
    return out


# =============================================================================
# filters
# =============================================================================

def bq_coefs(kind, f0, q=0.7071, gain_db=0.0):
    """RBJ audio-EQ-cookbook biquad coefficients (b0, b1, b2, a1, a2), a0-normalised"""
    f0 = min(max(f0, 1.0), SR * 0.49)
    w0 = TAU * f0 / SR
    cw = _cos(w0)
    sw = _sin(w0)
    alpha = sw / (2.0 * q)
    A = 10.0 ** (gain_db / 40.0)
    if kind == "lp":
        b0 = (1 - cw) / 2; b1 = 1 - cw; b2 = b0
        a0 = 1 + alpha; a1 = -2 * cw; a2 = 1 - alpha
    elif kind == "hp":
        b0 = (1 + cw) / 2; b1 = -(1 + cw); b2 = b0
        a0 = 1 + alpha; a1 = -2 * cw; a2 = 1 - alpha
    elif kind == "bp":  # constant 0 dB peak gain
        b0 = alpha; b1 = 0.0; b2 = -alpha
        a0 = 1 + alpha; a1 = -2 * cw; a2 = 1 - alpha
    elif kind == "notch":
        b0 = 1.0; b1 = -2 * cw; b2 = 1.0
        a0 = 1 + alpha; a1 = -2 * cw; a2 = 1 - alpha
    elif kind == "peak":
        b0 = 1 + alpha * A; b1 = -2 * cw; b2 = 1 - alpha * A
        a0 = 1 + alpha / A; a1 = -2 * cw; a2 = 1 - alpha / A
    elif kind == "ls":
        sq = 2.0 * math.sqrt(A) * alpha
        b0 = A * ((A + 1) - (A - 1) * cw + sq)
        b1 = 2 * A * ((A - 1) - (A + 1) * cw)
        b2 = A * ((A + 1) - (A - 1) * cw - sq)
        a0 = (A + 1) + (A - 1) * cw + sq
        a1 = -2 * ((A - 1) + (A + 1) * cw)
        a2 = (A + 1) + (A - 1) * cw - sq
    elif kind == "hs":
        sq = 2.0 * math.sqrt(A) * alpha
        b0 = A * ((A + 1) + (A - 1) * cw + sq)
        b1 = -2 * A * ((A - 1) + (A + 1) * cw)
        b2 = A * ((A + 1) + (A - 1) * cw - sq)
        a0 = (A + 1) - (A - 1) * cw + sq
        a1 = 2 * ((A - 1) - (A + 1) * cw)
        a2 = (A + 1) - (A - 1) * cw - sq
    else:
        raise ValueError(kind)
    return (b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0)


def biquad(x, kind, f0, q=0.7071, gain_db=0.0):
    b0, b1, b2, a1, a2 = bq_coefs(kind, f0, q, gain_db)
    y = [0.0] * len(x)
    z1 = z2 = 0.0
    i = 0
    for v in x:
        o = b0 * v + z1
        z1 = b1 * v - a1 * o + z2
        z2 = b2 * v - a2 * o
        y[i] = o
        i += 1
    return y


def lp(x, f, q=0.7071):
    return biquad(x, "lp", f, q)


def hp(x, f, q=0.7071):
    return biquad(x, "hp", f, q)


def bp(x, f, q=1.0):
    return biquad(x, "bp", f, q)


def peq(x, f, q, g):
    return biquad(x, "peak", f, q, g)


def band(x, lo, hi, order=2):
    for _ in range(order):
        x = hp(x, lo)
    for _ in range(order):
        x = lp(x, hi)
    return x


def lp1(x, fc):
    a = 1.0 - _exp(-TAU * fc / SR)
    y = 0.0
    out = [0.0] * len(x)
    i = 0
    for v in x:
        y += a * (v - y)
        out[i] = y
        i += 1
    return out


def svf(x, fc, q=0.7071, mode="lp", block=16):
    """Simper/Zavalishin TPT state-variable filter.  fc: Hz (number) or per-sample list
    (read once per block -> cheap modulation).  mode: lp | bp (unity peak) | hp"""
    n = len(x)
    out = [0.0] * n
    k = 1.0 / q
    ic1 = ic2 = 0.0
    seq = not isinstance(fc, (int, float))
    if not seq:
        block = max(n, 1)
    lim = SR * 0.45
    tn = math.tan
    i0 = 0
    while i0 < n:
        i1 = min(n, i0 + block)
        f = fc[i0] if seq else fc
        if f < 10.0:
            f = 10.0
        elif f > lim:
            f = lim
        g = tn(PI * f / SR)
        a1 = 1.0 / (1.0 + g * (g + k))
        a2 = g * a1
        a3 = g * a2
        if mode == "lp":
            for i in range(i0, i1):
                v3 = x[i] - ic2
                v1 = a1 * ic1 + a2 * v3
                v2 = ic2 + a2 * ic1 + a3 * v3
                ic1 = 2.0 * v1 - ic1
                ic2 = 2.0 * v2 - ic2
                out[i] = v2
        elif mode == "bp":
            for i in range(i0, i1):
                v3 = x[i] - ic2
                v1 = a1 * ic1 + a2 * v3
                v2 = ic2 + a2 * ic1 + a3 * v3
                ic1 = 2.0 * v1 - ic1
                ic2 = 2.0 * v2 - ic2
                out[i] = k * v1
        else:
            for i in range(i0, i1):
                xi = x[i]
                v3 = xi - ic2
                v1 = a1 * ic1 + a2 * v3
                v2 = ic2 + a2 * ic1 + a3 * v3
                ic1 = 2.0 * v1 - ic1
                ic2 = 2.0 * v2 - ic2
                out[i] = xi - k * v1 - v2
        i0 = i1
    return out


def allpass(x, d, g):
    buf = [0.0] * d
    p = 0
    y = [0.0] * len(x)
    i = 0
    for v in x:
        wd = buf[p]
        w = v + g * wd
        y[i] = wd - g * w
        buf[p] = w
        p += 1
        if p == d:
            p = 0
        i += 1
    return y


_FDN = (1031, 1171, 1303, 1429, 1559, 1693, 1811, 1949)


def reverb(x, rt60=1.5, size=1.0, damp=6000.0, predelay=0.0, diffuse=True):
    """8-line feedback delay network (Hadamard mix, one-pole damping per line) with
    4 Schroeder allpass input diffusers.  Returns the wet signal only, same length as x,
    scaled so the impulse response has roughly unit energy (wet gain ~ wet/dry power)."""
    n = len(x)
    pd = ns(predelay)
    inp = ([0.0] * pd + list(x))[:n]
    if diffuse:
        for dl, g in ((142, 0.62), (107, 0.62), (379, 0.55), (277, 0.55)):
            inp = allpass(inp, max(3, int(dl * size)), g)
    d = [max(37, int(v * size)) for v in _FDN]
    h = 0.35355339059327373  # 1/sqrt(8): orthonormal Hadamard
    gs = [h * 10.0 ** (-3.0 * di / (rt60 * SR)) for di in d]
    a = 1.0 - _exp(-TAU * damp / SR)
    nrm_ = 1.0 / math.sqrt(64.0 * rt60 * SR / (13.8155 * float(sum(d))))
    d0, d1, d2, d3, d4, d5, d6, d7 = d
    g0, g1, g2, g3, g4, g5, g6, g7 = gs
    B0 = [0.0] * d0; B1 = [0.0] * d1; B2 = [0.0] * d2; B3 = [0.0] * d3
    B4 = [0.0] * d4; B5 = [0.0] * d5; B6 = [0.0] * d6; B7 = [0.0] * d7
    p0 = p1 = p2 = p3 = p4 = p5 = p6 = p7 = 0
    s0 = s1 = s2 = s3 = s4 = s5 = s6 = s7 = 0.0
    out = [0.0] * n
    for i in range(n):
        xin = inp[i]
        s0 += a * (B0[p0] - s0)
        s1 += a * (B1[p1] - s1)
        s2 += a * (B2[p2] - s2)
        s3 += a * (B3[p3] - s3)
        s4 += a * (B4[p4] - s4)
        s5 += a * (B5[p5] - s5)
        s6 += a * (B6[p6] - s6)
        s7 += a * (B7[p7] - s7)
        out[i] = s0 - s1 + s2 - s3 + s4 - s5 + s6 - s7
        h0 = s0 + s1; h1 = s0 - s1; h2 = s2 + s3; h3 = s2 - s3
        h4 = s4 + s5; h5 = s4 - s5; h6 = s6 + s7; h7 = s6 - s7
        k0 = h0 + h2; k2 = h0 - h2; k1 = h1 + h3; k3 = h1 - h3
        k4 = h4 + h6; k6 = h4 - h6; k5 = h5 + h7; k7 = h5 - h7
        B0[p0] = g0 * (k0 + k4) + xin
        B1[p1] = g1 * (k1 + k5) - xin
        B2[p2] = g2 * (k2 + k6) + xin
        B3[p3] = g3 * (k3 + k7) - xin
        B4[p4] = g4 * (k0 - k4) + xin
        B5[p5] = g5 * (k1 - k5) - xin
        B6[p6] = g6 * (k2 - k6) + xin
        B7[p7] = g7 * (k3 - k7) - xin
        p0 += 1
        if p0 == d0:
            p0 = 0
        p1 += 1
        if p1 == d1:
            p1 = 0
        p2 += 1
        if p2 == d2:
            p2 = 0
        p3 += 1
        if p3 == d3:
            p3 = 0
        p4 += 1
        if p4 == d4:
            p4 = 0
        p5 += 1
        if p5 == d5:
            p5 = 0
        p6 += 1
        if p6 == d6:
            p6 = 0
        p7 += 1
        if p7 == d7:
            p7 = 0
    return [v * nrm_ for v in out]


def verb(x, wet, dry=1.0, **kw):
    w = reverb(x, **kw)
    return [dry * a + wet * b for a, b in zip(x, w)]


# =============================================================================
# oscillators / envelopes / building blocks
# =============================================================================

def dsine(n, f, amp=1.0, tau=None, phase=0.0):
    """(exponentially damped) sine by complex rotation -- runs in C via accumulate"""
    if n <= 0:
        return []
    if f >= SR * 0.48:
        return [0.0] * n
    dec = -1.0 / (tau * SR) if tau else 0.0
    r = cmath.exp(complex(dec, TAU * f / SR))
    z0 = amp * cmath.exp(1j * phase)
    return [z.imag for z in accumulate(repeat(r, n - 1), operator.mul, initial=z0)]


def env_exp(n, tau, amp=1.0):
    if n <= 0:
        return []
    k = _exp(-1.0 / (tau * SR))
    return list(accumulate(repeat(k, n - 1), operator.mul, initial=amp))


def env_pts(n, pts):
    """piecewise-linear envelope through [(t_sec, value), ...]; holds the end values"""
    out = [0.0] * n
    pts = sorted(pts)
    i_first = min(n, max(0, ns(pts[0][0])))
    out[:i_first] = [pts[0][1]] * i_first
    for (t0, v0), (t1, v1) in zip(pts, pts[1:]):
        i0 = ns(t0)
        i1 = ns(t1)
        if i1 <= i0:
            continue
        a = max(0, i0)
        b = min(n, i1)
        if b <= a:
            continue
        sl = (v1 - v0) / (i1 - i0)
        out[a:b] = [v0 + sl * (i - i0) for i in range(a, b)]
    i_last = ns(pts[-1][0])
    if i_last < n:
        i_last = max(0, i_last)
        out[i_last:] = [pts[-1][1]] * (n - i_last)
    return out


def phases(freqs, phase=0.0):
    k = TAU / SR
    ph = list(accumulate((f * k for f in freqs), initial=phase))
    ph.pop()
    return ph


def osc(freqs, phase=0.0):
    return [_sin(p) for p in phases(freqs, phase)]


def lfo(n, terms, base=0.0):
    """periodic control: base + sum(a*sin(2*pi*cycles*i/n + ph)); integer cycles -> seamless"""
    out = [base] * n
    for amp, cycles, ph in terms:
        w = TAU * cycles / n
        out = [o + amp * _sin(w * i + ph) for i, o in enumerate(out)]
    return out


def psine(n, f, phase=0.0, amp=1.0):
    w = TAU * f / SR
    return [amp * _sin(w * i + phase) for i in range(n)]


def saw_sum(n, freqs, rng):
    """sum of naive saws (fine for low / low-passed material), zero-mean-ish"""
    out = [0.0] * n
    for f in freqs:
        k = f / SR
        p = rng.random()
        out = [o + ((p + k * i) % 1.0) for i, o in enumerate(out)]
    off = 0.5 * len(freqs)
    return [2.0 * (o - off) for o in out]


def saw_var(freqs, phase=0.0):
    ph = list(accumulate((f / SR for f in freqs), initial=phase))
    ph.pop()
    return [2.0 * (p % 1.0) - 1.0 for p in ph]


def _blep(t, dt):
    if t < dt:
        t /= dt
        return t + t - t * t - 1.0
    if t > 1.0 - dt:
        t = (t - 1.0) / dt
        return t * t + t + t + 1.0
    return 0.0


def square_blep(n, f, phase=0.0):
    dt = f / SR
    out = [0.0] * n
    ph = phase
    bl = _blep
    for i in range(n):
        v = 1.0 if ph < 0.5 else -1.0
        v += bl(ph, dt)
        v -= bl((ph + 0.5) % 1.0, dt)
        out[i] = v
        ph += dt
        if ph >= 1.0:
            ph -= 1.0
    return out


def rsquare(n, f, drive=2.5, phase=0.0):
    """rounded square: tanh of a sine"""
    w = TAU * f / SR
    k = 1.0 / _tanh(drive)
    t = _tanh
    return [t(drive * _sin(w * i + phase)) * k for i in range(n)]


def burst(n, rng, tau, lo=None, hi=None):
    """white-noise burst with exponential decay, optionally band-limited"""
    x = mul(white(n, rng), env_exp(n, tau))
    if lo:
        x = hp(x, lo)
    if hi:
        x = lp(x, hi)
    return x


def thump(n, f_start, f_end, drop_tau, tau, attack=0.002):
    """sine with exponential pitch drop and exponential decay"""
    fr = [f_end + (f_start - f_end) * e for e in env_exp(n, drop_tau)]
    x = mul(osc(fr), env_exp(n, tau))
    return fade_in(x, attack)


def modes(n, freqs, amps, taus, rng=None, attack=0.0003):
    """sum of damped sinusoids (modal / struck-object synthesis)"""
    out = [0.0] * n
    for f, a, t in zip(freqs, amps, taus):
        if a == 0.0 or f >= SR * 0.47:
            continue
        ph = rng.random() * TAU if rng is not None else 0.0
        out = addv(out, dsine(n, f, a, t, ph))
    return fade_in(out, attack)


def click(rng, n=None, tau=0.0005, lo=1500.0, hi=None):
    n = n or ns(0.006)
    return burst(n, rng, tau, lo, hi)


def circ(x, fn, pre):
    """apply a (stateful) process circularly to a periodic buffer: run it over a
    pre-roll taken from the end of the buffer, return the last len(x) samples"""
    n = len(x)
    reps = pre // n + 2
    ext = (x * reps)[-(pre + n):]
    y = fn(ext)
    return y[pre:pre + n]


def per(n, length, pre, arr):
    """extend periodic control arr (len n) to `length` samples that start `pre` samples
    before loop position 0"""
    return [arr[(i - pre) % n] for i in range(length)]


def xfade_loop(x, n, c):
    """x has n + c samples: equal-power crossfade of the overhang into the start."""
    if len(x) < n + c:
        raise ValueError("xfade_loop: buffer too short")
    y = x[:n]
    if c > 0:
        k = 0.5 * PI / c
        for i in range(c):
            y[i] = x[i] * _sin(k * i) + x[n + i] * _cos(k * i)
    return y


def trem(x, rate, depth, phase=0.0):
    w = TAU * rate / SR
    return [v * (1.0 - depth * (0.5 - 0.5 * _cos(w * i + phase))) for i, v in enumerate(x)]


def crush(x, bits, hold):
    """bit-depth + sample-rate reduction"""
    q = float(2 ** (bits - 1))
    out = [0.0] * len(x)
    v = 0.0
    for i, s in enumerate(x):
        if i % hold == 0:
            v = round(s * q) / q
        out[i] = v
    return out


# --------------------------------------------------------------- shared timbres

BELL_PARTIALS = ((1.0, 1.0, 1.0), (2.0, 0.08, 0.45), (2.76, 0.30, 0.20),
                 (5.40, 0.13, 0.08), (8.93, 0.045, 0.04))


def bell(n, f, rng, decay=1.4, bright=1.0, fmul=None, strike=0.05):
    """soft vibraphone-ish chime bar: partials 1, 2, 2.76, 5.4, 8.93 with faster
    decays for the upper partials and a soft mallet click.  fmul: optional
    per-sample frequency multiplier (bends / tape wow)."""
    out = [0.0] * n
    if fmul is None:
        for r, a, td in BELL_PARTIALS:
            if f * r > 17000:
                continue
            g = a * (bright if r > 1.0 else 1.0)
            out = addv(out, dsine(n, f * r, g, decay * td))
    else:
        ph = phases([f * m for m in fit(fmul, n)])
        for r, a, td in BELL_PARTIALS:
            if f * r > 17000:
                continue
            g = a * (bright if r > 1.0 else 1.0)
            e = env_exp(n, decay * td, g)
            out = [o + ee * _sin(r * p) for o, ee, p in zip(out, e, ph)]
    if strike:
        c = lp(burst(ns(0.012), rng, 0.0012), 2500.0)
        mix(out, c, 0, strike * bright)
    return fade_in(out, 0.003)


def radio_fx(x, drive=2.2, lo=300.0, hi=3000.0):
    """walkie-talkie colouring: 300-3000 Hz band, presence bump, tanh drive"""
    x = hp(hp(x, lo), lo)
    x = peq(x, 1700.0, 1.0, 3.0)
    x = sat(nrm(x), drive)
    x = lp(lp(x, hi), hi)
    return x


def relay_clunk(rng, big=1.0):
    n = ns(0.3)
    out = zeros(n)
    mix(out, click(rng, tau=0.0005, lo=2000.0), 0, 0.8)
    mix(out, modes(ns(0.12), [2650, 3900, 5300, 1450], [0.3, 0.2, 0.1, 0.25],
                   [0.02, 0.015, 0.01, 0.03], rng), 0)
    mix(out, thump(ns(0.25), 130.0, 68.0, 0.015, 0.05 * big, 0.001), ns(0.003), 0.9 * big)
    mix(out, burst(ns(0.06), rng, 0.008, 200.0, 1200.0), ns(0.002), 0.5)
    return out


# =============================================================================
# registry
# =============================================================================

REG = []


def reg(name, dur, loop=False, peak_db=-1.0, rms_db=-20.0, fade_out=0.012):
    def deco(fn):
        REG.append(dict(name=name, dur=dur, loop=loop, peak_db=peak_db, rms_db=rms_db,
                        fade_out=fade_out, fn=fn, seed=zlib.crc32(name.encode("ascii"))))
        return fn
    return deco


# =============================================================================
# LOOPS
# =============================================================================

@reg("amb_night_loop", 12.0, loop=True, rms_db=-24.0)
def s_amb_night(rng):
    N, C, P = ns(12.0), ns(2.0), 8192
    L = P + N + C
    rum = brown(L, rng)
    rum = hp(rum, 24.0)
    rum = lp(rum, 180.0, 0.6)
    rum = peq(rum, 48.0, 2.0, 3.0)     # big-hall room modes
    rum = peq(rum, 96.0, 2.5, 2.0)
    rum = nrm_rms(xfade_loop(rum[P:], N, C))
    hiss = band(pink(L, rng), 400.0, 1500.0)
    hiss = nrm_rms(xfade_loop(hiss[P:], N, C), db(-12.5))
    swell = lfo(N, [(0.16, 1, 0.4), (0.06, 2, 2.1)], 0.80)       # 12 s + 6 s periods
    hmod = lfo(N, [(0.20, 1, 2.5), (0.07, 3, 1.0)], 0.85)
    w = TAU * 60.0 / SR
    hum = [_sin(w * i) + 0.7 * _sin(2 * w * i + 0.6) + 0.15 * _sin(3 * w * i + 1.9) for i in range(N)]
    hum = mul(nrm_rms(hum, db(-28.0)), lfo(N, [(0.15, 2, 0.0)], 1.0))
    return [r * s + h * m + u for r, s, h, m, u in zip(rum, swell, hiss, hmod, hum)]


@reg("amb_day_loop", 12.0, loop=True, rms_db=-24.0)
def s_amb_day(rng):
    N, C, P = ns(12.0), ns(2.0), 8192
    L = P + N + C
    room = pink(L, rng)
    room = lp(lp(hp(room, 70.0), 2500.0), 2500.0)
    room = nrm_rms(xfade_loop(room[P:], N, C))
    hv = lp(bp(pink(L, rng), 380.0, 0.7), 1100.0)
    hv = nrm_rms(xfade_loop(hv[P:], N, C), db(-3.0))
    hvm = lfo(N, [(0.18, 1, 1.1), (0.08, 2, 0.3), (0.04, 6, 2.0)], 0.85)
    rb = lp(hp(brown(L, rng), 40.0), 180.0)
    rb = nrm_rms(xfade_loop(rb[P:], N, C), db(-8.0))
    # very faint, diffuse "distant activity" murmur (formant-coloured noise)
    mm = pink(L, rng)
    mm = addv(addv(bp(mm, 520.0, 3.0), bp(mm, 1350.0, 3.5), 0.6), bp(mm, 2550.0, 4.0), 0.3)
    mm = lp(mm, 2200.0)
    mm = nrm_rms(xfade_loop(mm[P:], N, C), db(-21.0))
    r1 = smooth_rand(N, 60, rng, True)
    r2 = smooth_rand(N, 84, rng, True)
    r3 = smooth_rand(N, 108, rng, True)
    mmod = [max(0.0, 0.6 + 0.2 * a + 0.17 * b + 0.14 * c) for a, b, c in zip(r1, r2, r3)]
    w = TAU * 60.0 / SR
    hum = nrm_rms([_sin(w * i) + 0.5 * _sin(2 * w * i + 0.6) for i in range(N)], db(-34.0))
    return [a + b * c + d + e * f + g for a, b, c, d, e, f, g in zip(room, hv, hvm, rb, mm, mmod, hum)]


@reg("hum_light_loop", 2.0, loop=True)
def s_hum_light(rng):
    N, C, P = ns(2.0), ns(0.25), 4096
    L = P + N + C
    jit = smooth_rand(N, 26, rng, True)
    w = TAU * 120.0 / SR
    ph = [w * i + 0.035 * j for i, j in enumerate(jit)]
    tone = []
    ap = tone.append
    for p in ph:
        s = _sin(p)
        ap(0.35 * s + 0.55 * ((s if s > 0.0 else 0.0) - 0.3183)
           + 0.22 * _tanh(2.8 * _sin(p + 0.35)) + 0.05 * _sin(3.0 * p + 1.0))
    aj = smooth_rand(N, 18, rng, True)
    tone = [t * (1.0 + 0.05 * a) for t, a in zip(tone, aj)]
    tone = circ(tone, lambda v: peq(lp(v, 3200.0, 0.7), 1100.0, 1.2, 3.0), 4096)
    tone = nrm_rms(tone)
    pulse = [max(_sin(p), 0.0) ** 6 for p in ph]
    nz = mul(white(L, rng), per(N, L, P, pulse))
    nz = lp(hp(nz, 2500.0), 7000.0)
    nz = nrm_rms(xfade_loop(nz[P:], N, C), db(-17.0))
    return addv(tone, nz)


@reg("machine_hum_loop", 3.0, loop=True)
def s_machine_hum(rng):
    N, C, P = ns(3.0), ns(0.3), 4096
    L = P + N + C
    tone = zeros(N)
    for f, a in ((50, 0.45), (100, 1.0), (150, 0.22), (200, 0.32), (300, 0.10),
                 (400, 0.05), (500, 0.03), (600, 0.02)):
        w = TAU * f / SR
        p0 = rng.random() * TAU
        tone = [t + a * _sin(w * i + p0) for i, t in enumerate(tone)]
    tone = nrm_rms(sat(nrm(tone), 1.3))
    wm = lfo(N, [(0.35, 1, 0.0), (0.15, 3, 1.0)], 1.0)
    w = TAU * 7800.0 / SR
    whine = nrm_rms([_sin(w * i) * m for i, m in enumerate(wm)], db(-31.0))
    fan = lp(hp(pink(L, rng), 120.0), 900.0)
    fan = nrm_rms(xfade_loop(fan[P:], N, C), db(-17.0))
    return [a + b + c for a, b, c in zip(tone, whine, fan)]


def _clack(rng, sc):
    n = ns(0.11)
    ev = modes(n, [870 * sc, 1650 * sc, 2480 * sc, 3720 * sc, 5130 * sc],
               [0.30, 0.50, 0.40, 0.28, 0.14], [0.018, 0.022, 0.016, 0.011, 0.007], rng)
    mix(ev, hp(burst(ns(0.01), rng, 0.0008), 1500.0), 0, 0.9)
    mix(ev, thump(ns(0.08), 170.0, 120.0, 0.01, 0.02), 0, 0.6)
    s2 = sc * 1.035
    ev2 = modes(ns(0.07), [1650 * s2, 2480 * s2, 3720 * s2], [0.35, 0.3, 0.2], [0.015, 0.011, 0.008], rng)
    mix(ev2, hp(burst(ns(0.006), rng, 0.0006), 1800.0), 0, 0.6)
    mix(ev, ev2, ns(0.032), 0.45)
    return ev


@reg("belt_loop", 4.0, loop=True)
def s_belt(rng):
    N, C, P = ns(4.0), ns(0.5), 8192
    L = P + N + C
    k1, k2 = 90.0 / SR, 90.25 / SR            # 360 and 361 cycles per loop
    dr = [((k1 * i) % 1.0) * 1.2 + ((k2 * i + 0.37) % 1.0) * 0.8 for i in range(N)]
    dr = circ(dr, lambda v: lp(lp(v, 380.0, 0.9), 600.0), 4096)
    dr = nrm_rms([v - 1.0 for v in dr])
    w45 = TAU * 45.0 / SR
    wob = lfo(N, [(0.08, 2, 0.0), (0.03, 8, 1.3)], 1.0)
    drone = [(a + 0.35 * _sin(w45 * i)) * m for i, (a, m) in enumerate(zip(dr, wob))]
    rb = white(L, rng)
    rb = addv(lp(lp(rb, 260.0), 260.0), bp(rb, 700.0, 0.8), 0.15)
    rb = nrm_rms(xfade_loop(rb[P:], N, C), db(-5.0))
    rm = lfo(N, [(0.12, 32, 0.0)], 1.0)                      # 8 Hz roller flutter
    clk = zeros(N)
    for k in range(8):                                       # every 0.5 s
        t = 0.1 + 0.5 * k + rng.uniform(-0.004, 0.004)
        mix_circ(clk, _clack(rng, rng.uniform(0.93, 1.07)), ns(t), rng.uniform(0.75, 1.0))
    clk = nrm(clk, 4.0)
    return [a + b * m + c for a, b, m, c in zip(drone, rb, rm, clk)]


@reg("walkway_loop", 4.0, loop=True)
def s_walkway(rng):
    N, C, P = ns(4.0), ns(0.5), 8192
    L = P + N + C
    hum = zeros(N)
    for f, a in ((35, 0.22), (70, 1.0), (140, 0.33), (210, 0.12), (280, 0.06), (350, 0.025)):
        w = TAU * f / SR
        p0 = rng.random() * TAU
        hum = [t + a * _sin(w * i + p0) for i, t in enumerate(hum)]
    hum = nrm_rms(sat(nrm(hum), 1.2))
    gm = lfo(N, [(0.5, 4, 0.0)], 1.0)
    gw = TAU * 630.0 / SR
    gear = nrm_rms([_sin(gw * i) * m for i, m in enumerate(gm)], db(-30.0))
    rum = lp(bp(pink(L, rng), 300.0, 0.6), 900.0)
    rum = nrm_rms(xfade_loop(rum[P:], N, C), db(-9.0))
    hr = bp(white(L, rng), 2200.0, 1.5)
    hr = nrm_rms(xfade_loop(hr[P:], N, C), db(-27.0))
    rat = zeros(N)
    pattern = (1.0, 0.6, 0.85, 0.55)
    for k in range(16):                                      # every 0.25 s
        t = 0.05 + 0.25 * k + rng.uniform(-0.003, 0.003)
        sc = rng.uniform(0.92, 1.08)
        n = ns(0.06)
        ev = scale(burst(n, rng, 0.003, 700.0, 2600.0), 0.6)
        mix(ev, modes(n, [1150 * sc, 1730 * sc, 2390 * sc], [0.3, 0.2, 0.1], [0.012, 0.009, 0.006], rng))
        mix(ev, thump(n, 150.0, 110.0, 0.006, 0.012), 0, 0.4)
        for dt, a in ((0.007, 0.3), (0.015, 0.15)):
            mix(ev, click(rng, ns(0.004), 0.0005, 1200.0), ns(dt), a)
        mix_circ(rat, ev, ns(t), pattern[k % 4] * rng.uniform(0.85, 1.0))
    rat = nrm(rat, 1.1)
    return [a + b + c + d + e for a, b, c, d, e in zip(hum, gear, rum, hr, rat)]


@reg("xray_loop", 3.0, loop=True)
def s_xray(rng):
    N, C, P = ns(3.0), ns(0.4), 8192
    L = P + N + C
    w = white(L, rng)
    fan = addv(bp(w, 600.0, 1.3), lp(hp(w, 200.0), 2000.0), 0.35)
    fan = nrm_rms(xfade_loop(fan[P:], N, C))
    fan = mul(fan, lfo(N, [(0.18, 108, 0.0), (0.06, 216, 1.0)], 1.0))   # 36 Hz blade AM
    blade = psine(N, 216.0, 0.0, 1.0)
    blade = nrm_rms(mul(blade, lfo(N, [(0.3, 3, 0.5)], 1.0)), db(-20.0))
    wv = TAU * 1200.0 / SR
    wl = TAU / N
    whine = []
    for i in range(N):
        p = wv * i + 6.0 * _sin(wl * i)                    # +-2 Hz vibrato over 3 s
        whine.append(_sin(p) + 0.25 * _sin(2.0 * p))
    whine = nrm_rms(mul(whine, lfo(N, [(0.2, 2, 0.0)], 1.0)), db(-22.0))
    hm = nrm_rms(addv(psine(N, 60.0), psine(N, 120.0, 0.7), 0.6), db(-24.0))
    return [a + b + c + d for a, b, c, d in zip(fan, blade, whine, hm)]


@reg("wind_loop", 8.0, loop=True, rms_db=-24.0)
def s_wind(rng):
    N, C, P = ns(8.0), ns(1.0), 8192
    L = P + N + C
    gust = [max(0.12, g) for g in lfo(N, [(0.25, 1, 0.5), (0.12, 3, 2.0), (0.06, 5, 4.0)], 0.62)]
    gL = per(N, L, P, gust)
    cb = per(N, L, P, lfo(N, [(260.0, 1, 0.0), (110.0, 2, 1.3), (40.0, 6, 2.2)], 520.0))
    body = svf(white(L, rng), [c * (0.75 + 0.5 * g) for c, g in zip(cb, gL)], 1.1, "bp")
    body = nrm_rms(mul(body, gL))
    low = lp(hp(brown(L, rng), 25.0), 140.0)
    low = nrm_rms(mul(low, [g ** 1.5 for g in gL]), db(-3.0))
    wc = per(N, L, P, lfo(N, [(160.0, 1, 2.0), (55.0, 4, 0.7), (20.0, 9, 1.1)], 950.0))
    wct = [c * (0.9 + 0.2 * g) for c, g in zip(wc, gL)]
    wn = white(L, rng)
    wh1 = nrm_rms(mul(svf(wn, wct, 28.0, "bp"), [g * g for g in gL]))
    wh2 = nrm_rms(mul(svf(wn, [c * 1.47 for c in wct], 35.0, "bp"), [g ** 2.5 for g in gL]))
    wh = nrm_rms(addv(wh1, wh2, 0.5), db(-11.0))
    hs = nrm_rms(mul(hp(pink(L, rng), 2500.0), gL), db(-19.0))
    allx = [a + b + c + d for a, b, c, d in zip(body, low, wh, hs)]
    return xfade_loop(allx[P:], N, C)


@reg("drone_loop", 12.0, loop=True)
def s_drone(rng):
    N, C, P = ns(12.0), ns(1.5), 8192
    L = P + N + C
    x = zeros(N)
    # 55, 55.4167, 77.8333 Hz: integer cycle counts per 12 s (660, 665, 934)
    for f, a in ((55.0, 1.0), (665.0 / 12.0, 0.9), (934.0 / 12.0, 0.6)):
        k = f / SR
        p0 = rng.random()
        x = [v + a * (2.0 * ((p0 + k * i) % 1.0) - 1.0) for i, v in enumerate(x)]
    w55 = TAU * 55.0 / SR
    w27 = TAU * 27.5 / SR
    x = [v + 0.5 * _sin(w55 * i) + 0.35 * _sin(w27 * i) for i, v in enumerate(x)]
    cut = lfo(N, [(110.0, 1, 0.0), (40.0, 3, 1.0)], 360.0)
    pre = 8192
    x = circ(x, lambda v: lp(svf(v, per(N, len(v), pre, cut), 1.0, "lp"), 900.0), pre)
    x = nrm_rms(x)
    x = mul(x, lfo(N, [(0.12, 1, 1.0), (0.05, 2, 0.0)], 1.0))
    hi = addv(psine(N, 1244.0), psine(N, 1318.0, 0.5), 0.8)
    hi = nrm_rms(mul(hi, lfo(N, [(0.5, 1, PI)], 0.5)), db(-30.0))
    nz = lp(brown(L, rng), 220.0)
    nz = nrm_rms(xfade_loop(nz[P:], N, C), db(-16.0))
    out = [a + b + c for a, b, c in zip(x, hi, nz)]
    return sat(nrm(out), 1.3)


@reg("heartbeat_loop", 1.0, loop=True)
def s_heartbeat(rng):
    N = ns(1.0)
    beat = zeros(N)

    def thud(f0, f1, tau, amp):
        n = ns(0.45)
        x = thump(n, f0, f1, 0.03, tau, 0.004)
        nz = lp(lp(burst(n, rng, tau * 0.5), 150.0), 150.0)
        x = addv(x, nrm(nz), 0.3)
        return scale(x, amp)

    mix_circ(beat, thud(75.0, 46.0, 0.045, 1.0), ns(0.05))    # lub
    mix_circ(beat, thud(82.0, 50.0, 0.038, 0.62), ns(0.33))   # dub, 0.28 s later
    beat = sat(nrm(beat), 1.6)
    return circ(beat, lambda v: lp(v, 260.0, 0.7), 4096)


@reg("radio_static_loop", 3.0, loop=True)
def s_radio_static(rng):
    N, C, P = ns(3.0), ns(0.3), 4096
    L = P + N + C
    bed = peq(band(white(L, rng), 300.0, 3000.0), 1800.0, 1.0, 3.0)
    bed = nrm_rms(xfade_loop(bed[P:], N, C))
    fl = smooth_rand(N, 30, rng, True)
    ff = smooth_rand(N, 150, rng, True)
    mod = [max(0.2, 1.0 + 0.3 * a + 0.12 * b) for a, b in zip(fl, ff)]
    crk = zeros(N)
    for _ in range(750):                      # fine continuous crackle (~250/s, heavy-tailed)
        crk[rng.randrange(N)] += rng.choice((-1.0, 1.0)) * 2.0 * rng.random() ** 4
    w2 = ns(0.002)
    for _ in range(40):                       # isolated pops
        pos = rng.randrange(N)
        amp = 0.3 + 2.7 * rng.random() ** 3
        for _ in range(rng.randint(1, 3)):
            crk[(pos + rng.randrange(w2)) % N] += amp * rng.choice((-1.0, 1.0)) * rng.uniform(0.5, 1.0)
    for _ in range(6):                        # crackle clusters ("frying")
        start = rng.randrange(N)
        dur = rng.uniform(0.02, 0.08)
        for _ in range(int(dur * rng.uniform(1500, 3000))):
            crk[(start + rng.randrange(ns(dur))) % N] += rng.uniform(-1.5, 1.5)
    crk = circ(crk, lambda v: band(v, 300.0, 3000.0), 4096)
    crk = nrm(crk, 8.0)
    out = [b * m + c for b, m, c in zip(bed, mod, crk)]
    return sat(nrm(out), 1.8)


VOWELS = ((800, 1200, 2500), (500, 1850, 2550), (320, 2250, 2950), (550, 900, 2400),
          (380, 950, 2300), (700, 1650, 2450), (500, 1350, 1700), (600, 1150, 2450))


def _whisper_syl(rng, dur, fscale=1.0):
    v1 = rng.choice(VOWELS)
    v2 = rng.choice(VOWELS)
    n = ns(dur)
    src = white(n, rng)
    u = [smoothstep(i / n) for i in range(n)]
    out = zeros(n)
    for k, (q, g) in enumerate(((5.0, 1.0), (7.5, 0.65), (9.0, 0.35))):
        a = v1[k] * fscale * rng.uniform(0.95, 1.05)
        b = v2[k] * fscale * rng.uniform(0.95, 1.05)
        out = addv(out, svf(src, [a + (b - a) * s for s in u], q, "bp"), g)
    att = min(0.045, dur * 0.3)
    env = env_pts(n, [(0.0, 0.0), (att, 1.0), (dur * 0.55, 0.75), (dur, 0.0)])
    out = nrm(mul(out, [smoothstep(e) for e in env]))
    cons = rng.choice((None, None, "s", "sh", "h", "f", "t", "s"))
    if cons is None:
        return out
    cd = {"s": 0.11, "sh": 0.12, "h": 0.06, "f": 0.08, "t": 0.015}[cons]
    cn = ns(cd)
    cx = white(cn, rng)
    if cons == "s":
        cx, g = bp(hp(cx, 4000.0), 6500.0, 1.5), 0.55
    elif cons == "sh":
        cx, g = bp(cx, 3000.0 * fscale, 1.6), 0.6
    elif cons == "h":
        cx, g = bp(cx, 1500.0 * fscale, 0.6), 0.35
    elif cons == "f":
        cx, g = hp(cx, 2500.0), 0.22
    else:
        cx, g = hp(cx, 2000.0), 0.7
    cx = nrm(mul(cx, env_pts(cn, [(0.0, 0.0), (cd * 0.35, 1.0), (cd, 0.0)])), g)
    ov = ns(0.012)
    res = zeros(cn + n - ov)
    if rng.random() < 0.6:          # consonant before the vowel
        mix(res, cx, 0)
        mix(res, out, cn - ov)
    else:                           # after
        mix(res, out, 0)
        mix(res, cx, n - ov)
    return res


def _whisper_voice(rng, N, t_start, t_end, fscale, density=1.0):
    buf = zeros(N)
    t = t_start
    while t < t_end - 0.25:
        for _ in range(rng.choice((1, 2, 2, 3, 3, 4))):
            syl = _whisper_syl(rng, rng.uniform(0.09, 0.24), fscale)
            mix_circ(buf, syl, ns(t), rng.uniform(0.6, 1.0))
            t += len(syl) / SR + rng.uniform(0.0, 0.05)
            if t >= t_end - 0.2:
                break
        t += rng.uniform(0.15, 0.6) / density
    return buf


@reg("whisper_loop", 6.0, loop=True)
def s_whisper(rng):
    N = ns(6.0)
    v1 = _whisper_voice(rng, N, 0.10, 6.0, 1.0)
    v2 = _whisper_voice(rng, N, 0.85, 6.6, 0.85, density=0.8)
    v2 = circ(v2, lambda v: lp(v, 2600.0), 2048)
    dry = hp(addv(v1, v2, 0.45), 150.0)
    dry = circ(dry, lambda v: hp(v, 150.0), 2048)
    wet = circ(dry, lambda v: reverb(v, rt60=1.4, size=1.1, damp=5000.0, predelay=0.012), ns(2.5))
    return [a + 0.45 * b for a, b in zip(dry, wet)]


@reg("luggage_roll_loop", 1.8, loop=True)
def s_luggage_roll(rng):
    N, C, P = ns(1.8), ns(0.3), 4096
    L = P + N + C
    wn = white(L, rng)
    rum = nrm_rms(xfade_loop(lp(lp(wn, 320.0), 320.0)[P:], N, C))
    rum = mul(rum, lfo(N, [(0.2, 12, 0.0), (0.1, 24, 1.0)], 1.0))   # 6.67 Hz wheel rotation
    grit = nrm_rms(xfade_loop(bp(wn, 1500.0, 0.9)[P:], N, C), db(-16.0))
    gm = smooth_rand(N, 36, rng, True)
    grit = [g * (1.0 + 0.3 * m) for g, m in zip(grit, gm)]
    bear = nrm_rms(xfade_loop(bp(white(L, rng), 3200.0, 6.0)[P:], N, C), db(-26.0))
    clk = zeros(N)
    for k in range(6):                                      # tile seam every 0.3 s
        t = 0.05 + 0.3 * k + rng.uniform(-0.002, 0.002)
        for j, (dt, a) in enumerate(((0.0, 1.0), (rng.uniform(0.009, 0.014), 0.7))):
            n = ns(0.07)
            tap = scale(thump(n, 240.0, 180.0, 0.005, 0.014, 0.0005), 0.8)
            mix(tap, nrm(burst(ns(0.01), rng, 0.0008, 1800.0, 6000.0)), 0, 0.8)
            mix(tap, modes(n, [620 * rng.uniform(0.95, 1.05), 1130, 1870, 2900 * rng.uniform(0.95, 1.05)],
                           [0.25, 0.15, 0.1, 0.3], [0.02, 0.015, 0.01, 0.004], rng))
            mix_circ(clk, tap, ns(t + dt), a * rng.uniform(0.85, 1.0))
    clk = nrm(clk, 5.0)
    return [a + b + c + d for a, b, c, d in zip(rum, grit, bear, clk)]


def _inhale(rng, dur):
    n = ns(dur)
    src = white(n, rng)
    ctl = [800.0 * (2000.0 / 800.0) ** (i / n) for i in range(n)]
    x = svf(src, ctl, 2.2, "bp")
    x = addv(x, svf(src, 2900.0, 4.0, "bp"), 0.35)
    x = hp(x, 500.0)
    env = env_pts(n, [(0.0, 0.0), (dur * 0.6, 0.8), (dur * 0.88, 1.0), (dur, 0.0)])
    x = mul(x, [e * e for e in env])
    return trem(x, 7.0, 0.15)


def _exhale(rng, dur):
    n = ns(dur)
    src = white(n, rng)
    ctl = [1500.0 * (550.0 / 1500.0) ** (i / n) for i in range(n)]
    x = svf(src, ctl, 0.9, "bp")
    x = addv(nrm(x), nrm(lp(lp(src, 650.0), 650.0)), 0.45)
    env = env_pts(n, [(0.0, 0.0), (0.07, 1.0), (0.35, 0.7), (dur, 0.0)])
    x = mul(x, [e ** 1.5 for e in env])
    tr = smooth_rand(n, 12, rng)
    w = TAU * 9.5 / SR
    return [v * (1.0 + 0.22 * _sin(w * i) + 0.12 * t) for i, (v, t) in enumerate(zip(x, tr))]


@reg("breath_loop", 3.0, loop=True)
def s_breath(rng):
    N = ns(3.0)
    out = zeros(N)
    for t0, iv, ev in ((0.0, 0.55, 0.78), (1.5, 0.52, 0.80)):     # one cycle per 1.5 s
        mix_circ(out, nrm(_inhale(rng, iv)), ns(t0 + 0.02), 0.7)
        mix_circ(out, nrm(_exhale(rng, ev)), ns(t0 + 0.64), 1.0)
    wet = circ(out, lambda v: reverb(v, rt60=0.4, size=0.5, damp=6000.0), ns(0.8))
    return [a + 0.15 * b for a, b in zip(out, wet)]


@reg("menu_music_loop", 24.0, loop=True)
def s_menu_music(rng):
    N, C, P = ns(24.0), ns(2.0), 4096
    L = P + N + C
    # Am - F - Dm - E, 6 s each: (sub-bass midi, pad bass midi, pad notes)
    prog = ((33, 45, (57, 60, 64)),
            (29, 41, (57, 60, 65)),
            (26, 50, (57, 62, 65)),
            (28, 40, (56, 59, 64)))
    pad = zeros(N)
    sub = zeros(N)
    for ci, (sm, bm, notes) in enumerate(prog):
        start = ci * 6.0 - 0.8
        dur = 9.0
        n = ns(dur)
        x = zeros(n)
        for m in notes + (bm,):
            f = mtof(m)
            vo = saw_sum(n, [f * 2.0 ** (c / 1200.0) for c in (-9.0, -2.0, 6.0)], rng)
            x = addv(x, vo, (0.6 if m == bm else 1.0) / 3.0)
        fe = env_pts(n, [(0.0, 0.0), (3.2, 1.0), (6.5, 0.45), (dur, 0.1)])
        wob = lfo(n, [(0.12, 2, rng.random() * TAU)], 1.0)
        x = svf(x, [300.0 + 850.0 * e * w for e, w in zip(fe, wob)], 1.1, "lp")
        x = lp(x, 2500.0)
        ae = env_pts(n, [(0.0, 0.0), (2.0, 1.0), (6.8, 1.0), (dur, 0.0)])
        x = mul(x, [smoothstep(e) for e in ae])
        mix_circ(pad, x, ns(start))
        fs = mtof(sm)
        sb = addv(addv(dsine(n, fs), dsine(n, 2 * fs, 0.45, None, 0.3)), dsine(n, 3 * fs, 0.12))
        se = env_pts(n, [(0.0, 0.0), (1.6, 1.0), (6.8, 1.0), (dur, 0.0)])
        mix_circ(sub, mul(sb, [smoothstep(e) for e in se]), ns(start + 0.3))
    pad = nrm_rms(pad)
    sub = nrm_rms(sub, db(-8.0))
    # airport-chime motif in A minor, once per loop
    bells = zeros(N)
    for k, m in enumerate((81, 84, 88, 93)):        # A5 C6 E6 A6, above the pad
        b = bell(ns(4.0), mtof(m), rng, decay=2.2, bright=0.6, strike=0.03)
        mix_circ(bells, b, ns(2.0 + 0.55 * k), 0.9 - 0.05 * k)
    bells = nrm(trem(bells, 5.0, 0.12), 2.4)
    send = [b + 0.5 * p for b, p in zip(bells, pad)]
    wet = circ(send, lambda v: reverb(v, rt60=4.5, size=1.7, damp=3500.0, predelay=0.03), ns(8.0))
    air = lp(hp(pink(L, rng), 200.0), 1200.0)
    air = nrm_rms(xfade_loop(air[P:], N, C), db(-30.0))
    out = [0.8 * p + s + 0.6 * b + 0.75 * w + a for p, s, b, w, a in zip(pad, sub, bells, wet, air)]
    out = sat(nrm(out), 1.1)
    return circ(out, lambda v: lp(v, 9000.0), 4096)


# =============================================================================
# ONE-SHOTS
# =============================================================================

def _chime(rng, dur, notes, onsets, decay, bright, trem_rate, trem_depth, rt60, size, damp, wet):
    n = ns(dur)
    dry = zeros(n)
    for k, (m, t0) in enumerate(zip(notes, onsets)):
        d = decay * (1.2 if k == len(notes) - 1 else 1.0)
        mix(dry, bell(n - ns(t0), mtof(m), rng, decay=d, bright=bright), ns(t0), 1.0)
    dry = trem(dry, trem_rate, trem_depth)
    return verb(dry, wet, 1.0, rt60=rt60, size=size, damp=damp, predelay=0.02)


@reg("pa_chime", 3.0, fade_out=0.5)
def s_pa_chime(rng):
    return _chime(rng, 3.0, (69, 73, 76, 81), (0.05, 0.40, 0.75, 1.10), 1.35, 1.0,
                  5.5, 0.16, 2.3, 1.4, 5500.0, 0.7)


@reg("pa_chime_end", 2.5, peak_db=-4.0, fade_out=0.45)
def s_pa_chime_end(rng):
    return _chime(rng, 2.5, (81, 76, 73, 69), (0.05, 0.40, 0.75, 1.10), 1.1, 0.65,
                  5.5, 0.14, 2.1, 1.4, 5000.0, 0.7)


@reg("pa_chime_wrong", 4.0, fade_out=0.8)
def s_pa_chime_wrong(rng):
    n = ns(4.0)
    t = [i / SR for i in range(n)]
    # slow tape wow on everything
    wow = [1.0 + 0.0045 * _sin(TAU * 0.65 * x) + 0.0018 * _sin(TAU * 3.3 * x + 1.0) for x in t]
    # (midi, cents detune, onset, decay, brightness): detuned, dragging, last note a flat b6
    notes = ((69, +38.0, 0.05, 1.4, 1.0), (73, -45.0, 0.45, 1.4, 1.1),
             (76, +32.0, 0.93, 1.5, 1.2), (77, -40.0, 1.52, 2.4, 1.4))
    dry = zeros(n)
    ghost = zeros(n)
    for k, (m, cents, t0, dec, br) in enumerate(notes):
        i0 = ns(t0)
        m_n = n - i0
        f = mtof(m) * 2.0 ** (cents / 1200.0)
        fm = wow[i0:]
        if k == len(notes) - 1:     # bends down a further ~150 cents
            fm = [w * 2.0 ** (-1.5 / 12.0 * smoothstep(j / ns(2.2))) for j, w in enumerate(fm)]
        mix(dry, bell(m_n, f, rng, decay=dec, bright=br, fmul=fm), i0)
        mix(ghost, bell(m_n, f * 0.5, rng, decay=dec * 0.8, bright=0.4, fmul=fm, strike=0.0), i0 + ns(0.07))
    dry = addv(dry, ghost, 0.14)
    dry = trem(dry, 4.1, 0.26)
    return verb(dry, 0.95, 0.85, rt60=3.8, size=1.8, damp=3800.0, predelay=0.035)


@reg("radio_on", 0.35, fade_out=0.02)
def s_radio_on(rng):
    n = ns(0.35)
    out = zeros(n)
    sq = mul(white(ns(0.09), rng), env_pts(ns(0.09), [(0, 0), (0.001, 1.0), (0.035, 0.85), (0.09, 0.0)]))
    for _ in range(12):
        sq[rng.randrange(len(sq))] += rng.uniform(-1.5, 1.5)
    mix(out, sq, 0, 0.8)
    bn = ns(0.08)
    beep = mul(rsquare(bn, 1000.0, 1.6), env_pts(bn, [(0, 0), (0.003, 1.0), (0.077, 1.0), (0.08, 0.0)]))
    mix(out, beep, ns(0.11), 0.55)
    hs = mul(white(n, rng), env_pts(n, [(0.07, 0.0), (0.09, 0.05), (0.33, 0.035), (0.35, 0.0)]))
    out = addv(out, hs)
    return radio_fx(out, 1.8)


@reg("radio_off", 0.4, fade_out=0.02)
def s_radio_off(rng):
    n = ns(0.4)
    out = zeros(n)
    kn = ns(0.17)
    ks = mul(white(kn, rng), env_pts(kn, [(0, 0), (0.0015, 1.0), (0.03, 0.55), (0.17, 0.0)]))
    fl = smooth_rand(kn, 14, rng)
    ks = [v * (1.0 + 0.45 * f) for v, f in zip(ks, fl)]
    mix(out, ks, 0, 0.9)
    for t0, f in ((0.20, 640.0), (0.28, 540.0)):
        bn = ns(0.045)
        b = mul(rsquare(bn, f, 1.8), env_pts(bn, [(0, 0), (0.003, 1.0), (0.041, 1.0), (0.045, 0.0)]))
        mix(out, b, ns(t0), 0.55)
    return radio_fx(out, 1.8, 320.0, 3200.0)


@reg("radio_chatter", 2.5, fade_out=0.06)
def s_radio_chatter(rng):
    n = ns(2.5)
    f0 = [130.0] * n
    av = zeros(n)
    F = [[500.0] * n, [1500.0] * n, [2500.0] * n]
    fric = zeros(n)
    for p_start, p_end, hi_p, lo_p in ((0.06, 1.12, 158.0, 118.0), (1.30, 2.36, 146.0, 110.0)):
        t = p_start
        while t < p_end:
            dur = rng.uniform(0.08, 0.19)
            if t + dur > p_end:
                dur = max(0.06, p_end - t)
            u0 = (t - p_start) / (p_end - p_start)
            base = hi_p + (lo_p - hi_p) * u0
            accent = rng.choice((0.0, 0.0, 12.0, 20.0))
            i0, i1 = ns(t), min(n, ns(t + dur))
            m = i1 - i0
            f0[i0:i1] = [base + accent * _sin(PI * j / m) for j in range(m)]
            vow = rng.choice(VOWELS)
            for k in range(3):
                F[k][i0:i1] = [vow[k] * rng.uniform(0.97, 1.03)] * m
            e = env_pts(m, [(0, 0), (0.012, 1.0), (dur - 0.025, 0.8), (dur, 0.0)])
            av[i0:i1] = [max(a, b) for a, b in zip(av[i0:i1], e)]
            c = rng.random()
            if c < 0.3:                                   # fricative before
                cn = ns(rng.uniform(0.04, 0.07))
                fx = bp(white(cn, rng), rng.uniform(2600.0, 4200.0), 1.5)
                fx = mul(fx, env_pts(cn, [(0, 0), (cn / SR * 0.4, 1.0), (cn / SR, 0.0)]))
                mix(fric, nrm(fx), max(0, i0 - cn + ns(0.01)), 0.5)
            elif c < 0.5:                                 # plosive
                mix(fric, nrm(burst(ns(0.012), rng, 0.002, 1500.0)), max(0, i0 - ns(0.01)), 0.6)
            t += dur + rng.uniform(0.01, 0.05)
    # smooth formant / pitch transitions
    F = [lp1(lp1(fk, 25.0), 25.0) for fk in F]
    jit = smooth_rand(n, 60, rng)
    f0 = [f * (1.0 + 0.012 * j) for f, j in zip(lp1(f0, 20.0), jit)]
    src = mul(saw_var(f0), av)
    asp = mul(white(n, rng), [0.08 * a for a in av])
    x = addv(src, asp)
    vt = zeros(n)
    for k, (q, g) in enumerate(((5.0, 1.0), (8.0, 0.6), (10.0, 0.3))):
        vt = addv(vt, svf(x, F[k], q, "bp"), g)
    vt = addv(vt, x, 0.04)
    voice = addv(nrm(vt), fric, 0.8)
    for _ in range(2):                                    # signal drop-outs
        d0 = ns(rng.uniform(0.3, 2.2))
        dn = ns(rng.uniform(0.012, 0.025))
        voice[d0:d0 + dn] = [v * 0.15 for v in voice[d0:d0 + dn]]
    voice = radio_fx(voice, 3.0)
    st = band(white(n, rng), 300.0, 3000.0)
    sm = smooth_rand(n, 40, rng)
    st = [s * (1.0 + 0.4 * m) for s, m in zip(nrm_rms(st, 0.08), sm)]
    for _ in range(10):
        st[rng.randrange(n)] += rng.uniform(-0.5, 0.5)
    return addv(voice, st)


@reg("ui_click", 0.05, fade_out=0.008)
def s_ui_click(rng):
    n = ns(0.05)
    out = zeros(n)
    t0 = ns(0.002)
    mix(out, dsine(n, 2100.0, 0.6, 0.004), t0)
    mix(out, dsine(n, 3400.0, 0.3, 0.0025), t0)
    mix(out, dsine(n, 600.0, 0.25, 0.006), t0)
    mix(out, bp(burst(ns(0.004), rng, 0.0004), 4000.0, 1.0), t0, 0.5)
    return lp(out, 7000.0)


@reg("ui_tap", 0.08, fade_out=0.01)
def s_ui_tap(rng):
    n = ns(0.08)
    out = zeros(n)
    t0 = ns(0.002)
    f = 2600.0
    mix(out, modes(n, [f, f * 2.32, f * 4.25, f * 6.63], [1.0, 0.5, 0.25, 0.12],
                   [0.030, 0.018, 0.010, 0.006], None, 0.0006), t0)
    mix(out, click(rng, ns(0.004), 0.0003, 3000.0), t0, 0.35)
    return out


@reg("ui_notify", 0.5, fade_out=0.05)
def s_ui_notify(rng):
    n = ns(0.5)
    out = zeros(n)
    for t0, f in ((0.0, 1318.51), (0.13, 1760.0)):
        m = n - ns(t0)
        tone = addv(dsine(m, f, 0.75, 0.09), dsine(m, f, 0.25, 0.25))
        tone = addv(tone, dsine(m, 2 * f, 0.08, 0.05))
        tone = addv(tone, dsine(m, 3 * f, 0.04, 0.03))
        mix(out, fade_in(tone, 0.004), ns(t0) + ns(0.002))
    return verb(out, 0.25, 1.0, rt60=0.6, size=0.6, damp=8000.0)


@reg("ui_alert", 0.7, fade_out=0.05)
def s_ui_alert(rng):
    n = ns(0.7)
    out = zeros(n)
    bn = ns(0.11)
    env = env_pts(bn, [(0, 0), (0.004, 1.0), (0.106, 1.0), (0.11, 0.0)])
    for t0 in (0.005, 0.165, 0.325):
        tone = addv(rsquare(bn, 1800.0, 3.0), rsquare(bn, 1835.0, 2.0, 0.4), 0.4)
        mix(out, mul(tone, env), ns(t0))
    out = lp(peq(out, 2600.0, 1.2, 3.0), 9000.0)
    return verb(out, 0.18, 1.0, rt60=0.5, size=0.6, damp=7000.0)


@reg("tablet_open", 0.45, fade_out=0.04)
def s_tablet_open(rng):
    n = ns(0.45)
    wh = mul(pink(n, rng), [e * e for e in env_pts(n, [(0, 0), (0.2, 1.0), (0.42, 0.0)])])
    wh = svf(wh, [450.0 * (3000.0 / 450.0) ** min(1.0, i / ns(0.42)) for i in range(n)], 1.3, "bp")
    out = scale(nrm(wh), 0.6)
    cn = ns(0.12)
    fr = [700.0 * (1900.0 / 700.0) ** min(1.0, i / ns(0.09)) for i in range(cn)]
    ph = phases(fr)
    ch = [(_sin(p) + 0.25 * _sin(2 * p)) for p in ph]
    ch = mul(ch, env_pts(cn, [(0, 0), (0.01, 1.0), (0.08, 0.7), (0.12, 0.0)]))
    mix(out, ch, ns(0.12), 0.3)
    mix(out, addv(dsine(ns(0.12), 2400.0, 1.0, 0.03), dsine(ns(0.12), 3600.0, 0.3, 0.015)), ns(0.25), 0.15)
    return lp(out, 10000.0)


@reg("tablet_close", 0.3, fade_out=0.03)
def s_tablet_close(rng):
    n = ns(0.3)
    wh = mul(pink(n, rng), [e * e for e in env_pts(n, [(0, 0), (0.03, 1.0), (0.19, 0.0)])])
    wh = svf(wh, [2600.0 * (400.0 / 2600.0) ** min(1.0, i / ns(0.19)) for i in range(n)], 1.2, "bp")
    out = scale(nrm(wh), 0.6)
    c = zeros(ns(0.08))
    mix(c, dsine(len(c), 1400.0, 0.5, 0.005))
    mix(c, click(rng, ns(0.005), 0.0004, 1500.0), 0, 0.4)
    mix(c, dsine(len(c), 180.0, 0.4, 0.015))
    mix(out, fade_in(c, 0.0005), ns(0.19), 0.8)
    return out


def _crinkle(n, rng, regions):
    """sparse random impulses (paper crinkle). regions: (t0, t1, count, amp)"""
    imp = zeros(n)
    for t0, t1, cnt, amp in regions:
        for _ in range(cnt):
            i = ns(rng.uniform(t0, t1))
            if i < n - 3:
                a = amp * rng.random() ** 2 * rng.choice((-1.0, 1.0))
                imp[i] += a
                if rng.random() < 0.3:
                    imp[i + 1] -= 0.6 * a
                    imp[i + 2] += 0.3 * a
    return peq(hp(imp, 1800.0), 4500.0, 1.2, 4.0)


@reg("page_flip", 0.4, fade_out=0.04)
def s_page_flip(rng):
    n = ns(0.4)
    sw = mul(white(n, rng), env_pts(n, [(0, 0), (0.05, 0.25), (0.16, 1.0), (0.27, 0.35), (0.33, 0.0)]))
    sw = svf(sw, [1400.0 + 2200.0 * _sin(PI * min(1.0, i / ns(0.33))) for i in range(n)], 0.9, "bp")
    out = scale(nrm(sw), 0.45)
    crk = _crinkle(n, rng, ((0.01, 0.09, 90, 1.0), (0.08, 0.30, 150, 0.75)))
    out = addv(out, nrm(crk), 1.0)
    mix(out, nrm(burst(ns(0.04), rng, 0.006, 250.0, 1800.0)), ns(0.30), 0.35)
    return out


@reg("binder_open", 0.6, fade_out=0.05)
def s_binder_open(rng):
    n = ns(0.6)
    out = zeros(n)
    # plastic cover clack
    cl = scale(bp(burst(ns(0.03), rng, 0.004), 1200.0, 1.0), 1.0)
    mix(cl, thump(ns(0.03), 260.0, 230.0, 0.01, 0.01), 0, 0.5)
    mix(out, nrm(cl), ns(0.004), 0.5)
    # three rings snapping open
    for k, t0 in enumerate((0.03, 0.041, 0.05)):
        sc = rng.uniform(0.95, 1.05)
        rn = ns(0.15)
        r = modes(rn, [2350 * sc, 3880 * sc, 5600 * sc, 7400 * sc], [0.5, 0.35, 0.2, 0.1],
                  [0.06, 0.04, 0.025, 0.015], rng)
        mix(r, click(rng, ns(0.004), 0.0003, 2000.0), 0, 1.0)
        mix(r, dsine(rn, 900.0 * sc, 0.4, 0.008))
        mix(out, r, ns(t0), 1.0 - 0.15 * k)
    # paper rustle afterwards
    pn = ns(0.5)
    pr = mul(white(pn, rng), env_pts(pn, [(0, 0), (0.06, 0.6), (0.18, 0.3), (0.45, 0.0)]))
    pr = bp(pr, 2600.0, 0.8)
    pr = addv(nrm(pr), nrm(_crinkle(pn, rng, ((0.02, 0.3, 40, 1.0),))), 0.8)
    mix(out, nrm(pr), ns(0.08), 0.45)
    return out


@reg("button_press", 0.12, fade_out=0.02)
def s_button_press(rng):
    n = ns(0.12)
    out = zeros(n)
    c1 = bp(burst(ns(0.01), rng, 0.0015), 3000.0, 1.5)
    c1 = addv(nrm(c1), modes(len(c1), [1300.0, 2700.0], [0.6, 0.4], [0.006, 0.004], rng))
    mix(out, c1, ns(0.005), 0.8)
    th = addv(dsine(ns(0.08), 220.0, 1.0, 0.018), lp(burst(ns(0.08), rng, 0.006), 800.0), 0.6)
    mix(out, fade_in(th, 0.0005), ns(0.018), 1.0)
    mix(out, click(rng, ns(0.005), 0.0004, 1200.0), ns(0.018), 0.4)
    return out


@reg("switch_heavy", 0.5, fade_out=0.05)
def s_switch_heavy(rng):
    n = ns(0.5)
    dry = zeros(n)
    mc = modes(ns(0.08), [3100.0, 4700.0, 6900.0], [0.5, 0.3, 0.2], [0.025, 0.015, 0.01], rng)
    mix(mc, click(rng, ns(0.004), 0.0004, 3000.0), 0, 0.8)
    mix(dry, mc, ns(0.005), 0.55)
    t1 = ns(0.055)
    mix(dry, thump(ns(0.4), 95.0, 55.0, 0.03, 0.09, 0.001), t1, 1.0)
    mix(dry, nrm(burst(ns(0.15), rng, 0.035, None, 700.0)), t1, 0.5)
    mix(dry, modes(ns(0.4), [420.0, 1130.0, 1870.0, 2650.0, 3390.0], [0.3, 0.25, 0.2, 0.12, 0.08],
                   [0.18, 0.12, 0.09, 0.06, 0.04], rng), t1, 0.6)
    mix(dry, click(rng, ns(0.006), 0.0006, 1500.0), t1, 0.6)
    return verb(dry, 0.3, 1.0, rt60=0.5, size=0.7, damp=5000.0)


@reg("beep_ok", 0.15, fade_out=0.02)
def s_beep_ok(rng):
    n = ns(0.15)
    tn = ns(0.125)
    tone = addv(addv(dsine(tn, 1200.0), dsine(tn, 3600.0, 0.15)), dsine(tn, 2400.0, 0.06))
    tone = mul(tone, env_pts(tn, [(0, 0), (0.003, 1.0), (0.10, 0.85), (0.125, 0.0)]))
    out = zeros(n)
    mix(out, tone, ns(0.002))
    return lp(out, 6000.0)


@reg("beep_error", 0.9, fade_out=0.04)
def s_beep_error(rng):
    n = ns(0.9)
    out = zeros(n)
    bn = ns(0.35)
    env = env_pts(bn, [(0, 0), (0.004, 1.0), (0.342, 1.0), (0.35, 0.0)])
    for t0 in (0.02, 0.47):
        x = addv(square_blep(bn, 220.0), square_blep(bn, 223.5, 0.3), 0.6)
        x = sat(nrm(x), 2.2)
        mix(out, mul(x, env), ns(t0))
    out = hp(out, 160.0)
    out = peq(out, 1300.0, 1.0, 5.0)
    out = lp(lp(out, 3800.0), 3800.0)
    return verb(out, 0.12, 1.0, rt60=0.4, size=0.5, damp=6000.0)


def _piezo(dur_on, f, total):
    n = ns(total)
    bn = ns(dur_on)
    x = rsquare(bn, f, 2.2)
    x = addv(x, bp(x, f, 3.0), 0.8)
    x = mul(x, env_pts(bn, [(0, 0), (0.002, 1.0), (dur_on - 0.005, 1.0), (dur_on, 0.0)]))
    out = zeros(n)
    mix(out, x, ns(0.002))
    return out


@reg("card_beep", 0.1, fade_out=0.01)
def s_card_beep(rng):
    return _piezo(0.085, 2400.0, 0.1)


@reg("keypad_beep", 0.07, fade_out=0.008)
def s_keypad_beep(rng):
    return _piezo(0.055, 1500.0, 0.07)


# ------------------------------------------------------------------ footsteps

def _tile_step_dry(rng):
    n = ns(0.2)
    out = zeros(n)
    t0 = ns(0.003)
    fc = rng.uniform(2800.0, 4600.0)
    hc = peq(hp(burst(ns(0.006), rng, rng.uniform(0.0004, 0.0008)), 1500.0), fc, 1.4, 6.0)
    mix(out, nrm(hc), t0, 1.0)
    mix(out, dsine(ns(0.02), rng.uniform(2000.0, 3200.0), 0.25, rng.uniform(0.002, 0.004)), t0)
    mix(out, thump(ns(0.1), rng.uniform(150.0, 190.0), rng.uniform(95.0, 120.0), 0.008,
                   rng.uniform(0.018, 0.028), 0.0008), t0, 0.55)
    mix(out, nrm(burst(ns(0.05), rng, 0.007, 400.0, 1600.0)), t0, 0.45)
    t1 = t0 + ns(rng.uniform(0.04, 0.07))
    mix(out, nrm(burst(ns(0.04), rng, rng.uniform(0.003, 0.005), 700.0, 2600.0)), t1, rng.uniform(0.3, 0.45))
    mix(out, nrm(click(rng, ns(0.004), 0.0004, 2000.0)), t1, 0.35)
    mix(out, nrm(burst(ns(0.03), rng, 0.01, 3000.0, 7000.0)), t1 + ns(0.005), 0.06)
    return out


def _make_tile(v):
    @reg("footstep_tile_%d" % v, 0.2, fade_out=0.03)
    def _fn(rng):
        dry = _tile_step_dry(rng)
        return verb(dry, 0.2, 1.0, rt60=0.45, size=0.55, damp=6500.0)
    return _fn


def _make_carpet(v):
    @reg("footstep_carpet_%d" % v, 0.2, fade_out=0.03)
    def _fn(rng):
        n = ns(0.2)
        out = zeros(n)
        t0 = ns(0.004)
        for k, (dt, a) in enumerate(((0.0, 1.0), (rng.uniform(0.045, 0.065), rng.uniform(0.35, 0.5)))):
            m = ns(0.15)
            th = lp(lp(mul(white(m, rng), env_exp(m, rng.uniform(0.025, 0.035))), 280.0), 280.0)
            th = fade_in(nrm(th), 0.006)
            th = addv(th, thump(m, rng.uniform(85.0, 100.0), rng.uniform(65.0, 75.0), 0.02,
                                rng.uniform(0.03, 0.04), 0.005), 0.6)
            mix(out, th, t0 + ns(dt), a)
            sn = ns(0.07)
            sc = mul(white(sn, rng), env_pts(sn, [(0, 0), (0.012, 1.0), (0.06, 0.0)]))
            sc = bp(sc, rng.uniform(2000.0, 2800.0), 0.7)
            mix(out, nrm(sc), t0 + ns(dt + 0.005), 0.13 * a)
        out = lp(out, 3500.0)
        return verb(out, 0.08, 1.0, rt60=0.3, size=0.4, damp=4000.0)
    return _fn


PLATE = (1.0, 1.59, 2.14, 2.30, 2.65, 2.92, 3.16, 3.50, 4.06, 4.61, 5.13)


def _make_metal(v):
    @reg("footstep_metal_%d" % v, 0.3, fade_out=0.04)
    def _fn(rng):
        n = ns(0.3)
        out = zeros(n)
        t0 = ns(0.003)
        f0 = rng.uniform(180.0, 270.0)
        for k, (dt, a, ringy) in enumerate(((0.0, 1.0, 1.0), (rng.uniform(0.045, 0.065), 0.55, 0.6))):
            st = t0 + ns(dt)
            m = n - st
            ring = modes(m, [f0 * r * rng.uniform(0.98, 1.02) for r in PLATE],
                         [rng.uniform(0.3, 0.6) / (1.0 + 0.25 * j) for j in range(len(PLATE))],
                         [ringy * rng.uniform(0.04, 0.10) / (1.0 + 0.08 * j) for j in range(len(PLATE))], rng)
            high = modes(m, [rng.uniform(1300.0, 3800.0) for _ in range(5)],
                         [rng.uniform(0.05, 0.15) for _ in range(5)],
                         [rng.uniform(0.02, 0.06) for _ in range(5)], rng)
            ev = addv(scale(nrm(ring), 0.8), high, 0.5)
            mix(ev, nrm(click(rng, ns(0.004), 0.0006, 1000.0)), 0, 0.8)
            mix(ev, thump(ns(0.15), rng.uniform(110.0, 130.0), 80.0, 0.01, 0.03, 0.0008), 0, 0.6)
            mix(ev, nrm(bp(burst(ns(0.08), rng, 0.02), 550.0, 2.5)), 0, 0.4)
            mix(out, ev, st, a)
        return verb(out, 0.25, 1.0, rt60=0.7, size=0.7, damp=6000.0)
    return _fn


for _v in (1, 2, 3, 4):
    _make_tile(_v)
for _v in (1, 2, 3, 4):
    _make_carpet(_v)
for _v in (1, 2, 3, 4):
    _make_metal(_v)


# ------------------------------------------------------------------ doors & machines

@reg("door_slide", 1.4, fade_out=0.08)
def s_door_slide(rng):
    n = ns(1.4)

    def vel(t):
        if t < 0.05:
            return 0.0
        if t < 0.40:
            return smoothstep((t - 0.05) / 0.35)
        if t < 0.80:
            return 1.0
        if t < 1.12:
            return 1.0 - smoothstep((t - 0.80) / 0.32)
        return 0.0

    v = [vel(i / SR) for i in range(n)]
    ph = phases([240.0 + 430.0 * x for x in v])
    whine = [(_sin(p) + 0.35 * _sin(2 * p) + 0.12 * _sin(3 * p)) * (x ** 0.8) + 0.12 * _sin(4.1 * p) * x
             for p, x in zip(ph, v)]
    hum = [(_sin(TAU * 100.0 * i / SR) + 0.5 * _sin(TAU * 200.0 * i / SR)) * x for i, x in enumerate(v)]
    wn = white(n, rng)
    track = mul(lp(lp(wn, 380.0), 380.0), v)
    tm = smooth_rand(n, 40, rng)
    track = [t * (1.0 + 0.25 * m) for t, m in zip(track, tm)]
    wheels = mul(bp(wn, 1300.0, 1.2), [x ** 1.5 for x in v])
    air = mul(bp(pink(n, rng), 700.0, 0.5), [x * x for x in v])
    out = addv(scale(nrm(whine), 0.35), nrm(hum), 0.15)
    out = addv(out, nrm(track), 0.55)
    out = addv(out, nrm(wheels), 0.15)
    out = addv(out, nrm(air), 0.12)
    tb = ns(1.12)
    bump = thump(ns(0.25), 95.0, 70.0, 0.02, 0.05, 0.002)
    mix(bump, nrm(burst(ns(0.1), rng, 0.015, None, 600.0)), 0, 0.35)
    mix(bump, modes(ns(0.1), [2900.0, 4300.0, 6100.0], [0.08, 0.05, 0.03], [0.03, 0.02, 0.012], rng))
    mix(out, bump, tb, 0.6)
    return verb(out, 0.22, 1.0, rt60=0.6, size=0.8, damp=6000.0)


@reg("door_heavy", 1.0, fade_out=0.15)
def s_door_heavy(rng):
    n = ns(1.0)
    dry = zeros(n)
    # latch handle
    lt = modes(ns(0.1), [2800.0, 4100.0, 5600.0], [0.5, 0.3, 0.2], [0.03, 0.02, 0.015], rng)
    mix(lt, click(rng, ns(0.004), 0.0005, 2000.0), 0, 0.7)
    mix(dry, lt, ns(0.02), 0.35)
    # swing air + short hinge creak
    sn = ns(0.2)
    sw = mul(lp(brown(sn, rng), 300.0), env_pts(sn, [(0, 0), (0.15, 1.0), (0.2, 0.3)]))
    mix(dry, nrm(sw), ns(0.06), 0.25)
    cn = ns(0.12)
    cr = zeros(cn)
    tt = 0.0
    while tt < 0.12:
        i = ns(tt)
        if i < cn:
            cr[i] = rng.uniform(0.6, 1.0)
        tt += 1.0 / (35.0 + 20.0 * tt / 0.12)
    cr = addv(bp(cr, 1100.0, 6.0), bp(cr, 2300.0, 8.0), 0.6)
    cr = mul(cr, env_pts(cn, [(0, 0), (0.03, 1.0), (0.09, 0.8), (0.12, 0.0)]))
    mix(dry, nrm(cr), ns(0.08), 0.12)
    # slam
    ts = ns(0.25)
    mix(dry, thump(ns(0.7), 70.0, 45.0, 0.03, 0.12, 0.001), ts, 1.0)
    mix(dry, nrm(burst(ns(0.3), rng, 0.06, None, 250.0)), ts, 0.6)
    mix(dry, modes(ns(0.75), [180, 287, 410, 525, 690, 912, 1180, 1530],
                   [0.25, 0.2, 0.18, 0.14, 0.11, 0.08, 0.06, 0.05],
                   [0.35, 0.3, 0.25, 0.2, 0.16, 0.12, 0.1, 0.08], rng), ts, 0.7)
    mix(dry, nrm(click(rng, ns(0.006), 0.0008, 800.0)), ts, 0.5)
    lc = modes(ns(0.12), [3300.0, 5100.0, 2200.0], [0.5, 0.3, 0.3], [0.03, 0.02, 0.04], rng)
    mix(lc, click(rng, ns(0.004), 0.0004, 2500.0), 0, 0.8)
    mix(dry, lc, ts + ns(0.012), 0.45)
    mix(dry, scale(lc, 0.3), ts + ns(0.045), 1.0)
    return verb(dry, 0.45, 1.0, rt60=0.9, size=1.0, damp=4500.0)


@reg("shutter_roll", 2.5, fade_out=0.15)
def s_shutter_roll(rng):
    n = ns(2.5)

    def mot(t):
        if t < 0.08:
            return 0.0
        if t < 0.25:
            return smoothstep((t - 0.08) / 0.17)
        if t < 2.15:
            return 1.0
        if t < 2.26:
            return 1.0 - smoothstep((t - 2.15) / 0.11)
        return 0.0

    m = [mot(i / SR) for i in range(n)]
    imp = zeros(n)
    t = 0.1
    while t < 2.24:
        r = 16.0 + 10.0 * min(1.0, t / 0.8)
        g = mot(t)
        i = ns(t)
        for _ in range(rng.randint(2, 4)):
            j = i + rng.randrange(ns(0.006))
            if j < n:
                imp[j] += rng.uniform(0.4, 1.0) * g * rng.choice((-1.0, 1.0))
        t += (1.0 / r) * (1.0 + 0.08 * rng.uniform(-1.0, 1.0))
    for _ in range(600):
        tt = rng.uniform(0.1, 2.24)
        i = ns(tt)
        imp[i] += rng.uniform(-0.2, 0.2) * mot(tt)
    metal = zeros(n)
    for k, (f, q) in enumerate(((740, 18), (1180, 22), (1690, 25), (2350, 25), (3100, 30), (4400, 30), (5900, 30))):
        metal = addv(metal, nrm(bp(imp, f, q)), 1.0 / (1.0 + 0.2 * k))
    rattle = addv(nrm(metal), nrm(hp(imp, 1500.0)), 0.35)
    mf = [85.0 + 25.0 * x for x in m]
    motor = lp(lp(saw_var(mf), 450.0), 450.0)
    motor = mul(addv(nrm(motor), osc([2 * f for f in mf]), 0.2), m)
    rum = mul(lp(brown(n, rng), 180.0), m)
    out = addv(rattle, nrm(motor), 0.22)
    out = addv(out, nrm(rum), 0.25)
    # start jolt and stop clunk
    mix(out, relay_clunk(rng, 1.0), ns(0.06), 0.6)
    sc = thump(ns(0.4), 80.0, 50.0, 0.03, 0.09, 0.001)
    mix(sc, modes(ns(0.4), [210, 340, 520, 780, 1150], [0.3, 0.25, 0.2, 0.14, 0.1],
                  [0.2, 0.15, 0.12, 0.08, 0.05], rng), 0, 0.6)
    mix(sc, click(rng, ns(0.005), 0.0006, 1000.0), 0, 0.5)
    mix(out, sc, ns(2.26), 1.0)
    return verb(out, 0.3, 1.0, rt60=0.9, size=1.2, damp=5000.0)


@reg("camera_shutter", 0.25, fade_out=0.03)
def s_camera_shutter(rng):
    n = ns(0.25)
    out = zeros(n)
    c1 = modes(ns(0.05), [3400.0, 5200.0, 700.0], [0.4, 0.25, 0.3], [0.006, 0.004, 0.008], rng)
    mix(c1, click(rng, ns(0.004), 0.0006, 2500.0), 0, 0.9)
    mix(out, c1, ns(0.01), 0.8)
    wr = mul(bp(white(ns(0.05), rng), 4000.0, 2.0), env_pts(ns(0.05), [(0, 0), (0.02, 1.0), (0.05, 0.0)]))
    mix(out, nrm(wr), ns(0.028), 0.06)
    c2 = modes(ns(0.08), [1900.0, 2900.0, 260.0], [0.4, 0.25, 0.5], [0.01, 0.008, 0.015], rng)
    mix(c2, nrm(bp(burst(ns(0.01), rng, 0.0015), 2200.0, 1.0)), 0, 0.8)
    mix(out, c2, ns(0.085), 0.9)
    return verb(out, 0.12, 1.0, rt60=0.25, size=0.35, damp=7000.0)


@reg("clock_punch", 0.8, fade_out=0.08)
def s_clock_punch(rng):
    n = ns(0.8)
    out = zeros(n)
    ka = modes(ns(0.06), [2200.0, 3600.0, 1100.0], [0.4, 0.25, 0.3], [0.01, 0.007, 0.012], rng)
    mix(ka, click(rng, ns(0.004), 0.0005, 1500.0), 0, 0.8)
    mix(out, ka, ns(0.01), 0.45)
    gn = ns(0.07)
    gi = zeros(gn)
    tt = 0.0
    while tt < 0.07:
        gi[min(gn - 1, ns(tt))] = rng.uniform(0.5, 1.0)
        tt += 1.0 / (120.0 + 900.0 * tt)
    gi = mul(bp(gi, 2000.0, 3.0), env_pts(gn, [(0, 0.3), (0.07, 1.0)]))
    mix(out, nrm(gi), ns(0.045), 0.12)
    tc = ns(0.12)
    mix(out, thump(ns(0.4), 110.0, 65.0, 0.02, 0.07, 0.001), tc, 1.0)
    mix(out, modes(ns(0.35), [520, 860, 1340, 1990, 2730], [0.4, 0.3, 0.22, 0.15, 0.1],
                   [0.12, 0.09, 0.07, 0.05, 0.03], rng), tc, 0.6)
    mix(out, nrm(burst(ns(0.05), rng, 0.01, None, 1500.0)), tc, 0.6)
    for _ in range(6):
        mix(out, nrm(click(rng, ns(0.004), 0.0004, 1800.0)), tc + ns(rng.uniform(0.01, 0.08)),
            rng.uniform(0.05, 0.2))
    td = ns(0.22)
    ding = bell(n - td, 1760.0, rng, decay=0.6, bright=0.9, strike=0.1)
    mix(out, ding, td, 0.35)
    return verb(out, 0.25, 1.0, rt60=0.6, size=0.7, damp=6000.0)


@reg("luggage_thump", 0.5, fade_out=0.06)
def s_luggage_thump(rng):
    n = ns(0.5)
    out = zeros(n)
    for t0, a in ((0.01, 1.0), (0.12, 0.35)):
        ev = thump(ns(0.3), 95.0, 60.0, 0.02, 0.06, 0.001)
        mix(ev, nrm(burst(ns(0.12), rng, 0.02, None, 400.0)), 0, 0.7)
        mix(ev, modes(ns(0.15), [380.0, 610.0], [0.35, 0.2], [0.035, 0.025], rng), 0)
        mix(ev, nrm(bp(burst(ns(0.01), rng, 0.002), 1800.0, 1.0)), 0, 0.3)
        mix(out, ev, ns(t0), a)
    t = 0.03
    a = 0.3
    while t < 0.3:
        c = modes(ns(0.03), [rng.uniform(1600.0, 3000.0)], [1.0], [0.004], rng)
        mix(c, nrm(bp(burst(ns(0.003), rng, 0.0008), rng.uniform(2500.0, 4000.0), 1.5)), 0, 0.8)
        mix(out, c, ns(t), a * rng.uniform(0.5, 1.0))
        t += rng.uniform(0.02, 0.05)
        a *= 0.82
    return verb(out, 0.18, 1.0, rt60=0.5, size=0.8, damp=5000.0)


@reg("metal_detector", 1.2, fade_out=0.1)
def s_metal_detector(rng):
    n = ns(1.2)
    out = zeros(n)
    bn = ns(0.27)
    env = env_pts(bn, [(0, 0), (0.003, 1.0), (0.264, 1.0), (0.27, 0.0)])
    wl = TAU * 14.0 / SR
    fr = [2000.0 + 160.0 * _tanh(3.0 * _sin(wl * i)) for i in range(bn)]
    tone = sat(osc(fr), 2.2)
    tone = addv(tone, bp(tone, 2000.0, 1.5), 0.5)
    tone = mul(tone, env)
    for t0 in (0.02, 0.42, 0.82):
        mix(out, tone, ns(t0))
    return verb(out, 0.18, 1.0, rt60=0.9, size=1.2, damp=6000.0)


def _buzz120(n, rng):
    w = TAU * 120.0 / SR
    s = [_sin(w * i) for i in range(n)]
    x = [0.5 * _tanh(4.0 * v) + 0.6 * ((v if v > 0.0 else 0.0) - 0.318) for v in s]
    sz = hp(mul(white(n, rng), [(v if v > 0.0 else 0.0) ** 8 for v in s]), 2000.0)
    return addv(peq(hp(x, 100.0), 2000.0, 1.0, 4.0), nrm(sz), 0.4)


@reg("flicker_zap", 0.35, fade_out=0.03)
def s_flicker_zap(rng):
    n = ns(0.35)
    bz = _buzz120(n, rng)
    gate = env_pts(n, [(0.0, 0.0), (0.003, 1.0), (0.045, 1.0), (0.05, 0.0), (0.07, 0.0), (0.072, 0.7),
                       (0.10, 0.7), (0.103, 0.0), (0.13, 0.0), (0.133, 1.0), (0.22, 0.9), (0.225, 0.0),
                       (0.25, 0.0), (0.252, 0.5), (0.27, 0.4), (0.275, 0.0)])
    out = scale(nrm(mul(bz, gate)), 0.6)
    for tz, dz in ((0.0, 0.02), (0.13, 0.025), (0.25, 0.012)):
        zn = ns(dz + 0.01)
        z = zeros(zn)
        for _ in range(int(dz * 3000)):
            z[rng.randrange(ns(dz))] += rng.uniform(-1.0, 1.0)
        z = hp(z, 1500.0)
        mix(z, white(ns(0.004), rng), 0, 0.8)
        mix(out, nrm(z), ns(tz) + ns(0.002), 0.9)
    mix(out, modes(ns(0.05), [4500.0], [1.0], [0.008], rng), ns(0.002), 0.2)
    return verb(out, 0.15, 1.0, rt60=0.4, size=0.5, damp=7000.0)


@reg("power_down", 2.5, fade_out=0.2)
def s_power_down(rng):
    n = ns(2.5)
    out = zeros(n)
    mix(out, relay_clunk(rng, 1.3), ns(0.01), 1.0)
    mix(out, thump(ns(0.8), 60.0, 45.0, 0.05, 0.3, 0.003), ns(0.012), 0.6)
    # descending whine 800 -> 40 Hz
    wn = n - ns(0.03)
    T = 2.25
    fr = [800.0 * (40.0 / 800.0) ** min(1.0, (i / SR / T) ** 0.8) for i in range(wn)]
    ph = phases(fr)
    wob = smooth_rand(wn, 30, rng)
    wh = [(_sin(p) + 0.3 * _sin(2 * p) + 0.12 * _sin(3 * p)) * (f / 800.0) ** 0.45 * (1.0 + 0.05 * w)
          for p, f, w in zip(ph, fr, wob)]
    wh = mul(wh, env_pts(wn, [(0, 0), (0.03, 1.0), (1.8, 0.6), (2.4, 0.0)]))
    mix(out, wh, ns(0.03), 0.5)
    # mains hum dying, pitch drooping
    hf = [60.0 - 8.0 * min(1.0, i / ns(1.6)) for i in range(n)]
    hph = phases(hf)
    hm = [(_sin(p) + 0.6 * _sin(2 * p) + 0.25 * _sin(3 * p)) for p in hph]
    hm = mul(hm, env_exp(n, 0.6))
    mix(out, fade_in(hm, 0.01), 0, 0.35)
    for _ in range(5):
        mix(out, nrm(click(rng, ns(0.006), 0.0008, 1500.0)), ns(rng.uniform(0.02, 0.3)), rng.uniform(0.1, 0.3))
    return verb(out, 0.4, 1.0, rt60=1.6, size=1.3, damp=4500.0)


@reg("power_up", 2.0, fade_out=0.35)
def s_power_up(rng):
    n = ns(2.0)
    out = zeros(n)
    mix(out, relay_clunk(rng, 1.2), ns(0.01), 1.0)
    wn = n - ns(0.04)
    fr = [520.0 * (60.0 / 520.0) ** _exp(-(i / SR) / 0.35) for i in range(wn)]
    ph = phases(fr)
    wh = [(_sin(p) + 0.3 * _sin(2 * p) + 0.1 * _sin(3 * p)) for p in ph]
    wh = mul(wh, env_pts(wn, [(0, 0), (0.05, 0.3), (0.8, 0.8), (1.96, 0.8)]))
    mix(out, wh, ns(0.04), 0.4)
    hm = [(_sin(TAU * 60.0 * i / SR) + 0.6 * _sin(TAU * 120.0 * i / SR) + 0.2 * _sin(TAU * 180.0 * i / SR))
          * (1.0 - _exp(-(i / SR) / 0.4)) for i in range(n)]
    mix(out, hm, 0, 0.3)
    return verb(out, 0.35, 1.0, rt60=1.4, size=1.2, damp=5000.0)


@reg("glitch", 0.6, fade_out=0.02)
def s_glitch(rng):
    n = ns(0.6)
    out = zeros(n)

    def seg(t0, x, g=1.0):
        x = fade_out(fade_in(x, 0.0006), 0.0006)
        mix(out, x, ns(t0), g)

    seg(0.000, crush(white(ns(0.05), rng), 3, 12), 0.9)
    gr = crush(rsquare(ns(0.025), 900.0, 4.0), 4, 8)
    gr = [v * (1.0 if (i // 300) % 2 == 0 else 0.4) for i, v in enumerate(gr)]
    for k in range(4):
        seg(0.06 + 0.025 * k, gr, 0.8)
    seg(0.17, crush(white(ns(0.004), rng), 2, 1), 0.7)
    seg(0.21, crush(addv(osc([1720.0] * ns(0.08)), white(ns(0.08), rng), 0.2), 4, 20), 0.75)
    g2 = crush(addv(osc([340.0 + 2000.0 * rng.random()] * ns(0.015)), white(ns(0.015), rng), 0.5), 3, 6)
    t = 0.30
    for k in range(8):
        seg(t, g2[:max(60, len(g2) - k * 70)], 0.85 - 0.06 * k)
        t += 0.015 - k * 0.0008
    seg(0.43, crush(lp(white(ns(0.06), rng), 3000.0), 3, 30), 1.0)
    seg(0.50, mul(crush(square_blep(ns(0.08), 220.0), 2, 4), env_pts(ns(0.08), [(0, 1.0), (0.08, 0.0)])), 0.6)
    return out


@reg("stinger_hit", 3.0, fade_out=0.5)
def s_stinger_hit(rng):
    n = ns(3.0)
    hit_t = 0.4
    # reverse swell: reverberate a short noisy metallic burst, play the reverb backwards
    sn = ns(1.2)
    src = zeros(sn)
    mix(src, nrm(burst(ns(0.25), rng, 0.06, None, 5000.0)), 0)
    mix(src, modes(ns(0.25), [311.1, 466.2, 739.9, 1244.5], [0.3, 0.25, 0.2, 0.1], [0.1, 0.08, 0.06, 0.05], rng), 0, 0.5)
    sw = reverb(src, rt60=1.4, size=1.3, damp=6000.0)
    s0 = ns(0.02)
    swell = sw[s0:s0 + ns(hit_t)][::-1]
    swell = mul(swell, [(i / len(swell)) ** 2 for i in range(len(swell))])
    out = zeros(n)
    mix(out, nrm(swell), 0, 0.6)
    hn = n - ns(hit_t)
    hit = thump(hn, 75.0, 40.0, 0.08, 0.9, 0.002)
    parts = [233.1, 311.1 * 1.013, 466.2 * 0.991, 554.4 * 1.02, 739.9, 987.8 * 1.03, 1244.5 * 0.985,
             1661.2, 2217.5 * 1.012, 2960.0]
    cl = modes(hn, parts, [0.30, 0.28, 0.25, 0.22, 0.2, 0.17, 0.15, 0.12, 0.1, 0.08],
               [1.6, 1.4, 1.2, 1.1, 0.9, 0.8, 0.7, 0.6, 0.5, 0.4], rng)
    cl = addv(cl, modes(hn, [p + 3.0 for p in parts], [0.15] * 10, [0.9] * 10, rng))
    hit = addv(hit, nrm(cl), 0.7)
    hit = addv(hit, nrm(burst(hn, rng, 0.06, None, 3000.0)), 0.8)
    hit = addv(hit, nrm(burst(hn, rng, 0.015, 2000.0)), 0.4)
    hit = sat(nrm(hit), 1.5)
    mix(out, hit, ns(hit_t))
    return verb(out, 0.85, 1.0, rt60=3.2, size=1.8, damp=2500.0, predelay=0.02)


@reg("stinger_soft", 3.0, fade_out=0.3)
def s_stinger_soft(rng):
    n = ns(3.0)
    u = [min(1.0, i / ns(2.8)) for i in range(n)]
    fa = [830.0 * (1.0 + 0.07 * smoothstep(x)) for x in u]      # two close tones sliding apart
    fb = [828.0 * (1.0 + 0.02 * smoothstep(x)) for x in u]      # (2 Hz -> ~42 Hz beating)
    out = zeros(n)
    for fr, a in ((fa, 1.0), (fb, 0.7)):
        ph = phases(fr)
        out = addv(out, [_sin(p) + 0.12 * _sin(2 * p) + 0.05 * _sin(3 * p) for p in ph], a)
    out = mul(out, env_pts(n, [(0, 0), (0.7, 0.8), (1.6, 1.0), (2.95, 0.0)]))
    out = trem(out, 3.1, 0.15)
    br = mul(bp(white(n, rng), 840.0, 30.0), env_pts(n, [(0, 0), (1.0, 1.0), (2.9, 0.0)]))
    out = addv(nrm(out), nrm(br), 0.12)
    return verb(out, 0.6, 1.0, rt60=2.5, size=1.5, damp=6000.0, predelay=0.02)


@reg("sub_boom", 3.0, fade_out=0.4)
def s_sub_boom(rng):
    n = ns(3.0)
    out = zeros(n)
    t0 = ns(0.01)
    b = thump(n - t0, 58.0, 37.0, 0.12, 0.85, 0.004)
    nz = lp(lp(brown(n - t0, rng), 90.0), 90.0)
    nz = mul(nrm(nz), env_exp(n - t0, 0.35))
    x = sat(nrm(addv(b, nz, 0.5)), 1.5)
    mix(out, x, t0)
    send = hp(hp(out, 70.0), 70.0)
    wet = reverb(send, rt60=2.8, size=1.8, damp=500.0)
    return addv(out, wet, 0.9)


@reg("death_sting", 2.5, fade_out=0.3)
def s_death_sting(rng):
    n = ns(2.5)
    low = (45, 46, 51, 52, 56, 57, 58, 63, 64, 69, 70, 75)
    x = zeros(n)
    for m in low:
        f = mtof(m)
        x = addv(x, saw_sum(n, [f * 2.0 ** (rng.uniform(-14.0, 14.0) / 1200.0) for _ in range(3)], rng), 1.0 / 3.0)
    hi = zeros(n)
    for m in (76, 77, 83, 88):
        f = mtof(m)
        hi = addv(hi, saw_sum(n, [f * 2.0 ** (rng.uniform(-10.0, 10.0) / 1200.0) for _ in range(2)], rng), 0.5)
    hi = mul(hi, env_exp(n, 0.25))
    x = addv(nrm(x), nrm(hi), 0.35)
    cut = [600.0 + 5400.0 * _exp(-(i / SR) / 0.35) for i in range(n)]
    x = svf(x, cut, 1.2, "lp")
    env = env_pts(n, [(0, 0), (0.015, 1.0), (0.3, 0.45), (2.4, 0.0)])
    x = mul(nrm(x), [e ** 1.6 for e in env])
    out = scale(x, 1.0)
    out = addv(out, nrm(bp(burst(n, rng, 0.08), 1500.0, 0.5)), 0.6)
    out = addv(out, nrm(click(rng, n, 0.002, 500.0)), 0.5)
    out = addv(out, thump(n, 50.0, 32.0, 0.1, 0.5, 0.002), 1.0)
    out = sat(nrm(out), 1.6)
    out = verb(out, 0.4, 1.0, rt60=1.2, size=1.2, damp=4000.0)
    return mul(out, env_pts(n, [(0, 1.0), (1.6, 1.0), (2.45, 0.0)]))


@reg("eyes_close", 0.5, fade_out=0.02)
def s_eyes_close(rng):
    n = ns(0.5)
    cut = 0.36
    ic = ns(cut)
    src = addv(nrm(brown(n, rng)), white(n, rng), 0.08)
    ctl = [110.0 + 300.0 * (min(i, ic) / ic) ** 1.5 for i in range(n)]
    x = svf(src, ctl, 1.4, "lp")
    env = [((i / ic) ** 2.2 if i < ic else 0.0) for i in range(n)]
    sub = [_sin(TAU * 52.0 * i / SR) for i in range(n)]
    x = addv(nrm(x), sub, 0.5)
    x = mul(x, env)
    # 20 ms release instead of a hard cut
    rn = ns(0.02)
    for j in range(rn):
        if ic + j < n:
            x[ic + j] = 0.0
    xr = x[ic - rn:ic]
    x[ic - rn:ic] = [v * (0.5 + 0.5 * _cos(PI * (k + 1) / rn)) for k, v in enumerate(xr)]
    return x


@reg("tension_rise", 8.0, fade_out=0.004)
def s_tension_rise(rng):
    n = ns(8.0)
    T = 8.0
    # Shepard-like rising tone: 9 octave-spaced partials under a fixed spectral envelope
    S = [1.7 * ((i / SR) / T) ** 1.35 for i in range(n)]
    K = 9
    fmin = 27.5
    sh = zeros(n)
    for k in range(K):
        pos = [(k + s) % K for s in S]
        fr = [fmin * 2.0 ** p for p in pos]
        am = [_exp(-0.5 * ((p - 4.0) / 1.3) ** 2) for p in pos]
        ph = phases(fr, rng.random() * TAU)
        sh = [o + a * _sin(p) for o, a, p in zip(sh, am, ph)]
    ramp = [(i / n) for i in range(n)]
    sh = mul(nrm(sh), [0.25 + 0.75 * r for r in ramp])
    nz = svf(pink(n, rng), [300.0 * (3500.0 / 300.0) ** r for r in ramp], 0.8, "bp")
    nz = mul(nrm(nz), [r ** 2.2 for r in ramp])
    dr = lp(lp(saw_sum(n, [55.0, 55.3], rng), 250.0), 250.0)
    dr = mul(nrm(dr), ramp)
    pulse = zeros(n)
    t = 0.3
    while t < T - 0.05:
        r = t / T
        a = 0.4 + 0.6 * r
        p = thump(ns(0.3), 80.0, 50.0, 0.02, 0.07, 0.002)
        mix(p, dsine(ns(0.02), 2500.0, 0.15 + 0.3 * r, 0.004), 0)
        mix(pulse, p, ns(t), a)
        t += 0.85 * (0.13 / 0.85) ** (r ** 1.1)
    out = addv(addv(scale(sh, 0.7), nz, 0.45), dr, 0.35)
    out = addv(out, nrm(pulse), 0.8)
    out = sat(nrm(out), 1.2)
    return out


@reg("ending_tone", 10.0, fade_out=0.3)
def s_ending_tone(rng):
    n = ns(10.0)
    pad = zeros(n)
    # Fmaj7 (F2 F3 A3 C4 E4) -> Am (A2 E3 A3 C4 E4); A3 C4 E4 sustain through
    voices = ((41, 0.0, 5.6, 0.9), (53, 0.0, 5.6, 0.7), (57, 0.0, 10.0, 0.7), (60, 0.0, 10.0, 0.65),
              (64, 0.0, 10.0, 0.6), (45, 4.6, 10.0, 0.9), (52, 4.6, 10.0, 0.7))
    for m, t0, t1, a in voices:
        f = mtof(m)
        i0 = ns(t0)
        vn = min(n, ns(t1 + 1.6)) - i0
        x = saw_sum(vn, [f * 2.0 ** (-4.0 / 1200.0), f * 2.0 ** (5.0 / 1200.0)], rng)
        x = addv(x, dsine(vn, f), 0.8)
        e = env_pts(vn, [(0, 0), (1.8, 1.0), (t1 - t0, 1.0), (t1 - t0 + 1.6, 0.0)])
        mix(pad, mul(x, [smoothstep(v) for v in e]), i0, a)
    cut = lfo(n, [(150.0, 1, 0.0), (60.0, 3, 1.0)], 850.0)
    pad = lp(svf(pad, cut, 0.8, "lp"), 3000.0)
    pad = nrm(pad)
    bl = zeros(n)
    for m, t0 in ((69, 0.4), (76, 2.3), (72, 4.9), (69, 6.7)):
        mix(bl, bell(n - ns(t0), mtof(m), rng, decay=2.2, bright=0.55, strike=0.02), ns(t0), 0.3)
    out = addv(pad, bl)
    out = verb(out, 0.6, 1.0, rt60=3.8, size=1.6, damp=4000.0, predelay=0.02)
    fe = env_pts(n, [(0, 1.0), (6.0, 1.0), (9.9, 0.0)])
    return mul(out, [e * e for e in fe])


@reg("distant_door", 1.5, peak_db=-10.0, fade_out=0.45)
def s_distant_door(rng):
    n = ns(1.5)
    dry = zeros(n)
    t0 = ns(0.01)
    mix(dry, thump(ns(0.4), 70.0, 50.0, 0.03, 0.07, 0.003), t0, 0.7)
    mix(dry, nrm(lp(burst(ns(0.25), rng, 0.045), 600.0)), t0, 1.0)
    mix(dry, nrm(lp(click(rng, ns(0.02), 0.002, 800.0), 1500.0)), t0 + ns(0.012), 0.3)
    dry = lp(lp(dry, 700.0), 900.0)
    return verb(dry, 1.0, 0.3, rt60=3.5, size=1.6, damp=1800.0, predelay=0.015)


@reg("distant_footsteps", 3.0, peak_db=-12.0, fade_out=0.3)
def s_distant_footsteps(rng):
    n = ns(3.0)
    dry = zeros(n)
    for k, t0 in enumerate((0.10, 0.62, 1.12, 1.63, 2.13, 2.64)):
        st = _tile_step_dry(rng)
        mix(dry, st, ns(t0 + rng.uniform(-0.015, 0.015)), rng.uniform(0.8, 1.0))
    dry = lp(lp(dry, 1600.0), 1600.0)
    return verb(dry, 1.0, 0.35, rt60=3.2, size=1.6, damp=2000.0, predelay=0.02)


# =============================================================================
# finishing, WAV I/O, verification
# =============================================================================

def finish_oneshot(x, spec):
    n = ns(spec["dur"])
    x = fit(list(x), n)
    x = hp(x, 18.0)                         # DC / sub-sonic blocker
    fade_in(x, 0.002)
    fade_out(x, spec["fade_out"])
    return nrm(x, db(spec["peak_db"] - 0.02))


def finish_loop(y, spec):
    n = ns(spec["dur"])
    if len(y) != n:
        raise RuntimeError("%s: loop has %d samples, expected %d" % (spec["name"], len(y), n))
    y = circ(list(y), lambda v: hp(v, 18.0), ns(1.0))   # seamless DC / sub-sonic blocker
    g = db(spec["rms_db"]) / rms(y)
    pk = peak(y) * g
    lim = db(-3.0 - 0.05)
    if pk > lim:
        g *= lim / pk
    return [v * g for v in y]


def to_pcm16(x, rng):
    """float [-1,1] -> array('h') with TPDF dither"""
    r = rng.random
    out = array("h", [0]) * len(x)
    for i, v in enumerate(x):
        s = int(round(v * 32767.0 + (r() - r())))
        if s > 32767:
            s = 32767
        elif s < -32768:
            s = -32768
        out[i] = s
    return out


def wav_bytes(pcm, loop):
    if sys.byteorder != "little":
        pcm = array("h", pcm)
        pcm.byteswap()
    data = pcm.tobytes()
    fmt = struct.pack("<HHIIHH", 1, 1, SR, SR * 2, 2, 16)
    chunks = [b"fmt " + struct.pack("<I", len(fmt)) + fmt,
              b"data" + struct.pack("<I", len(data)) + data + (b"\x00" if len(data) & 1 else b"")]
    if loop:
        n = len(pcm)
        # smpl header: manufacturer, product, sample_period(ns), midi_unity_note,
        # midi_pitch_fraction, smpte_format, smpte_offset, num_sample_loops, sampler_data
        smpl = struct.pack("<9I", 0, 0, int(round(1e9 / SR)), 60, 0, 0, 0, 1, 0)
        # loop: cue_point_id, type (0 = forward), start, end (inclusive), fraction, play_count (0 = inf)
        smpl += struct.pack("<6I", 0, 0, 0, n - 1, 0, 0)
        chunks.append(b"smpl" + struct.pack("<I", len(smpl)) + smpl)
    body = b"WAVE" + b"".join(chunks)
    return b"RIFF" + struct.pack("<I", len(body)) + body


def render(spec):
    t0 = time.perf_counter()
    rng = random.Random(spec["seed"])
    y = spec["fn"](rng)
    y = finish_loop(y, spec) if spec["loop"] else finish_oneshot(y, spec)
    pcm = to_pcm16(y, random.Random(spec["seed"] ^ 0x5EED))
    path = os.path.join(OUT_DIR, spec["name"] + ".wav")
    with open(path, "wb") as f:
        f.write(wav_bytes(pcm, spec["loop"]))
    return spec["name"], time.perf_counter() - t0


def _render_by_name(name):
    for s in REG:
        if s["name"] == name:
            return render(s)
    raise KeyError(name)


def read_wav(path):
    with open(path, "rb") as f:
        b = f.read()
    info = {"size": len(b), "errors": []}
    err = info["errors"]
    if b[:4] != b"RIFF" or b[8:12] != b"WAVE":
        err.append("not RIFF/WAVE")
        return info
    if struct.unpack("<I", b[4:8])[0] + 8 != len(b):
        err.append("RIFF size mismatch")
    pos = 12
    while pos + 8 <= len(b):
        cid = b[pos:pos + 4]
        size = struct.unpack("<I", b[pos + 4:pos + 8])[0]
        body = b[pos + 8:pos + 8 + size]
        if len(body) != size:
            err.append("truncated chunk %r" % cid)
            break
        if cid == b"fmt ":
            tag, ch, sr, br, ba, bits = struct.unpack("<HHIIHH", body[:16])
            info["fmt"] = (tag, ch, sr, br, ba, bits)
            if (tag, ch, sr, br, ba, bits) != (1, 1, SR, SR * 2, 2, 16):
                err.append("unexpected fmt %r" % (info["fmt"],))
        elif cid == b"data":
            a = array("h")
            a.frombytes(body)
            if sys.byteorder != "little":
                a.byteswap()
            info["pcm"] = a
        elif cid == b"smpl":
            if size != 60:
                err.append("smpl size %d != 60" % size)
            hdr = struct.unpack("<9I", body[:36])
            info["smpl_hdr"] = hdr
            loops = [struct.unpack("<6I", body[36 + 24 * k:60 + 24 * k]) for k in range(hdr[7])]
            info["loops"] = loops
        pos += 8 + size + (size & 1)
    if pos != len(b):
        err.append("trailing bytes / bad padding")
    if "fmt" not in info:
        err.append("no fmt chunk")
    if "pcm" not in info:
        err.append("no data chunk")
    return info


def verify(specs):
    rows = []
    ok_all = True
    for s in specs:
        path = os.path.join(OUT_DIR, s["name"] + ".wav")
        if not os.path.isfile(path):
            rows.append((s["name"], "-", "-", "-", "-", "MISSING"))
            ok_all = False
            continue
        info = read_wav(path)
        probs = list(info["errors"])
        pcm = info.get("pcm", array("h"))
        n = len(pcm)
        secs = n / SR
        if n == 0:
            probs.append("empty")
        pk = max(max(pcm), -min(pcm)) / 32768.0 if n else 0.0
        rm = math.sqrt(sum(map(operator.mul, pcm, pcm)) / n) / 32768.0 if n else 0.0
        pk_db, rm_db = lin2db(pk), lin2db(rm)
        exp_n = ns(s["dur"])
        if n != exp_n:
            probs.append("len %d != %d" % (n, exp_n))
        if rm_db < -60.0:
            probs.append("near-silent")
        if max(pcm, default=0) >= 32767 or min(pcm, default=0) <= -32768:
            probs.append("CLIPPED")
        extra = ""
        if s["loop"]:
            if pk_db > -3.0 + 1e-6:
                probs.append("peak > -3 dBFS")
            lo = info.get("loops")
            if not lo or len(lo) != 1:
                probs.append("missing smpl loop")
            else:
                cue, typ, st, en, fr, pc = lo[0]
                if (typ, st, en) != (0, 0, n - 1):
                    probs.append("bad smpl loop %r" % (lo[0],))
            # seam: jump across the wrap vs. typical sample-to-sample step
            steps = sum(abs(pcm[i] - pcm[i - 1]) for i in range(1, n)) / (n - 1)
            jump = abs(pcm[0] - pcm[-1])
            w = min(2048, n // 4)
            ra = math.sqrt(sum(v * v for v in pcm[-w:]) / w) + 1e-9
            rb = math.sqrt(sum(v * v for v in pcm[:w]) / w) + 1e-9
            extra = "seam %.2fx, %+.1f dB" % (jump / (steps + 1e-9), 20 * math.log10(rb / ra))
            if jump > 6.0 * steps + 64:
                probs.append("seam jump")
        else:
            if pk_db > s["peak_db"] + 1e-6:
                probs.append("peak > %.0f dBFS" % s["peak_db"])
        status = "ok" if not probs else "; ".join(probs)
        ok_all = ok_all and not probs
        rows.append((s["name"] + ".wav", "%.3f" % secs, "%.2f" % pk_db, "%.2f" % rm_db, extra, status))
    hdr = ("file", "seconds", "peak dBFS", "RMS dBFS", "loop seam", "status")
    wid = [max(len(str(r[i])) for r in rows + [hdr]) for i in range(len(hdr))]
    line = "  ".join(h.ljust(w) for h, w in zip(hdr, wid))
    print(line)
    print("-" * len(line))
    for r in rows:
        print("  ".join(str(c).ljust(w) for c, w in zip(r, wid)))
    print("-" * len(line))
    print("%d files, %s" % (len(rows), "all OK" if ok_all else "PROBLEMS FOUND"))
    return ok_all


def main(argv):
    jobs = None
    filters = []
    only_verify = False
    it = iter(argv)
    for a in it:
        if a == "--verify":
            only_verify = True
        elif a == "-j":
            jobs = int(next(it))
        elif a.startswith("-j"):
            jobs = int(a[2:])
        else:
            filters.append(a)
    specs = [s for s in REG if not filters or any(f in s["name"] for f in filters)]
    if not specs:
        print("no sound matches", filters)
        return 2
    os.makedirs(OUT_DIR, exist_ok=True)
    if not only_verify:
        t0 = time.perf_counter()
        names = [s["name"] for s in specs]
        # longest jobs first for better pool utilisation
        names.sort(key=lambda nm: -next(s["dur"] for s in REG if s["name"] == nm))
        if jobs is None:
            jobs = min(len(names), max(1, (os.cpu_count() or 1) - 1), 12)
        done = False
        if jobs > 1 and len(names) > 1:
            try:
                from concurrent.futures import ProcessPoolExecutor
                with ProcessPoolExecutor(max_workers=jobs) as ex:
                    for name, dt in ex.map(_render_by_name, names):
                        print("  %-24s %6.2f s" % (name, dt), flush=True)
                done = True
            except Exception as e:  # pragma: no cover - fall back to serial rendering
                print("process pool unavailable (%s); rendering serially" % e)
        if not done:
            for nm in names:
                name, dt = _render_by_name(nm)
                print("  %-24s %6.2f s" % (name, dt), flush=True)
        print("generated %d files in %.1f s -> %s\n" % (len(names), time.perf_counter() - t0, OUT_DIR))
    return 0 if verify(specs) else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

"""GATE 0 — catching your breath after a run (Player._update_breath).

Usage (from the project root):  py -I tools/gen_breath.py
Writes assets/audio/sfx/breath_run_1.wav … breath_run_5.wav (44.1 kHz 16-bit mono): one slow, soft mouth breath each —
an airy inhale that swells in, a short catch, then a long, relaxed "haa" that eases out (a breath of voice at most). The player plays them one
at a time (Snd.variant), closer together and louder the more out of breath they are, so the rhythm slows down by
itself as they recover — a loop cannot do that. Close and dry: it is your own breath.
The frightened breathing loop (breath_loop, ElevenLabs) stays for the closed-eyes scare.
Pure Python (gen_sfx's filters), a few seconds.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_sfx as g   # noqa: E402

SR = g.SR
# inhale s, exhale s, formant scale, voice level, f0 Hz
TAKES = [
    (0.55, 0.80, 1.00, 0.03, 120.0),
    (0.50, 0.74, 1.03, 0.00, 126.0),
    (0.60, 0.86, 0.97, 0.04, 116.0),
    (0.52, 0.78, 1.01, 0.00, 122.0),
    (0.57, 0.82, 0.99, 0.02, 118.0),
]


def resonate(src, formants, sweep):
    """Noise through vocal-tract resonances [(Hz, Q, gain)], all moving by `sweep` (start->end factor)."""
    n = len(src)
    out = [0.0] * n
    for f, q, gain in formants:
        ctl = [f * (1.0 + (sweep - 1.0) * i / n) for i in range(n)]
        out = g.addv(out, g.svf(src, ctl, q, "bp"), gain)
    return out


def inhale(rng, dur, fs):
    n = g.ns(dur)
    src = g.white(n, rng)
    # air pulled in through an open mouth: thin and airy, the tongue rising a little as it goes
    x = resonate(src, [(1050 * fs, 2.2, 0.7), (1800 * fs, 3.0, 0.8), (2700 * fs, 4.0, 0.35), (4000 * fs, 4.0, 0.1)], 1.06)
    x = g.addv(g.nrm(x), g.nrm(g.hp(src, 1400.0)), 0.05)
    x = g.lp(g.lp(x, 3600.0), 3600.0)
    env = g.env_pts(n, [(0.0, 0.0), (dur * 0.3, 0.55), (dur * 0.75, 0.9), (dur * 0.9, 1.0), (dur, 0.0)])
    wob = g.smooth_rand(n, 6, rng)
    return [v * e * e * (1.0 + 0.1 * w) for v, e, w in zip(x, env, wob)]


def glottal(rng, n, f0, f1):
    """A soft breathy buzz gliding f0 -> f1 (a little jitter), for the voiced start of the exhale."""
    out = [0.0] * n
    ph = 0.0
    jit = g.smooth_rand(n, 8, rng)
    for i in range(n):
        f = (f0 + (f1 - f0) * i / n) * (1.0 + 0.02 * jit[i])
        ph += f / SR
        ph -= math.floor(ph)
        out[i] = math.sin(math.pi * ph) ** 6 - 0.3   # rounded pulse, no hard edge
    return g.lp(g.lp(out, 1800.0), 1800.0)


def exhale(rng, dur, fs, voice, f0):
    n = g.ns(dur)
    src = g.white(n, rng)
    # "hah": breath through an open, relaxed mouth (an /a/-like tract) that closes a little as it ends
    tract = [(760 * fs, 5.0, 1.0), (1250 * fs, 5.5, 0.75), (2550 * fs, 6.0, 0.28), (3500 * fs, 6.0, 0.08)]
    x = g.nrm(resonate(src, tract, 0.9))
    x = g.addv(x, g.nrm(g.lp(g.lp(src, 900.0), 900.0)), 0.35)
    x = g.lp(g.lp(x, 2400.0), 2400.0)          # breath is dark: the hiss above 3 kHz is what gives synthetic air away
    if voice > 0.0:
        v = g.nrm(resonate(glottal(rng, n, f0, f0 * 0.85), tract, 0.9))
        venv = g.env_pts(n, [(0.0, 0.0), (0.08, 1.0), (dur * 0.3, 0.3), (dur * 0.45, 0.0)])
        x = g.addv(x, g.mul(v, venv), voice)
    env = g.env_pts(n, [(0.0, 0.0), (0.1, 1.0), (dur * 0.35, 0.72), (dur, 0.0)])   # eases in, long sigh out
    wob = g.smooth_rand(n, 8, rng)
    return [s * e ** 1.4 * (1.0 + 0.08 * w) for s, e, w in zip(x, env, wob)]


def breath(rng, di, de, fs, voice, f0):
    a = g.nrm(inhale(rng, di, fs), 0.4)        # the inhale sits well under the exhale
    b = g.nrm(exhale(rng, de, fs, voice, f0), 1.0)
    gap = g.ns(rng.uniform(0.07, 0.11))
    lead = g.ns(0.01)
    out = g.zeros(lead + len(a) + gap + len(b) + g.ns(0.06))
    g.mix(out, a, lead)
    g.mix(out, b, lead + len(a) + gap)
    out = g.lp(g.hp(out, 140.0), 7500.0)
    room = g.reverb(out, rt60=0.25, size=0.3, damp=5000.0)   # just the inside of a mask-less head, not a room
    return [s + 0.05 * r for s, r in zip(out, room)]


def main():
    for k, (di, de, fs, voice, f0) in enumerate(TAKES, 1):
        name = "breath_run_%d" % k
        rng = random.Random(4100 + k)
        x = breath(rng, di, de, fs, voice, f0)
        x = g.hp(x, 18.0)
        g.fade_in(x, 0.002)
        g.fade_out(x, 0.03)
        x = g.nrm(x, g.db(-3.0))
        pcm = g.to_pcm16(x, random.Random(k))
        with open(os.path.join(g.OUT_DIR, name + ".wav"), "wb") as f:
            f.write(g.wav_bytes(pcm, False))
        print("%-14s %4.2f s" % (name, len(x) / SR))


if __name__ == "__main__":
    main()

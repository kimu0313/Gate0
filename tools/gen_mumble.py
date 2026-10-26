"""GATE 0 — the colleague's voice through the face mask: talk you cannot make out (StaffNpc.murmur).

Usage (from the project root):  py -I tools/gen_mumble.py
Writes assets/audio/sfx/npc_mumble_1.wav … npc_mumble_3.wav (22.05 kHz 16-bit mono, ~6 s of continuous talk each;
murmur() plays a stretch from a random point, Snd.variant never repeats the last one).

Casual Korean handover talk is spoken by Windows SAPI (Heami), read a little slower and lower, then made
unintelligible: syllable-sized pieces are shuffled within each group of three (the words are gone, the rhythm and
intonation stay) and a mask/close-mouth filter takes away the consonants (low-pass ~750 Hz, a boxy bump around
260 Hz). Dry on purpose: the engine adds the room (the 3D player sits in the NPC's head).
The distant evening-staff chatter is a different sound (npc_murmur_*, ElevenLabs).
No numpy needed (pure Python, a few seconds). Reuses gen_tape's SAPI and filter helpers.
"""
import math
import os
import random
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_tape as gt   # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio", "sfx")
RATE = gt.RATE

LINES = [
    ("npc_mumble_1", gt.KO, -1, "아, 오셨어요? 이쪽으로 오세요. 이거 먼저 받으시고요, 이건 무전기예요. 어렵진 않아요, 금방 익숙해지실 거예요."),
    ("npc_mumble_2", gt.KO, -1, "음, 그러니까요, 밤에는 좀 조용해요. 그냥 수칙대로만 하시면 돼요. 저도 처음엔 다 그랬거든요, 네."),
    ("npc_mumble_3", gt.KO, -1, "네네, 그건 소장님이 알려 주실 거예요. 아무튼 오늘 수고 많으세요. 저는 이만 가 볼게요, 들어가세요."),
]


def peaking(x, f0, gain_db, q=1.0):
    a = 10 ** (gain_db / 40)
    w0 = 2 * math.pi * f0 / RATE
    alpha = math.sin(w0) / (2 * q)
    c = math.cos(w0)
    b0, b1, b2 = 1 + alpha * a, -2 * c, 1 - alpha * a
    a0, a1, a2 = 1 + alpha / a, -2 * c, 1 - alpha / a
    b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0
    y = []
    x1 = x2 = y1 = y2 = 0.0
    for v in x:
        o = b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, v, y1, o
        y.append(o)
    return y


def close_gaps(x, keep=0.12, thr=0.015):
    """Shortens pauses to at most `keep` s so any stretch of the clip is talk."""
    out, quiet = [], 0
    n_keep = int(keep * RATE)
    win = int(0.01 * RATE)
    for i in range(0, len(x), win):
        seg = x[i:i + win]
        if max(abs(v) for v in seg) < thr:
            quiet += len(seg)
            if quiet > n_keep:
                continue
        else:
            quiet = 0
        out += seg
    return out


def scramble(x, rng, xf=0.018):
    """Syllable-sized pieces (0.16–0.28 s) shuffled within each group of three, spliced with equal-power fades."""
    n_xf = int(xf * RATE)
    cuts = [0]
    while cuts[-1] < len(x):
        cuts.append(min(len(x), cuts[-1] + int(rng.uniform(0.16, 0.28) * RATE)))
    pieces = [(cuts[i], cuts[i + 1]) for i in range(len(cuts) - 1)]
    order = []
    for g in range(0, len(pieces), 3):
        grp = pieces[g:g + 3]
        if len(grp) > 1:
            shuffled = grp[:]
            while shuffled == grp:
                rng.shuffle(shuffled)
            grp = shuffled
        order += grp
    out = []
    for a, b in order:
        piece = x[max(0, a - n_xf):b]
        if out and len(piece) > n_xf:
            for k in range(n_xf):
                t = k / n_xf
                out[-n_xf + k] = out[-n_xf + k] * math.cos(t * math.pi / 2) + piece[k] * math.sin(t * math.pi / 2)
            out += piece[n_xf:]
        else:
            out += piece
    return out


def mask(x):
    x = gt.biquad(x, "hp", 110.0)
    x = gt.biquad(gt.biquad(x, "lp", 750.0), "lp", 750.0)
    x = peaking(x, 260.0, 3.0, 0.9)
    peak = max(1e-6, max(abs(v) for v in x))
    return [math.tanh(1.6 * v / peak) / math.tanh(1.6) for v in x]   # a little even, like a voice held back


def fade(x, fin=0.03, fout=0.08):
    ni, no = int(fin * RATE), int(fout * RATE)
    for i in range(min(ni, len(x))):
        x[i] *= i / ni
    for i in range(min(no, len(x))):
        x[-1 - i] *= i / no
    return x


def main():
    rng = random.Random(2310)
    gt.LINES = [(i, v, r, t, "ko") for i, v, r, t in LINES]
    with tempfile.TemporaryDirectory() as tmp:
        gt.synth(tmp)
        for i, _v, _r, _t in LINES:
            x = gt.trim(gt.read(os.path.join(tmp, i + "_raw.wav")))
            x = gt.resample(x, 0.87)                  # lower and a little slower: a tired voice under a mask
            x = close_gaps(x)
            x = mask(scramble(x, rng))
            x = fade(x)
            gt.write(os.path.join(OUT, i + ".wav"), x)
            print("%-14s %5.2f s" % (i, len(x) / RATE))


if __name__ == "__main__":
    main()

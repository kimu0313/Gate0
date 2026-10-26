"""GATE 0 — the A0 tape (1987 control-tower recording) and its fallback name call.

Usage (from the project root):  py -I tools/gen_tape.py
Writes assets/audio/voice/tape_a0_1.wav … tape_a0_6.wav and tape_name_generic.wav (22.05 kHz 16-bit mono).

The lines are spoken by Windows SAPI (Zira for the tower and the pilot, Heami for the Korean fallback), then made to
sound like an old cassette dub of a radio recording: the pilot pitched down, a radio band-pass, saturation,
wow and flutter, hiss and mains hum, squelch clicks at the start and end of each transmission. Line 5 breaks off
mid-word into a burst of noise; line 6 is the noise that is left. ShiftDirector.TAPE has the subtitles.
Godot plays them through the PA bus (the console's built-in deck), which adds the terminal's own speakers.
No numpy needed (pure Python, a few seconds).
"""
import json
import math
import os
import random
import struct
import subprocess
import sys
import tempfile
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio", "voice")
RATE = 22050
EN = "Microsoft Zira Desktop"
KO = "Microsoft Heami Desktop"

# id, voice, SAPI rate, text, role (tower | pilot | ko)
LINES = [
    ("tape_a0_1", EN, -1, "Alpha zero, Seohae tower. Wind calm, runway three four, cleared for take-off.", "tower"),
    ("tape_a0_2", EN, 0, "Cleared for take-off, runway three four, Alpha zero.", "pilot"),
    ("tape_a0_3", EN, 0, "Seohae tower, Alpha zero, airborne, passing one thousand.", "pilot"),
    ("tape_a0_4", EN, -1, "Alpha zero, radar contact. Climb and maintain six thousand.", "tower"),
    ("tape_a0_5", EN, -1, "Climbing six thousand, Alpha zero. Tower, uh, be advised, below us there is a", "pilot"),
    ("tape_name_generic", KO, -2, "거기, 누구 있습니까. 들립니까. 여기는, 에이영편입니다.", "ko"),
]

PS = r"""
Add-Type -AssemblyName System.Speech
$items = Get-Content -Raw -Encoding UTF8 $args[0] | ConvertFrom-Json
$s = New-Object System.Speech.Synthesis.SpeechSynthesizer
$f = New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo(22050, [System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen, [System.Speech.AudioFormat.AudioChannel]::Mono)
foreach ($it in $items) {
    try { $s.SelectVoice($it.voice) } catch { Write-Warning ("voice missing: " + $it.voice) }
    $s.Rate = [int]$it.rate
    try { $s.SetOutputToWaveFile($it.path, $f) } catch { Write-Warning ("cannot write " + $it.path); continue }
    $s.Speak($it.text)
    $s.SetOutputToNull()
}
$s.Dispose()
"""


def synth(tmp):
    items = [{"voice": v, "rate": r, "text": t, "path": os.path.join(tmp, i + "_raw.wav")} for i, v, r, t, _ in LINES]
    jpath = os.path.join(tmp, "lines.json")
    with open(jpath, "w", encoding="utf-8") as f:
        json.dump(items, f, ensure_ascii=False)
    ps1 = os.path.join(tmp, "synth.ps1")
    with open(ps1, "w", encoding="utf-8-sig") as f:   # BOM: Windows PowerShell 5.1 reads it as UTF-8
        f.write(PS)
    subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", ps1, jpath], check=True)


def read(path):
    with wave.open(path, "rb") as w:
        n = w.getnframes()
        data = w.readframes(n)
    return [s / 32768.0 for s in struct.unpack("<%dh" % n, data)]


def write(path, x):
    peak = max(1e-6, max(abs(v) for v in x))
    g = 0.7 / peak   # about -3 dBFS, like the other PA clips
    frames = struct.pack("<%dh" % len(x), *[int(max(-1.0, min(1.0, v * g)) * 32767) for v in x])
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(frames)


def trim(x, thr=0.01):
    a = next((i for i, v in enumerate(x) if abs(v) > thr), 0)
    b = len(x) - next((i for i, v in enumerate(reversed(x)) if abs(v) > thr), 0)
    return x[max(0, a - 400):min(len(x), b + 800)]


def resample(x, factor, wow=0.0, rng=None):
    """Read x at `factor` speed (< 1 = slower and lower), with optional wow and flutter."""
    out = []
    pos = 0.0
    t = 0
    ph = rng.random() * 6.28 if rng else 0.0
    while pos < len(x) - 1:
        i = int(pos)
        fr = pos - i
        out.append(x[i] * (1 - fr) + x[i + 1] * fr)
        sp = factor * (1.0 + wow * math.sin(ph + t * 2 * math.pi * 0.55 / RATE) + wow * 0.4 * math.sin(t * 2 * math.pi * 7.3 / RATE))
        pos += sp
        t += 1
    return out


def biquad(x, kind, f0, q=0.707):
    w0 = 2 * math.pi * f0 / RATE
    alpha = math.sin(w0) / (2 * q)
    c = math.cos(w0)
    if kind == "lp":
        b0, b1, b2 = (1 - c) / 2, 1 - c, (1 - c) / 2
    else:
        b0, b1, b2 = (1 + c) / 2, -(1 + c), (1 + c) / 2
    a0, a1, a2 = 1 + alpha, -2 * c, 1 - alpha
    b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0
    y = []
    x1 = x2 = y1 = y2 = 0.0
    for v in x:
        o = b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, v, y1, o
        y.append(o)
    return y


def radio(x):
    x = biquad(biquad(x, "hp", 420.0), "hp", 420.0)
    x = biquad(biquad(x, "lp", 2600.0), "lp", 2600.0)
    return [math.tanh(v * 3.2) / math.tanh(3.2) for v in x]   # an overdriven transmitter


def noise(n, rng, level):
    return [rng.uniform(-1, 1) * level for _ in range(n)]


def tape_bed(n, rng):
    """Cassette hiss (high-passed noise), mains hum and the odd crackle."""
    hiss = biquad(noise(n, rng, 1.0), "hp", 2500.0)
    out = []
    for i in range(n):
        v = hiss[i] * 0.05 + 0.012 * math.sin(2 * math.pi * 60 * i / RATE) + 0.006 * math.sin(2 * math.pi * 120 * i / RATE)
        if rng.random() < 0.0004:
            v += rng.uniform(-0.25, 0.25)
        out.append(v)
    return out


def squelch(rng, n=int(RATE * 0.09)):
    burst = biquad(noise(n, rng, 0.5), "lp", 4000.0)
    return [v * (1 - i / n) for i, v in enumerate(burst)]


def mix(a, b):
    n = max(len(a), len(b))
    return [(a[i] if i < len(a) else 0.0) + (b[i] if i < len(b) else 0.0) for i in range(n)]


def build(raw, role, rng, cut=False):
    x = trim(raw)
    if role == "pilot":
        x = resample(x, 0.84)   # lower voice, a different person
    if role != "ko":
        x = radio(x)
    x = resample(x, 1.0, wow=0.004, rng=rng)
    if cut:
        # the transmission breaks off mid-word into a roar of static that drops away
        x = x[:int(len(x) * 0.97)]
        n = int(RATE * 1.3)
        roar = biquad(noise(n, rng, 0.9), "lp", 5000.0)
        x += [v * (1.0 - i / n) ** 1.6 for i, v in enumerate(roar)]
    if role != "ko":
        x = squelch(rng) + [0.0] * int(RATE * 0.05) + x + squelch(rng)
    lead = [0.0] * int(RATE * 0.25)
    x = lead + x + [0.0] * int(RATE * 0.35)
    return mix(x, tape_bed(len(x), rng))


def static_tail(rng):
    """Line 6: what is left on the tape after the cut — static that swells and dies, a voice-like warble under it."""
    n = int(RATE * 3.2)
    st = biquad(noise(n, rng, 1.0), "lp", 3200.0)
    out = []
    for i in range(n):
        k = i / n
        env = math.sin(math.pi * min(1.0, k * 1.4)) * (1.0 - k) ** 0.5
        warble = 0.12 * math.sin(2 * math.pi * (180 + 40 * math.sin(i / RATE * 3.1)) * i / RATE) * math.sin(math.pi * k) ** 2
        out.append(st[i] * 0.45 * env + warble * env)
    return mix(out, tape_bed(n, rng))


def main():
    rng = random.Random(1103)
    with tempfile.TemporaryDirectory() as tmp:
        synth(tmp)
        for i, _v, _r, _t, role in LINES:
            raw = read(os.path.join(tmp, i + "_raw.wav"))
            x = build(raw, role, rng, cut=(i == "tape_a0_5"))
            write(os.path.join(OUT, i + ".wav"), x)
            print("%-20s %6.2f s" % (i, len(x) / RATE))
    write(os.path.join(OUT, "tape_a0_6.wav"), static_tail(rng))
    print("%-20s %6.2f s" % ("tape_a0_6", 3.2))


if __name__ == "__main__":
    sys.exit(main())

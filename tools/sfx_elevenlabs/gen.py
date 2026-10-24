"""Generate GATE 0 sound effects with the ElevenLabs text-to-sound API and fit them into assets/audio/sfx.

    python -I tools/sfx_elevenlabs/gen.py generate [--only a,b] [--raw <dir>]   # API -> raw takes (mp3)
    python -I tools/sfx_elevenlabs/gen.py pick [--only a,b] [--raw <dir>]       # score the takes -> <raw>/picks.json
    python -I tools/sfx_elevenlabs/gen.py build [--only a,b] [--raw <dir>]      # picked take -> assets wav

Spec: sounds.json. Per sound: prompt (or `prompts`, one per take = options to choose from), takes, dur, loop, inf,
ch (1 mono for 3D emitters / 2 stereo), trim/trim_db, slice/step (footsteps), af (ffmpeg filter: EQ), level (new
sounds), keep: "procedural" (leave the original file in place).

The API key comes from ELEVENLABS_API_KEY (process or Windows user environment); it is never printed or written.
Raw takes: <raw>/<name>_t<k>.mp3 (default ../GATE0_SFX_ElevenLabs/r2). `pick` scores every take (clean noise floor,
a single event for short UI/foley sounds, steady machines, beds without sudden spikes, consistent footsteps) and
records the best; edit picks.json by hand to override. `build`:
  - decodes the picked take through `af`, trims leading silence, slices footsteps (pooled from every take of the
    same prompt), seamless loop seam, short fades,
  - matches the level of the procedural file it replaces (backup in <raw>/../_procedural) so code volumes stay valid,
  - writes 44.1 kHz 16-bit wav.
"""
import argparse, json, os, shutil, subprocess, sys, urllib.request, urllib.error, wave
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
SFX = os.path.join(ROOT, "assets", "audio", "sfx")
WORK = os.path.join(os.path.dirname(ROOT), "GATE0_SFX_ElevenLabs")
DEFAULT_RAW = os.path.join(WORK, "r2")
BACKUP = os.path.join(WORK, "_procedural")
SR = 44100
API = "https://api.elevenlabs.io/v1/sound-generation?output_format=mp3_44100_192"


def api_key() -> str:
    k = os.environ.get("ELEVENLABS_API_KEY", "")
    if not k and sys.platform == "win32":
        import winreg
        try:
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as h:
                k = winreg.QueryValueEx(h, "ELEVENLABS_API_KEY")[0]
        except OSError:
            pass
    if not k:
        sys.exit("ELEVENLABS_API_KEY is not set (process or user environment)")
    return k


def spec() -> dict:
    return json.load(open(os.path.join(HERE, "sounds.json"), encoding="utf-8"))


def select(sounds, only):
    sounds = [s for s in sounds if not s.get("keep")]
    if not only:
        return sounds
    want = set(only.split(","))
    return [s for s in sounds if s["name"] in want or s.get("group") in want]


def takes_of(s: dict) -> int:
    return len(s["prompts"]) if s.get("prompts") else int(s.get("takes", 1))


def prompt_of(s: dict, t: int) -> str:
    return s["prompts"][t - 1] if s.get("prompts") else s["prompt"]


# ------------------------------------------------------------------ generate
def generate(s: dict, raw: str, key: str) -> None:
    for t in range(1, takes_of(s) + 1):
        out = os.path.join(raw, f"{s['name']}_t{t}.mp3")
        if os.path.exists(out):
            continue
        body = {"text": prompt_of(s, t), "duration_seconds": s["dur"], "prompt_influence": s.get("inf", 0.3),
                "model_id": "eleven_text_to_sound_v2"}
        if s.get("loop"):
            body["loop"] = True
        req = urllib.request.Request(API, data=json.dumps(body).encode("utf-8"), method="POST",
                                     headers={"xi-api-key": key, "Content-Type": "application/json", "Accept": "audio/mpeg"})
        try:
            with urllib.request.urlopen(req, timeout=180) as r:
                data = r.read()
        except urllib.error.HTTPError as e:
            msg = e.read().decode("utf-8", "replace")[:300]
            print(f"  FAIL {s['name']} t{t}: HTTP {e.code} {msg}")
            if e.code in (401, 402, 403):
                sys.exit("stopping: auth / quota error")
            continue
        open(out, "wb").write(data)
        print(f"  ok   {os.path.basename(out)} {len(data) // 1024} KB")


# ------------------------------------------------------------------ audio helpers
def decode(path: str, ch: int, af: str = "") -> np.ndarray:
    cmd = ["ffmpeg", "-v", "error", "-i", path]
    if af:
        cmd += ["-af", af]
    cmd += ["-f", "f32le", "-ac", str(ch), "-ar", str(SR), "-"]
    pcm = subprocess.run(cmd, capture_output=True, check=True).stdout
    return np.frombuffer(pcm, dtype=np.float32).reshape(-1, ch).copy()


def read_wav(path: str) -> np.ndarray:
    w = wave.open(path)
    n, ch, sw = w.getnframes(), w.getnchannels(), w.getsampwidth()
    a = np.frombuffer(w.readframes(n), dtype={2: np.int16, 4: np.int32}[sw]).astype(np.float32)
    a /= float(2 ** (8 * sw - 1))
    return a.reshape(-1, ch)


def write_wav(path: str, a: np.ndarray) -> None:
    pcm = (np.clip(a, -1.0, 1.0) * 32767.0).astype("<i2")
    w = wave.open(path, "wb")
    w.setnchannels(a.shape[1])
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(pcm.tobytes())
    w.close()


def env(a: np.ndarray, win: float = 0.01) -> np.ndarray:
    m = np.abs(a).max(axis=1)
    n = max(1, int(SR * win))
    return np.convolve(m, np.ones(n) / n, mode="same")


def db(x) -> float:
    return 20 * np.log10(np.maximum(x, 1e-9))


def active_rms_db(a: np.ndarray) -> float:
    """RMS (dBFS) of the part louder than 30 dB under the peak, so silence and tails do not drag it down."""
    m = np.abs(a).max(axis=1)
    if m.max() <= 0:
        return -120.0
    act = a[m > m.max() * 10 ** (-30 / 20)]
    return float(db(np.sqrt(np.mean(act ** 2))))


def trim_lead(a: np.ndarray, thresh_db: float = -45.0) -> np.ndarray:
    e = env(a, 0.003)
    idx = int(np.argmax(e > max(1e-9, e.max()) * 10 ** (thresh_db / 20)))    # first sample within thresh of the peak
    return a[max(0, idx - int(0.005 * SR)):]


def trim_tail(a: np.ndarray, rel_db: float = -55.0) -> np.ndarray:
    """Cut once the sound has decayed `rel_db` under its peak (keeps tails, drops the noise after them)."""
    e = env(a, 0.01)
    above = np.where(e > e.max() * 10 ** (rel_db / 20))[0]
    return a[: above[-1] + int(0.04 * SR)] if len(above) else a


def fades(a: np.ndarray, fin: float = 0.003, fout: float = 0.03) -> np.ndarray:
    a = a.copy()
    ni, no = min(len(a), int(fin * SR)), min(len(a), int(fout * SR))
    if ni:
        a[:ni] *= np.linspace(0, 1, ni)[:, None]
    if no:
        a[-no:] *= np.linspace(1, 0, no)[:, None] ** 2
    return a


def onsets(a: np.ndarray) -> list:
    e = env(a, 0.004)
    thr = e.max() * 0.18
    out, i, gap = [], 0, int(0.22 * SR)
    while i < len(e):
        if e[i] > thr:
            out.append(max(0, i - int(0.008 * SR)))
            i += gap
        else:
            i += 1
    return out


def step_cuts(a: np.ndarray, step: float) -> list:
    """Single footsteps: from each onset to where it decays 40 dB (at most `step` s), each faded out."""
    cuts = []
    for o in onsets(a):
        seg = a[o: o + int(step * SR)]
        if len(seg) < int(0.12 * SR):
            continue
        e = env(seg, 0.005)
        pk = int(np.argmax(e))
        below = np.where(e[pk:] < e[pk] * 10 ** (-40 / 20))[0]
        end = pk + (below[0] if len(below) else len(e) - pk)
        seg = seg[: max(int(0.12 * SR), min(len(seg), end + int(0.03 * SR)))]
        cuts.append(fades(seg, 0.002, min(0.08, len(seg) / SR * 0.4)))
    return cuts


def level_to(a: np.ndarray, target_db: float) -> np.ndarray:
    a = a * 10 ** ((target_db - active_rms_db(a)) / 20)
    peak = np.abs(a).max()
    if peak > 10 ** (-1 / 20):
        a = a * (10 ** (-1 / 20) / peak)
    return a


def loop_seam(a: np.ndarray, xf: float = 0.08) -> np.ndarray:
    """Equal-power crossfade of the last `xf` s into the start so the loop point never clicks."""
    n = int(xf * SR)
    if len(a) <= 3 * n:
        return a
    head, body, tail = a[:n], a[n:-n], a[-n:]
    t = np.linspace(0, 1, n)[:, None]
    return np.concatenate([tail * np.cos(t * np.pi / 2) + head * np.sin(t * np.pi / 2), body])


# ------------------------------------------------------------------ scoring
def score(s: dict, a: np.ndarray) -> float:
    """Higher is better. A proxy for a clean, usable take; it does not judge taste."""
    m = np.abs(a).max(axis=1)
    if m.max() < 1e-4:
        return -999.0
    clip = float(np.mean(m > 0.985)) * 400
    if s.get("slice"):
        cuts = step_cuts(a, float(s["step"]))
        if len(cuts) < 4:
            return -200.0 + len(cuts)
        pk = np.array([db(np.abs(c).max()) for c in cuts])
        ln = np.array([len(c) / SR for c in cuts])
        return min(len(cuts), 8) * 2 - float(np.std(pk)) * 3 - float(np.std(ln)) * 20 - clip
    e = env(a, 0.05)
    edb = db(e / e.max())
    if s.get("loop"):
        rms = db(np.sqrt(np.convolve(np.mean(a ** 2, axis=1), np.ones(int(0.1 * SR)) / int(0.1 * SR), mode="valid")) + 1e-9)
        spread = float(np.percentile(rms, 95) - np.percentile(rms, 20))
        spike = float(rms.max() - np.median(rms))
        steady = s.get("group") == "machines"
        return -(spread * (1.5 if steady else 0.5)) - max(0.0, spike - 9.0) * 2 - clip
    # one-shots: low noise floor after the event, and (short sounds) a single event
    tail = edb[int(len(edb) * 0.85):]
    floor = float(np.median(tail)) if len(tail) else 0.0
    sc = -floor * 0.4 - clip
    if s["dur"] <= 1.0 and s.get("group") in ("ui", "foley"):
        n_on = len(onsets(a))
        sc -= max(0, n_on - (2 if s["name"] in ("ui_notify", "ui_alert", "beep_error") else 1)) * 6
    return sc


def pick_all(sounds: list, raw: str) -> dict:
    pf = os.path.join(raw, "picks.json")
    picks = json.load(open(pf, encoding="utf-8")) if os.path.exists(pf) else {}
    for s in sounds:
        scores = {}
        for t in range(1, takes_of(s) + 1):
            p = os.path.join(raw, f"{s['name']}_t{t}.mp3")
            if os.path.exists(p):
                scores[t] = round(score(s, decode(p, int(s.get("ch", 1)), s.get("af", ""))), 2)
        if not scores:
            continue
        best = max(scores, key=scores.get)
        if not str(picks.get(s["name"], "")).endswith("!"):      # "2!" = chosen by hand, keep it
            picks[s["name"]] = best
        print(f"  {s['name']:20s} {scores} -> {picks[s['name']]}")
    json.dump(picks, open(pf, "w", encoding="utf-8"), indent=1)
    return picks


# ------------------------------------------------------------------ build
def build(s: dict, raw: str, take: int) -> None:
    ch = int(s.get("ch", 1))
    af = s.get("af", "")
    os.makedirs(BACKUP, exist_ok=True)
    if s.get("slice"):
        # pool the steps of every take sharing the chosen take's prompt (options: just that take)
        ts = [take] if s.get("prompts") else list(range(1, takes_of(s) + 1))
        cuts = []
        for t in ts:
            p = os.path.join(raw, f"{s['name']}_t{t}.mp3")
            if os.path.exists(p):
                cuts += step_cuts(decode(p, ch, af), float(s["step"]))
        if not cuts:
            print("  no steps for", s["name"])
            return
        pk = np.array([db(np.abs(c).max()) for c in cuts])
        keep = sorted(np.argsort(np.abs(pk - np.median(pk)))[: int(s["slice"])])
        old = [os.path.join(BACKUP, f"{s['name']}_{k}.wav") for k in range(1, 5)]
        refs = [active_rms_db(read_wav(p)) for p in old if os.path.exists(p)]
        ref = float(np.mean(refs)) if refs else -18.0
        for k in range(1, 13):
            stale = os.path.join(SFX, f"{s['name']}_{k}.wav")
            if os.path.exists(stale):
                os.remove(stale)
        for k, i in enumerate(keep, 1):
            write_wav(os.path.join(SFX, f"{s['name']}_{k}.wav"), level_to(cuts[i], ref))
        print(f"  built {s['name']}_1..{len(keep)} from {len(cuts)} steps (ref {ref:.1f} dB)")
        return
    src = os.path.join(raw, f"{s['name']}_t{take}.mp3")
    if not os.path.exists(src):
        print("  missing take", os.path.basename(src))
        return
    a = decode(src, ch, af)
    dst = os.path.join(SFX, s["name"] + ".wav")
    bak = os.path.join(BACKUP, s["name"] + ".wav")
    if os.path.exists(dst) and not os.path.exists(bak) and not s.get("level"):
        shutil.copy(dst, bak)
    ref = active_rms_db(read_wav(bak)) if os.path.exists(bak) else float(s.get("level", -20.0))
    if s.get("loop"):
        a = loop_seam(a)
    else:
        if s.get("trim"):
            a = trim_lead(a, float(s.get("trim_db", -45.0)))
        a = fades(trim_tail(a), 0.003, 0.05)
    write_wav(dst, level_to(a, ref))
    print(f"  built {s['name']} t{take} {len(a) / SR:.2f}s ch{ch} (ref {ref:.1f} dB)")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["generate", "pick", "build"])
    ap.add_argument("--only", default="")
    ap.add_argument("--raw", default=DEFAULT_RAW)
    args = ap.parse_args()
    os.makedirs(args.raw, exist_ok=True)
    sounds = select(spec()["sounds"], args.only)
    if args.cmd == "generate":
        key = api_key()
        for s in sounds:
            generate(s, args.raw, key)
    elif args.cmd == "pick":
        pick_all(sounds, args.raw)
    else:
        pf = os.path.join(args.raw, "picks.json")
        picks = json.load(open(pf, encoding="utf-8")) if os.path.exists(pf) else {}
        for s in sounds:
            build(s, args.raw, int(str(picks.get(s["name"], 1)).rstrip("!")))


if __name__ == "__main__":
    main()

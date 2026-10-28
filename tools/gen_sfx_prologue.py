"""GATE 0 — prologue sound effects (Gate 0 v2, SCENE 01–04 and the gate door).

Usage (from the project root):  py -I tools/gen_sfx_prologue.py [name filter ...]
Writes assets/audio/sfx/<name>.wav (44.1 kHz 16-bit mono), pure Python on gen_sfx's filters and registry:

  cart_rattle_1..3   a baggage trolley rolling over tile joints somewhere (달그락…… 덜컹……), one pass each
  cart_rattle_loop   the same at a steady run (it follows you in SCENE 03), 4 s seamless loop
  paper_tear_1..4    a baggage tag torn in two (찌익)
  bone_crack_1..3    a joint giving the wrong way (뚝)
  door_slam          a door slamming (쿵!)
  monster_scream     the creature screaming as it catches you
  body_fall          going down hard on the carpet as you stumble through the door
  wall_rub           a palm feeling along a painted wall
  key_pickup         a small key picked up off the carpet
  padlock_open       key in, turn, the shackle pops
  chain_drop         a chain sliding off two pull bars onto the floor

Dry, close sources: the engine adds the room (reverb zones), distance and occlusion.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_sfx as g   # noqa: E402

SR = g.SR
ns = g.ns
MINE = []


def reg(name, dur, **kw):
    def deco(fn):
        g.reg(name, dur, **kw)(fn)
        MINE.append(name)
        return fn
    return deco


# ------------------------------------------------------------------ baggage cart

def _rattle_hit(rng, amp):
    """one tick of the wire basket against its frame"""
    sc = rng.uniform(0.8, 1.25)
    n = ns(0.03)
    ev = g.modes(n, [1750 * sc, 2630 * sc, 3480 * sc, 4410 * sc], [0.5, 0.35, 0.25, 0.15],
                 [0.012, 0.009, 0.007, 0.005], rng)
    g.mix(ev, g.hp(g.burst(ns(0.004), rng, 0.0005), 2000.0), 0, 0.5)
    return g.scale(ev, amp)


def _joint_bump(rng, amp):
    """덜컹: the castors drop over a tile joint, the whole trolley rings"""
    n = ns(0.35)
    out = g.zeros(n)
    g.mix(out, g.thump(ns(0.14), 150.0, 72.0, 0.01, 0.03, 0.001), 0, 0.9)
    g.mix(out, g.modes(ns(0.3), [410.0, 980.0, 1630.0, 2390.0], [0.35, 0.28, 0.2, 0.12], [0.09, 0.06, 0.04, 0.03], rng), 0, 0.6)
    for k in range(rng.randint(3, 6)):
        g.mix(out, _rattle_hit(rng, rng.uniform(0.4, 1.0)), ns(rng.uniform(0.0, 0.05)), 1.0)
    return g.scale(out, amp)


def _cart(rng, n, speed_at, bump_every=0.58):
    """a trolley run: speed_at(t) in 0..1 drives the rumble, the basket rattle and the joint bumps"""
    v = [speed_at(i / SR) for i in range(n)]
    rum = g.lp(g.lp(g.brown(n, rng), 230.0), 300.0)
    rum = g.nrm(rum)
    flutter = [0.65 + 0.35 * g._sin(g.TAU * 7.0 * i / SR) for i in range(n)]
    rum = [r * f * (s ** 1.2) for r, f, s in zip(rum, flutter, v)]
    rat = g.zeros(n)
    t = 0.0
    while t < n / SR:
        s = v[min(n - 1, int(t * SR))]
        rate = 6.0 + 30.0 * s
        t += rng.expovariate(rate)
        if s > 0.05 and t < n / SR:
            g.mix(rat, _rattle_hit(rng, rng.uniform(0.1, 0.55) * s), ns(t))
    bumps = g.zeros(n)
    t = rng.uniform(0.15, 0.35)
    while t < n / SR:
        s = v[min(n - 1, int(t * SR))]
        if s > 0.15:
            g.mix(bumps, _joint_bump(rng, rng.uniform(0.75, 1.0) * s), ns(t))
        t += bump_every / max(0.35, s) * rng.uniform(0.93, 1.07)
    return g.addv(g.addv(g.scale(rum, 0.5), rat, 1.0), bumps, 1.2)


def _env3(rise, hold, fall):
    def f(t):
        if t < rise:
            return g.smoothstep(t / rise)
        if t < rise + hold:
            return 1.0
        return 1.0 - g.smoothstep((t - rise - hold) / fall)
    return f


@reg("cart_rattle_1", 3.6, fade_out=0.2)
def s_cart_1(rng):
    return _cart(rng, ns(3.6), _env3(0.5, 2.0, 1.0))


@reg("cart_rattle_2", 3.2, fade_out=0.2)
def s_cart_2(rng):
    out = _cart(rng, ns(3.2), _env3(0.3, 1.9, 0.8), 0.5)
    # it stops with a knock against something
    g.mix(out, _joint_bump(rng, 1.3), ns(2.85))
    return out


@reg("cart_rattle_3", 3.0, fade_out=0.25)
def s_cart_3(rng):
    return _cart(rng, ns(3.0), _env3(0.8, 1.2, 0.9), 0.66)


@reg("cart_rattle_loop", 4.0, loop=True, rms_db=-18.0)
def s_cart_loop(rng):
    N, C = ns(4.0), ns(0.5)
    L = N + C
    rum = g.nrm(g.lp(g.lp(g.brown(L, rng), 230.0), 300.0))
    rum = g.xfade_loop(rum, N, C)
    flutter = [0.65 + 0.35 * g._sin(g.TAU * 7.0 * i / SR) for i in range(N)]    # 28 cycles per loop
    out = [r * f * 0.5 for r, f in zip(rum, flutter)]
    t = 0.0
    while t < 4.0:
        t += rng.expovariate(32.0)
        g.mix_circ(out, _rattle_hit(rng, rng.uniform(0.15, 0.6)), ns(t))
    for k in range(8):                                                        # a joint every 0.5 s
        g.mix_circ(out, _joint_bump(rng, rng.uniform(0.8, 1.05)), ns(0.07 + 0.5 * k + rng.uniform(-0.02, 0.02)), 1.2)
    return out


# ------------------------------------------------------------------ the figure

def _tear(rng, dur):
    n = ns(dur + 0.2)
    out = g.zeros(n)
    # fibres snapping, thick in the middle of the rip
    t = 0.02
    while t < dur:
        u = t / dur
        dens = 60.0 + 900.0 * (g.smoothstep(u / 0.3) * (1.0 - g.smoothstep((u - 0.75) / 0.25)))
        t += rng.expovariate(dens)
        c = g.click(rng, ns(0.004), rng.uniform(0.0002, 0.0006), rng.uniform(1200.0, 2500.0))
        g.mix(out, c, ns(t), rng.uniform(0.2, 1.0))
    # the rip itself: a hiss whose pitch climbs as it goes
    hiss = g.white(n, rng)
    ctl = [1400.0 + 2600.0 * min(1.0, i / (dur * SR)) for i in range(n)]
    hiss = g.svf(hiss, ctl, 1.4, "bp")
    env = g.env_pts(n, [(0, 0.0), (0.06, 0.8), (dur * 0.7, 1.0), (dur, 0.0), (dur + 0.2, 0.0)])
    hiss = g.mul(hiss, env)
    out = g.addv(g.nrm(out), g.nrm(hiss), 0.55)
    # the paper flapping as the hands pull apart
    flap = g.mul(g.lp(g.white(ns(0.08), rng), 500.0), g.env_exp(ns(0.08), 0.02))
    g.mix(out, g.nrm(flap), ns(dur * 0.92), 0.3)
    return out


@reg("paper_tear_1", 0.7, fade_out=0.05)
def s_tear_1(rng):
    return _tear(rng, 0.42)


@reg("paper_tear_2", 0.8, fade_out=0.05)
def s_tear_2(rng):
    return _tear(rng, 0.55)


@reg("paper_tear_3", 0.6, fade_out=0.05)
def s_tear_3(rng):
    return _tear(rng, 0.32)


@reg("paper_tear_4", 0.9, fade_out=0.05)
def s_tear_4(rng):
    out = _tear(rng, 0.3)
    g.mix(out, _tear(rng, 0.25), ns(0.38), 0.8)     # a second, shorter rip
    return out


def _crack(rng, big):
    n = ns(0.9)
    out = g.zeros(n)
    # the snap
    g.mix(out, g.click(rng, ns(0.006), 0.0006, 700.0), 0, 1.0)
    g.mix(out, g.burst(ns(0.04), rng, 0.005, 600.0, 7000.0), 0, 0.9)
    # splinters right after it
    t = 0.004
    for k in range(rng.randint(4, 8)):
        t += rng.uniform(0.004, 0.02)
        g.mix(out, g.click(rng, ns(0.004), 0.0004, rng.uniform(900.0, 2200.0)), ns(t), rng.uniform(0.25, 0.7))
    # the bone's body and the meat around it
    g.mix(out, g.modes(ns(0.25), [170.0 * big, 330.0 * big, 610.0 * big, 1150.0], [0.6, 0.4, 0.25, 0.12],
                       [0.05, 0.035, 0.02, 0.012], rng), 0, 0.9)
    g.mix(out, g.thump(ns(0.18), 120.0, 58.0, 0.01, 0.045, 0.001), 0, 0.8)
    gristle = g.band(g.white(ns(0.2), rng), 300.0, 1500.0)
    crackle = [1.0 if rng.random() < 0.06 else 0.15 for _ in range(ns(0.2))]
    gristle = g.mul(g.mul(gristle, crackle), g.env_exp(ns(0.2), 0.06))
    g.mix(out, g.nrm(gristle), ns(0.01), 0.35)
    return g.verb(out, 0.08, 1.0, rt60=0.35, size=0.5, damp=5000.0)


@reg("bone_crack_1", 0.9, fade_out=0.1)
def s_crack_1(rng):
    return _crack(rng, 1.0)


@reg("bone_crack_2", 0.9, fade_out=0.1)
def s_crack_2(rng):
    return _crack(rng, 0.85)


@reg("bone_crack_3", 0.9, fade_out=0.1)
def s_crack_3(rng):
    return _crack(rng, 1.2)


# ------------------------------------------------------------------ doors, walls, the key

@reg("door_slam", 1.8, fade_out=0.3)
def s_door_slam(rng):
    n = ns(1.8)
    out = g.zeros(n)
    g.mix(out, g.thump(ns(0.6), 78.0, 44.0, 0.04, 0.13, 0.002), 0, 1.0)
    g.mix(out, g.nrm(g.lp(g.burst(ns(0.3), rng, 0.05), 450.0)), 0, 0.9)
    g.mix(out, g.nrm(g.band(g.burst(ns(0.08), rng, 0.012), 900.0, 4000.0)), 0, 0.35)
    latch = g.modes(ns(0.12), [2650.0, 3900.0, 5200.0], [0.5, 0.3, 0.2], [0.03, 0.02, 0.012], rng)
    g.mix(out, latch, ns(0.012), 0.45)
    # the leaf and its frame rattle for a moment
    for k in range(7):
        t = 0.03 + k * rng.uniform(0.025, 0.05)
        g.mix(out, g.modes(ns(0.15), [330.0 * rng.uniform(0.9, 1.1), 780.0, 1240.0], [0.3, 0.2, 0.1],
                           [0.05, 0.03, 0.02], rng), ns(t), 0.5 * (1.0 - k / 8.0))
    return g.verb(out, 0.3, 1.0, rt60=1.1, size=0.9, damp=3000.0)


@reg("monster_scream", 2.0, fade_out=0.35)
def s_monster_scream(rng):
    """caught: the thing screams — a piercing, inhuman shriek over a torn roar and a rattle of vocal fry, all at once"""
    n = ns(2.0)
    env = g.env_pts(n, [(0, 0.0), (0.012, 1.0), (0.25, 0.95), (1.2, 0.8), (1.6, 0.45), (2.0, 0.0)])
    jit = g.smooth_rand(n, 140, rng)
    # the shriek: a voice forced far too high, wavering wildly
    hi = g.env_pts(n, [(0, 640.0), (0.06, 1150.0), (0.5, 980.0), (0.9, 1250.0), (1.4, 860.0), (2.0, 700.0)])
    f_hi = [h * (1.0 + 0.08 * g._sin(g.TAU * 23.0 * i / SR) + 0.05 * j) for i, (h, j) in enumerate(zip(hi, jit))]
    shriek_src = g.addv(g.saw_var(f_hi), g.white(n, rng), 0.25)
    shriek = g.zeros(n)
    for fc, q, gain in ((1150.0, 5.0, 1.0), (2700.0, 7.0, 0.8), (3900.0, 8.0, 0.5)):
        shriek = g.addv(shriek, g.svf(shriek_src, fc, q, "bp"), gain)
    shriek = g.sat(g.nrm(shriek), 4.0)
    # the roar underneath: a huge throat, an octave split under it
    lo = g.env_pts(n, [(0, 95.0), (0.1, 140.0), (1.0, 120.0), (2.0, 80.0)])
    f_lo = [l * (1.0 + 0.04 * j) for l, j in zip(lo, jit)]
    roar_src = g.addv(g.addv(g.saw_var(f_lo), g.saw_var([f * 0.5 for f in f_lo]), 0.7), g.brown(n, rng), 0.6)
    roar = g.addv(g.svf(roar_src, 520.0, 3.0, "bp"), g.svf(roar_src, 1350.0, 4.0, "bp"), 0.6)
    roar = g.sat(g.nrm(roar), 5.0)
    # vocal fry: the scream tearing in the throat
    fry = g.zeros(n)
    t = 0.0
    while t < 1.9:
        t += rng.uniform(1.0 / 70.0, 1.0 / 38.0)
        g.mix(fry, g.burst(ns(0.008), rng, 0.0015, 300.0, 3500.0), ns(t), rng.uniform(0.4, 1.0))
    out = g.addv(g.addv(g.scale(shriek, 0.75), roar, 0.7), g.nrm(fry), 0.35)
    out = g.mul(g.sat(g.nrm(out), 1.8), env)
    return g.verb(out, 0.18, 1.0, rt60=0.9, size=0.8, damp=4500.0)


@reg("body_fall", 1.3, fade_out=0.25)
def s_body_fall(rng):
    """you go down on the carpet: knee, then the body, the radio and the flashlight knocking on the floor"""
    n = ns(1.3)
    out = g.zeros(n)
    g.mix(out, g.thump(ns(0.25), 120.0, 70.0, 0.015, 0.05, 0.002), 0, 0.55)                 # knee
    g.mix(out, g.nrm(g.lp(g.burst(ns(0.12), rng, 0.02), 900.0)), 0, 0.35)
    t = ns(0.11)
    g.mix(out, g.thump(ns(0.5), 85.0, 42.0, 0.03, 0.1, 0.003), t, 1.0)                      # the body
    g.mix(out, g.nrm(g.lp(g.burst(ns(0.3), rng, 0.05), 600.0)), t, 0.8)
    cloth = g.mul(g.band(g.white(ns(0.45), rng), 500.0, 3200.0), g.env_pts(ns(0.45), [(0, 0.0), (0.03, 1.0), (0.45, 0.0)]))
    g.mix(out, g.nrm(cloth), t - ns(0.02), 0.3)
    for k, dt in enumerate((0.14, 0.2, 0.33)):                                                 # gear on the floor
        sc = rng.uniform(0.9, 1.15)
        ev = g.modes(ns(0.12), [1180.0 * sc, 2350.0 * sc, 3420.0 * sc], [0.4, 0.3, 0.15], [0.03, 0.02, 0.012], rng)
        g.mix(ev, g.click(rng, ns(0.004), 0.0005, 1400.0), 0, 0.5)
        g.mix(out, ev, ns(dt), (0.45, 0.3, 0.2)[k])
    return g.lp(out, 5000.0)


@reg("wall_rub", 1.0, peak_db=-4.0, fade_out=0.1)
def s_wall_rub(rng):
    n = ns(1.0)
    hiss = g.band(g.white(n, rng), 700.0, 4200.0)
    low = g.lp(g.white(n, rng), 280.0)
    env = g.env_pts(n, [(0, 0.0), (0.08, 0.7), (0.32, 0.9), (0.42, 0.15), (0.5, 0.6), (0.78, 0.8), (0.95, 0.0), (1.0, 0.0)])
    grain = [1.0 + 0.6 * (rng.random() - 0.5) for _ in range(n)]
    out = g.addv(g.mul(g.mul(g.nrm(hiss), env), grain), g.mul(g.nrm(low), env), 0.4)
    # fingertips catching on the panel joint
    g.mix(out, g.click(rng, ns(0.005), 0.0008, 800.0), ns(0.44), 0.4)
    return out


@reg("key_pickup", 0.9, peak_db=-3.0, fade_out=0.2)
def s_key_pickup(rng):
    n = ns(0.9)
    out = g.zeros(n)
    for k, t in enumerate((0.0, 0.07, 0.19)):
        sc = rng.uniform(0.96, 1.04)
        ev = g.modes(ns(0.6), [3150.0 * sc, 4720.0 * sc, 6930.0 * sc, 8810.0 * sc], [0.5, 0.35, 0.22, 0.12],
                     [0.16, 0.1, 0.06, 0.035], rng)
        g.mix(ev, g.click(rng, ns(0.004), 0.0004, 2500.0), 0, 0.6)
        g.mix(out, ev, ns(t), (1.0, 0.55, 0.35)[k])
    # a hand closing on it
    g.mix(out, g.nrm(g.mul(g.band(g.white(ns(0.12), rng), 600.0, 3000.0), g.env_exp(ns(0.12), 0.04))), ns(0.22), 0.2)
    return out


@reg("padlock_open", 1.1, fade_out=0.2)
def s_padlock(rng):
    n = ns(1.1)
    out = g.zeros(n)
    # key in: a short scrape of teeth over pins
    scrape = g.band(g.white(ns(0.18), rng), 2000.0, 6500.0)
    teeth = [1.0 if (i // ns(0.012)) % 2 == 0 else 0.35 for i in range(ns(0.18))]
    g.mix(out, g.nrm(g.mul(g.mul(scrape, teeth), g.env_pts(ns(0.18), [(0, 0.2), (0.05, 1.0), (0.18, 0.4)]))), 0, 0.45)
    # turn: the cylinder clicks round
    g.mix(out, g.modes(ns(0.1), [2850.0, 4500.0, 6100.0], [0.5, 0.3, 0.15], [0.02, 0.014, 0.009], rng), ns(0.32), 0.7)
    g.mix(out, g.click(rng, ns(0.004), 0.0005, 1800.0), ns(0.32), 0.6)
    # the shackle pops free
    g.mix(out, g.thump(ns(0.12), 330.0, 210.0, 0.01, 0.025, 0.001), ns(0.48), 0.8)
    g.mix(out, g.modes(ns(0.5), [1240.0, 2610.0, 3970.0, 5480.0], [0.5, 0.4, 0.25, 0.12], [0.12, 0.08, 0.05, 0.03], rng), ns(0.48), 0.8)
    return out


@reg("chain_drop", 1.6, fade_out=0.25)
def s_chain_drop(rng):
    n = ns(1.6)
    out = g.zeros(n)
    t = 0.0
    gap = 0.07
    for k in range(18):
        sc = rng.uniform(0.85, 1.2)
        ev = g.modes(ns(0.12), [1480.0 * sc, 2730.0 * sc, 4150.0 * sc, 5520.0 * sc], [0.45, 0.35, 0.22, 0.12],
                     [0.045, 0.03, 0.02, 0.012], rng)
        g.mix(ev, g.click(rng, ns(0.004), 0.0004, 1600.0), 0, 0.5)
        g.mix(out, ev, ns(t), rng.uniform(0.4, 1.0))
        t += gap * rng.uniform(0.6, 1.3)
        gap *= 0.88
    # it lands in a heap on the floor
    land = t + 0.02
    g.mix(out, g.thump(ns(0.25), 150.0, 80.0, 0.015, 0.05, 0.001), ns(land), 0.9)
    for k in range(10):
        sc = rng.uniform(0.8, 1.25)
        g.mix(out, g.modes(ns(0.15), [1650.0 * sc, 3100.0 * sc, 4700.0 * sc], [0.4, 0.3, 0.15], [0.05, 0.03, 0.02], rng),
              ns(land + rng.uniform(0.0, 0.35)), rng.uniform(0.2, 0.7))
    return out


def main(argv):
    names = [nm for nm in MINE if not argv or any(f in nm for f in argv)]
    for nm in names:
        name, dt = g._render_by_name(nm)
        print("  %-20s %6.2f s" % (name, dt), flush=True)
    specs = [s for s in g.REG if s["name"] in names]
    return 0 if g.verify(specs) else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

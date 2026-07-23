#!/usr/bin/env python3
"""Generate the game's sound effects — synthesised, reproducible, dependency-free.

Regenerate with:  python3 tools/gen_sfx.py

Synthesised rather than sourced, so they stay reproducible and licence-free (same
discipline as the sprites, tileset and music). This is the M9-era overhaul of the
original six placeholder blips: combat is now LAYERED the way Dead Cells layers
it — a weapon-class *impact* transient plus a *material* response are two separate
one-shots the Sfx layer plays together, so 3 impacts x 6 materials cost 3+6 files
instead of 18, and a Pick on Armour genuinely differs from a Blade on Flesh.

Layout the Sfx autoload relies on:
  impact_{pick,blade,blunt}   weapon-class transient (the "what swung")
  mat_{flesh,armor,bone,stone,wood,ecto}   surface response (the "what got hit")
  riposte / poise_break / parry   the combat pillars, loud and distinct
  whoosh_light / whoosh_heavy   swing air, per weapon weight
  enemy_death / player_death    the payoff and the punish
  jump / doublejump / land / land_soft / roll / hurt   movement + damage
  pickup_ore / pickup_heart / pickup_buff / pickup_weapon / buy_upgrade / shrine_accept
  ui_move / ui_select / ui_back / ui_pause / ui_slider   menu feedback
  axe_whoosh / axe_hit          the pendulum hazard
  shrine_hum / amb_mine         SEAMLESS LOOPS (integer LFO periods, no click)

Loops must tile: shrine_hum and amb_mine build every oscillation from an integer
number of cycles across the buffer, so the last sample meets the first with no
discontinuity. Everything else is a decaying one-shot.
"""

import math
import os
import random
import struct
import wave

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
TAU = 2 * math.pi


# --- write -----------------------------------------------------------------

def _write(name, samples):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(
            b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples)
        )
    print(f"  {name:<20} {len(samples) / RATE * 1000:6.0f} ms")


# --- primitives ------------------------------------------------------------

def _n(seconds):
    return int(seconds * RATE)


def noise():
    return random.uniform(-1.0, 1.0)


def env(i, n, attack=0.002, power=3.0):
    """Fast attack, exponential-ish decay. The decay curve is most of what makes
    a sound read as an impact instead of a beep."""
    a = int(attack * RATE)
    if i < a:
        return i / max(1, a)
    t = (i - a) / max(1, n - a)
    return (1.0 - t) ** power


def sine(freq, t):
    return math.sin(TAU * freq * t)


def saw(freq, t):
    return 2.0 * ((freq * t) % 1.0) - 1.0


def square(freq, t, duty=0.5):
    return 1.0 if (freq * t) % 1.0 < duty else -1.0


def lp(samples, coeff):
    """One-pole low-pass. coeff in (0,1]; lower = darker."""
    out = []
    prev = 0.0
    for x in samples:
        prev = prev + coeff * (x - prev)
        out.append(prev)
    return out


def hp(samples, coeff):
    """One-pole high-pass — samples minus their low-passed self."""
    low = lp(samples, coeff)
    return [samples[i] - low[i] for i in range(len(samples))]


def soft(x, drive=1.4):
    """tanh soft-clip. Adds harmonics and glues a layered hit into one body."""
    return math.tanh(x * drive)


def mix(*layers):
    """Sum equal-length (or ragged) sample lists into the longest."""
    n = max(len(l) for l in layers)
    out = [0.0] * n
    for l in layers:
        for i, s in enumerate(l):
            out[i] += s
    return out


def normalize(samples, peak=0.9):
    hi = max(1e-6, max(abs(x) for x in samples))
    g = peak / hi
    return [x * g for x in samples]


def metallic(partials, dur, decay=8.0, attack=0.001):
    """Sum of inharmonic partials — the ring that makes metal sound like metal.
    partials: list of (freq, gain)."""
    n = _n(dur)
    out = []
    for i in range(n):
        t = i / RATE
        e = env(i, n, attack, power=1.0) * math.exp(-t * decay)
        v = sum(g * sine(f, t) for f, g in partials)
        out.append(v * e)
    return out


# --- combat: weapon-class impact transients --------------------------------
# The "what swung" layer. Sharp, short, tells you the tool, carries little tone
# so the material layer underneath it does the pitch work.

def impact_pick():
    """Sharp metallic tick — a pointed pick biting in. Bright, very short."""
    n = _n(0.09)
    out = []
    for i in range(n):
        t = i / RATE
        e = env(i, n, 0.0006, power=6.0)
        tick = noise() * (1.0 - i / n) ** 10
        ring = sine(2600, t) * 0.4 + sine(3900, t) * 0.2
        out.append(soft((tick * 0.7 + ring * 0.5) * e, 1.6))
    return normalize(out, 0.85)


def impact_blade():
    """A slashing 'shing' — filtered noise sweeping up, thin and keen."""
    n = _n(0.13)
    raw = [noise() for _ in range(n)]
    band = hp(lp(raw, 0.5), 0.06)  # band-ish
    out = []
    for i in range(n):
        p = i / n
        e = env(i, n, 0.001, power=4.0)
        # rising centre gives the metallic 'sheen'
        sheen = sine(1800 + 2600 * p, i / RATE) * 0.3 * (1.0 - p)
        out.append(soft((band[i] * 0.8 + sheen) * e, 1.5))
    return normalize(out, 0.85)


def impact_blunt():
    """Deep leathery thud — a maul/haft landing. Low, no shimmer."""
    n = _n(0.12)
    out = []
    for i in range(n):
        t = i / RATE
        e = env(i, n, 0.001, power=4.0)
        body = sine(150 * (1.0 - 0.4 * (i / n)), t) * 0.9
        knock = noise() * 0.4 * (1.0 - i / n) ** 6
        out.append(soft((body + knock) * e, 1.7))
    return normalize(out, 0.9)


# --- combat: material response layers --------------------------------------
# The "what got hit" layer, played under the impact. This is where the pitch and
# texture of the surface lives.

def mat_flesh():
    """Wet, dull, pitch-dropping squish. No ring — meat swallows the hit."""
    n = _n(0.15)
    out = []
    for i in range(n):
        t = i / RATE
        e = env(i, n, 0.001, power=4.5)
        freq = 120 * (1.0 - 0.55 * (i / n))
        body = sine(freq, t) * 0.8
        squelch = noise() * 0.3 * (1.0 - i / n) ** 3
        out.append((body + squelch) * e)
    return normalize(lp(out, 0.6), 0.8)


def mat_armor():
    """A heavy hit skidding off plate — a low iron THUNK with a short, dark ring
    on top. Warm, not tinny (Dustin's note): the ring's partials are pulled well
    down, the bright clank is tamed, and a dropping low body carries the weight."""
    # Metallic ring, pitched into the low-mids so it clangs like iron rather than
    # pinging like a triangle — but still clearly metal, not a dull thud (which
    # would collapse into the flesh sound). Moderate decay: a short clang, not a bell.
    ring = metallic([(300, 1.0), (470, 0.7), (700, 0.5), (1050, 0.28)], 0.28, decay=15.0)
    n = len(ring)
    out = []
    for i in range(n):
        t = i / RATE
        e = env(i, n, 0.0008, power=3.5)
        body = sine(150 * (1.0 - 0.4 * (i / n)), t) * 0.5   # a little iron thunk beneath
        clank = noise() * (1.0 - i / n) ** 10 * 0.3         # brief contact grit, tamed
        out.append((body + clank) * e + ring[i] * 0.95)
    # A gentle top-end shave only — keep the metallic mids, kill the tinny sizzle.
    return normalize([soft(s, 1.4) for s in lp(out, 0.92)], 0.82)


def mat_bone():
    """Dry crack — a hard knock with a short woody snap, no wet, no ring."""
    n = _n(0.12)
    out = []
    for i in range(n):
        t = i / RATE
        e = env(i, n, 0.0006, power=7.0)
        crack = noise() * (1.0 - i / n) ** 6
        knock = sine(320 * (1.0 - 0.3 * (i / n)), t) * 0.5
        out.append(soft((crack * 0.8 + knock) * e, 1.5))
    return normalize(hp(out, 0.2), 0.82)


def mat_stone():
    """Hard, unyielding crack — a chip of rock, bright and instant, no give."""
    n = _n(0.1)
    out = []
    for i in range(n):
        t = i / RATE
        e = env(i, n, 0.0004, power=9.0)
        chip = noise() * (1.0 - i / n) ** 5
        ping = (sine(900, t) + sine(1500, t) * 0.5) * 0.4 * (1.0 - i / n) ** 3
        out.append(soft((chip + ping) * e, 1.4))
    return normalize(out, 0.8)


def mat_wood():
    """A knock on a practice dummy — hollow, low, brief. The training-hall sound."""
    n = _n(0.13)
    out = []
    for i in range(n):
        t = i / RATE
        e = env(i, n, 0.001, power=5.0)
        hollow = sine(230 * (1.0 - 0.35 * (i / n)), t) * 0.8
        tap = noise() * 0.25 * (1.0 - i / n) ** 8
        out.append((hollow + tap) * e)
    return normalize(lp(out, 0.7), 0.78)


def mat_ecto():
    """Soft, airy, otherworldly — a wisp taking a hit. Detuned high sines + air."""
    n = _n(0.2)
    out = []
    for i in range(n):
        t = i / RATE
        e = env(i, n, 0.004, power=2.6)
        shimmer = sine(660, t) * 0.4 + sine(660 * 1.5, t) * 0.25 + sine(990 * 1.33, t) * 0.15
        air = noise() * 0.15 * math.sin(math.pi * i / n)
        out.append((shimmer + air) * e * 0.7)
    return normalize(lp(out, 0.4), 0.6)


# --- combat: pillars & extras ----------------------------------------------

def parry():
    """Bright two-tone ring — the most distinct sound in the set. The parry is a
    pillar; it must be legible with your eyes shut."""
    n = _n(0.34)
    out = []
    for i in range(n):
        t = i / RATE
        e = env(i, n, 0.0006, power=2.0)
        a = sine(1560, t)
        b = sine(2340, t) * 0.6
        shimmer = sine(3120, t) * 0.28 * (1.0 - i / n) ** 2
        click = noise() * 0.45 * (1.0 - i / n) ** 18
        out.append((a + b + shimmer + click) * e)
    return normalize(out, 0.62)


def riposte():
    """The parry payoff strike — a heavy, satisfying metallic confirm. Lower and
    fuller than a normal connect: this is the reward, and it should feel like one."""
    ring = metallic([(220, 1.0), (330, 0.7), (550, 0.5), (880, 0.35), (1650, 0.2)], 0.42, decay=7.0)
    n = len(ring)
    thump = [sine(90 * (1.0 - 0.3 * i / n), i / RATE) * math.exp(-i / RATE * 9.0) * 0.9 for i in range(n)]
    crack = [noise() * (1.0 - i / n) ** 12 * 0.5 for i in range(n)]
    return normalize([soft(s, 1.3) for s in mix(ring, thump, crack)], 0.9)


def poise_break():
    """An enemy's guard gives out — a big descending crunch with a stagger wobble.
    The 'you cracked it' beat, so it lands heavy and reads as a state change."""
    n = _n(0.4)
    out = []
    for i in range(n):
        t = i / RATE
        p = i / n
        e = env(i, n, 0.001, power=2.2)
        # pitch-dropping body with a slow wobble (the stagger)
        wob = 1.0 + 0.06 * sine(9, t)
        body = sine(200 * (1.0 - 0.6 * p) * wob, t) * 0.8
        grind = saw(140 * (1.0 - 0.4 * p), t) * 0.3
        crunch = noise() * 0.4 * (1.0 - p) ** 3
        out.append(soft((body + grind + crunch) * e, 1.5))
    return normalize(out, 0.88)


def whoosh_light():
    """Fast air of a light swing. Short filtered-noise swell, high and quick."""
    n = _n(0.16)
    prev = 0.0
    out = []
    for i in range(n):
        p = i / n
        raw = noise()
        prev = prev * 0.72 + raw * 0.28
        out.append(prev * math.sin(math.pi * p) * (0.6 + 0.4 * p))
    return normalize(hp(out, 0.12), 0.5)


def whoosh_heavy():
    """Slow, low air of a heavy swing — a maul cutting the room. Longer, darker."""
    n = _n(0.28)
    prev = 0.0
    out = []
    for i in range(n):
        p = i / n
        raw = noise()
        prev = prev * 0.9 + raw * 0.1
        out.append(prev * math.sin(math.pi * p) * (0.5 + 0.5 * p))
    return normalize(lp(out, 0.5), 0.6)


def enemy_death():
    """A kill — downward pitch collapse with a final rattle. Material colour is
    layered on at play time; this is the shared 'it went down' body."""
    n = _n(0.34)
    out = []
    for i in range(n):
        t = i / RATE
        p = i / n
        e = env(i, n, 0.001, power=2.4)
        fall = sine(260 * (1.0 - 0.7 * p), t) * 0.7
        rattle = noise() * 0.35 * (1.0 - p) ** 2 * (0.5 + 0.5 * sine(30, t))
        out.append(soft((fall + rattle) * e, 1.3))
    return normalize(out, 0.82)


def player_death():
    """The punish. A low, final, somber hit — heavy sub, a downward groan, no
    sparkle. You lost the haul; the sound should sit in your chest."""
    n = _n(0.8)
    out = []
    for i in range(n):
        t = i / RATE
        p = i / n
        e = env(i, n, 0.003, power=1.8)
        sub = sine(60 * (1.0 - 0.25 * p), t) * 0.9
        groan = saw(110 * (1.0 - 0.4 * p), t) * 0.3 * (1.0 - p)
        out.append(soft((sub + groan) * e, 1.2))
    return normalize(lp(out, 0.5), 0.9)


# --- movement + damage -----------------------------------------------------

def jump():
    n = _n(0.09)
    out = []
    for i in range(n):
        t = i / RATE
        e = env(i, n, 0.001, power=2.5)
        freq = 320 + 300 * (i / n)
        out.append(square(freq, t, 0.5) * e * 0.5)
    return normalize(out, 0.5)


def doublejump():
    """A brighter, airier second hop — reads as 'again, mid-air'."""
    n = _n(0.1)
    out = []
    for i in range(n):
        t = i / RATE
        e = env(i, n, 0.001, power=2.2)
        freq = 480 + 420 * (i / n)
        air = noise() * 0.2 * (1.0 - i / n) ** 2
        out.append((square(freq, t, 0.4) * 0.7 + air) * e)
    return normalize(hp(out, 0.1), 0.5)


def land():
    n = _n(0.12)
    out = []
    for i in range(n):
        t = i / RATE
        e = env(i, n, 0.001, power=4.0)
        freq = 120 * (1.0 - 0.5 * (i / n))
        out.append((sine(freq, t) + noise() * 0.25) * e)
    return normalize(out, 0.7)


def land_soft():
    """A gentle touch-down for short drops — less thud, more scuff."""
    n = _n(0.08)
    out = []
    for i in range(n):
        e = env(i, n, 0.001, power=5.0)
        out.append(noise() * 0.5 * e)
    return normalize(lp(out, 0.35), 0.4)


def roll():
    """Filtered-noise whoosh that swells then fades — reads as a committed move."""
    n = _n(0.26)
    prev = 0.0
    out = []
    for i in range(n):
        p = i / n
        prev = prev * 0.86 + noise() * 0.14
        out.append(prev * math.sin(math.pi * p))
    return normalize(out, 0.75)


def hurt():
    """The player takes a hit — a short, ugly descending buzz. Unpleasant on
    purpose; damage should never sound good."""
    n = _n(0.2)
    out = []
    for i in range(n):
        t = i / RATE
        e = env(i, n, 0.001, power=2.5)
        freq = 260 * (1.0 - 0.55 * (i / n))
        out.append((saw(freq, t) * 0.6 + noise() * 0.2) * e)
    return normalize(out, 0.72)


# --- pickups & economy -----------------------------------------------------

def pickup_ore():
    """Collecting haul — a warm two-note lift, like a coin caught. Softer attack
    and a lower base than the first pass (Dustin: "weirdish"), so it reads as a
    rounded chime rather than a bright blip, and a short glide between the two
    notes hides the abrupt step that made it odd."""
    n = _n(0.2)
    out = []
    for i in range(n):
        t = i / RATE
        p = i / n
        # Glide up a fifth around the midpoint instead of a hard jump.
        f = 720.0 + 360.0 * (0.5 + 0.5 * math.tanh((p - 0.45) * 14.0))
        e = env(i, n, 0.004, power=2.4)
        out.append((sine(f, t) * 0.62 + sine(f * 2.0, t) * 0.13) * e)
    return normalize(lp(out, 0.6), 0.55)


def pickup_heart():
    """Healing — a warm, rounded major-third chime. Relief, not fanfare."""
    n = _n(0.3)
    out = []
    for i in range(n):
        t = i / RATE
        e = env(i, n, 0.005, power=2.2)
        v = sine(523, t) * 0.5 + sine(659, t) * 0.35 + sine(784, t) * 0.25
        out.append(v * e)
    return normalize(lp(out, 0.5), 0.6)


def pickup_buff():
    """A temporary boon — a rising sparkle arpeggio, a little magical."""
    n = _n(0.32)
    out = []
    notes = [660, 880, 990, 1320]
    for i in range(n):
        t = i / RATE
        p = i / n
        idx = min(len(notes) - 1, int(p * len(notes)))
        e = env(i, n, 0.002, power=1.6)
        shimmer = sine(notes[idx], t) * 0.6 + sine(notes[idx] * 2.01, t) * 0.2
        out.append(shimmer * e)
    return normalize(out, 0.55)


def pickup_weapon():
    """A real find — a metallic 'ka-ching' with a bright ring. Reshapes the run."""
    ring = metallic([(880, 1.0), (1320, 0.6), (1760, 0.4), (2640, 0.25)], 0.36, decay=6.0, attack=0.002)
    n = len(ring)
    scrape = [noise() * (1.0 - i / n) ** 20 * 0.5 for i in range(n)]
    return normalize(mix(ring, scrape), 0.62)


def buy_upgrade():
    """Anvil/forge — two low metal strikes. The blacksmith made you stronger."""
    def strike(f0):
        m = metallic([(f0, 1.0), (f0 * 2.7, 0.5), (f0 * 5.1, 0.25)], 0.2, decay=14.0)
        k = len(m)
        return mix(m, [noise() * (1.0 - i / k) ** 16 * 0.5 for i in range(k)])
    a = strike(300)
    b = strike(360)
    gap = _n(0.11)
    buf = [0.0] * (gap + len(b))
    for i, s in enumerate(a):
        if i < len(buf):
            buf[i] += s
    for i, s in enumerate(b):
        buf[gap + i] += s * 0.9
    return normalize([soft(s, 1.2) for s in buf], 0.8)


def shrine_accept():
    """A dark bargain sealed — a low minor drone that blooms then a soft bell.
    Ominous but rewarding: you took the deal."""
    n = _n(0.6)
    out = []
    for i in range(n):
        t = i / RATE
        p = i / n
        bloom = math.sin(math.pi * min(1.0, p * 1.6))
        drone = (sine(110, t) * 0.5 + sine(164.8, t) * 0.4 + sine(220, t) * 0.3) * bloom
        bell = (sine(880, t) * 0.3 + sine(1174, t) * 0.15) * (p ** 2) * (1.0 - p)
        out.append(soft((drone + bell) * 0.7, 1.1))
    return normalize(out, 0.6)


# --- UI --------------------------------------------------------------------

def ui_move():
    """Menu navigation tick — soft, short, low. Heard constantly; must not annoy."""
    n = _n(0.04)
    out = []
    for i in range(n):
        t = i / RATE
        e = env(i, n, 0.001, power=4.0)
        out.append((sine(880, t) * 0.6 + sine(1320, t) * 0.2) * e)
    return normalize(out, 0.32)


def ui_select():
    """Confirm — a bright, positive up-tick. A little reward for choosing."""
    n = _n(0.1)
    out = []
    for i in range(n):
        t = i / RATE
        p = i / n
        f = 700 + 500 * p
        e = env(i, n, 0.001, power=2.5)
        out.append((sine(f, t) * 0.6 + sine(f * 1.5, t) * 0.2) * e)
    return normalize(out, 0.4)


def ui_back():
    """Cancel/back — a lower, down-tick. The inverse of select."""
    n = _n(0.09)
    out = []
    for i in range(n):
        t = i / RATE
        p = i / n
        f = 620 - 260 * p
        e = env(i, n, 0.001, power=3.0)
        out.append(sine(f, t) * 0.6 * e)
    return normalize(out, 0.38)


def ui_pause():
    """Opening the pause menu — a soft muffled double-blip, 'time stops'."""
    n = _n(0.16)
    out = []
    for i in range(n):
        t = i / RATE
        e = env(i, n, 0.003, power=2.0)
        gate = 1.0 if (i / RATE) % 0.08 < 0.05 else 0.3
        out.append(sine(420, t) * 0.5 * e * gate)
    return normalize(lp(out, 0.4), 0.4)


def ui_slider():
    """A slider notch — the quietest, driest tick in the set."""
    n = _n(0.025)
    out = []
    for i in range(n):
        t = i / RATE
        e = env(i, n, 0.001, power=5.0)
        out.append(sine(1200, t) * e)
    return normalize(out, 0.28)


# --- hazard ----------------------------------------------------------------

def axe_whoosh():
    """The pendulum cutting past — a low, chain-creak-tinted air pass."""
    n = _n(0.36)
    prev = 0.0
    out = []
    for i in range(n):
        t = i / RATE
        p = i / n
        prev = prev * 0.9 + noise() * 0.1
        creak = sine(70 + 20 * sine(6, t), t) * 0.15 * math.sin(math.pi * p)
        out.append((prev * math.sin(math.pi * p) + creak))
    return normalize(lp(out, 0.5), 0.55)


def axe_hit():
    """The blade catches you — a heavy metallic chunk. Unparryable, so it should
    feel like a mistake, not a trade."""
    ring = metallic([(180, 1.0), (300, 0.6), (520, 0.4), (900, 0.25)], 0.3, decay=13.0)
    n = len(ring)
    chunk = [noise() * (1.0 - i / n) ** 8 * 0.7 for i in range(n)]
    return normalize([soft(s, 1.4) for s in mix(ring, chunk)], 0.85)


# --- seamless loops --------------------------------------------------------
# Every oscillation uses an integer number of cycles across the buffer, so the
# tail meets the head with no click. The Sfx layer forces LOOP_FORWARD on these.

def _loop_hz(cycles, loop_len):
    """A frequency that fits `cycles` whole periods into a `loop_len`-second loop."""
    return cycles / loop_len


def shrine_hum(loop_len=4.0):
    """A low sacred drone for a lit altar — positional, so it swells as you near.
    Detuned fifth with a slow shimmer LFO, all integer-cycle for a clean loop."""
    n = _n(loop_len)
    out = []
    root = _loop_hz(round(98 * loop_len), loop_len)      # ~G2
    fifth = _loop_hz(round(146.8 * loop_len), loop_len)  # ~D3
    shimmer = _loop_hz(round(392 * loop_len), loop_len)  # ~G4
    lfo = _loop_hz(round(0.5 * loop_len) or 1, loop_len)
    for i in range(n):
        t = i / RATE
        amp = 0.7 + 0.3 * sine(lfo, t)
        v = (sine(root, t) * 0.5 + sine(fifth, t) * 0.35 + sine(shimmer, t) * 0.12 * amp)
        out.append(v * 0.5)
    return normalize(lp(out, 0.6), 0.5)


def amb_mine(loop_len=6.0):
    """The mine's own breath — a dark wind/drone bed under a delve. Filtered noise
    shaped by slow integer-cycle LFOs plus a barely-there sub, so it tiles clean."""
    n = _n(loop_len)
    # windy filtered noise, but made loopable by cross-fading the buffer with its
    # own half-shifted copy so the seam is masked.
    raw = [noise() for _ in range(n)]
    wind = lp(raw, 0.04)
    half = n // 2
    shifted = wind[half:] + wind[:half]
    out = []
    sub = _loop_hz(round(48 * loop_len), loop_len)
    lfo = _loop_hz(round(0.33 * loop_len) or 1, loop_len)
    for i in range(n):
        t = i / RATE
        # triangular cross-fade between the buffer and its shift hides both seams
        x = i / n
        w = 1.0 - abs(2.0 * x - 1.0)
        blended = wind[i] * w + shifted[i] * (1.0 - w)
        gust = 0.5 + 0.5 * sine(lfo, t)
        drone = sine(sub, t) * 0.12
        out.append(blended * (0.4 + 0.6 * gust) + drone)
    return normalize(out, 0.42)


# --- enemy tells & tension -------------------------------------------------

def telegraph():
    """An enemy's WIND-UP tell — a short, rising, slightly-dissonant swell that
    says 'a blow is coming' without you having to be looking at it. Deliberately
    a little unpleasant (a minor-second beat), so it reads as threat, not music.
    Positional on the enemy, so you can hear an off-screen swing charging."""
    n = _n(0.2)
    out = []
    for i in range(n):
        t = i / RATE
        p = i / n
        e = math.sin(math.pi * p) ** 0.6          # swell in and out
        f = 300.0 + 340.0 * p                     # rising pitch = "charging"
        beat = sine(f, t) * 0.6 + sine(f * 1.06, t) * 0.4  # detune = uneasy beating
        out.append(soft(beat * e, 1.2))
    return normalize(lp(out, 0.6), 0.5)


def projectile_whoosh():
    """A thrown rock cutting the air — a fast 'fwip' with a downward pitch bend
    (a passing object), distinct from a melee swing's whoosh. Positional on the
    projectile so it tracks across the room."""
    n = _n(0.22)
    prev = 0.0
    out = []
    for i in range(n):
        t = i / RATE
        p = i / n
        prev = prev * 0.8 + noise() * 0.2
        tone = sine(520.0 * (1.0 - 0.5 * p), t) * 0.3 * (1.0 - p)  # downward bend
        out.append((prev * math.sin(math.pi * p) + tone))
    return normalize(hp(out, 0.1), 0.55)


def heartbeat(loop_len=0.95):
    """A SEAMLESS LOOP: the player's own heart when near death — a low lub-dub
    thump then silence, so it tiles cleanly (it's near-zero at both edges). The
    Sfx layer loops it while health is low and stops it when you recover. Sub-
    heavy and soft: tension, not a jump-scare."""
    n = _n(loop_len)
    out = [0.0] * n

    def thump(start, gain):
        for k in range(_n(0.16)):
            t = k / RATE
            f = 60.0 * math.exp(-t * 14.0) + 38.0   # a soft, round low pulse
            s = math.sin(TAU * f * t) * math.exp(-t * 11.0) * gain
            j = start + k
            if 0 <= j < n:
                out[j] += s

    thump(_n(0.02), 1.0)    # lub
    thump(_n(0.20), 0.7)    # dub
    return normalize(out, 0.75)


# --- bake ------------------------------------------------------------------

SOUNDS = {
    # weapon-class impacts
    "impact_pick.wav": impact_pick,
    "impact_blade.wav": impact_blade,
    "impact_blunt.wav": impact_blunt,
    # material responses
    "mat_flesh.wav": mat_flesh,
    "mat_armor.wav": mat_armor,
    "mat_bone.wav": mat_bone,
    "mat_stone.wav": mat_stone,
    "mat_wood.wav": mat_wood,
    "mat_ecto.wav": mat_ecto,
    # combat pillars & extras
    "parry.wav": parry,
    "riposte.wav": riposte,
    "poise_break.wav": poise_break,
    "whoosh_light.wav": whoosh_light,
    "whoosh_heavy.wav": whoosh_heavy,
    "enemy_death.wav": enemy_death,
    "player_death.wav": player_death,
    # movement + damage
    "jump.wav": jump,
    "doublejump.wav": doublejump,
    "land.wav": land,
    "land_soft.wav": land_soft,
    "roll.wav": roll,
    "hurt.wav": hurt,
    # pickups & economy
    "pickup_ore.wav": pickup_ore,
    "pickup_heart.wav": pickup_heart,
    "pickup_buff.wav": pickup_buff,
    "pickup_weapon.wav": pickup_weapon,
    "buy_upgrade.wav": buy_upgrade,
    "shrine_accept.wav": shrine_accept,
    # UI
    "ui_move.wav": ui_move,
    "ui_select.wav": ui_select,
    "ui_back.wav": ui_back,
    "ui_pause.wav": ui_pause,
    "ui_slider.wav": ui_slider,
    # enemy tells & ranged
    "telegraph.wav": telegraph,
    "projectile_whoosh.wav": projectile_whoosh,
    # hazard
    "axe_whoosh.wav": axe_whoosh,
    "axe_hit.wav": axe_hit,
    # seamless loops
    "shrine_hum.wav": shrine_hum,
    "amb_mine.wav": amb_mine,
    "heartbeat.wav": heartbeat,
}


if __name__ == "__main__":
    random.seed(7)  # reproducible output
    print(f"generating {len(SOUNDS)} sound effects:")
    for name, fn in SOUNDS.items():
        _write(name, fn())
    print("done")

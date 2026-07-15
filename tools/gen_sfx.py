#!/usr/bin/env python3
"""Generate placeholder SFX for the M2 feel pass.

Synthesised rather than sourced, so they are reproducible, dependency-free and
unambiguously placeholder — nobody will mistake these for final audio. Regenerate
with:  python3 tools/gen_sfx.py

Real audio is M9's problem. These exist because hitstop without a sound is only
half of "crunchy": the freeze tells you that you connected, the sound tells you
what you connected with.
"""

import math
import os
import random
import struct
import wave

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")


def _write(name, samples):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        frames = b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples
        )
        w.writeframes(frames)
    print(f"  {name}  {len(samples) / RATE * 1000:.0f} ms")


def _env(i, n, attack=0.002, power=3.0):
    """Fast attack, exponential decay. The decay curve is what makes a hit read
    as an impact rather than a beep."""
    a = int(attack * RATE)
    if i < a:
        return i / max(1, a)
    t = (i - a) / max(1, n - a)
    return (1.0 - t) ** power


def noise():
    return random.uniform(-1.0, 1.0)


def hit(n=int(0.14 * RATE)):
    """Noise crack over a pitch-dropping body. Generic 'something connected'."""
    out = []
    for i in range(n):
        t = i / RATE
        e = _env(i, n, power=4.0)
        freq = 180.0 * (1.0 - 0.6 * (i / n))
        body = math.sin(2 * math.pi * freq * t) * 0.7
        crack = noise() * 0.5 * (1.0 - i / n) ** 8
        out.append((body + crack) * e * 0.9)
    return out


def parry(n=int(0.32 * RATE)):
    """Bright two-tone ring. Deliberately the most distinct sound in the set:
    the parry is the pillar, so it must be audible without looking."""
    out = []
    for i in range(n):
        t = i / RATE
        e = _env(i, n, power=2.2)
        a = math.sin(2 * math.pi * 1560.0 * t)
        b = math.sin(2 * math.pi * 2340.0 * t) * 0.6
        shimmer = math.sin(2 * math.pi * 3120.0 * t) * 0.25 * (1.0 - i / n) ** 2
        click = noise() * 0.4 * (1.0 - i / n) ** 16
        out.append((a + b + shimmer + click) * e * 0.32)
    return out


def jump(n=int(0.09 * RATE)):
    """Short rising blip."""
    out = []
    for i in range(n):
        t = i / RATE
        e = _env(i, n, power=2.5)
        freq = 320.0 + 300.0 * (i / n)
        square = 1.0 if math.sin(2 * math.pi * freq * t) > 0 else -1.0
        out.append(square * e * 0.16)
    return out


def land(n=int(0.11 * RATE)):
    """Low thud."""
    out = []
    for i in range(n):
        t = i / RATE
        e = _env(i, n, power=4.0)
        freq = 120.0 * (1.0 - 0.5 * (i / n))
        out.append((math.sin(2 * math.pi * freq * t) + noise() * 0.25) * e * 0.4)
    return out


def roll(n=int(0.26 * RATE)):
    """Filtered noise whoosh. Swells then fades so it reads as movement."""
    out = []
    prev = 0.0
    for i in range(n):
        p = i / n
        swell = math.sin(math.pi * p)
        raw = noise()
        # One-pole lowpass; without it this is just hiss.
        prev = prev * 0.86 + raw * 0.14
        out.append(prev * swell * 0.5)
    return out


def hurt(n=int(0.2 * RATE)):
    """Descending buzz. Unpleasant on purpose."""
    out = []
    for i in range(n):
        t = i / RATE
        e = _env(i, n, power=2.5)
        freq = 260.0 * (1.0 - 0.55 * (i / n))
        saw = 2.0 * ((freq * t) % 1.0) - 1.0
        out.append((saw * 0.6 + noise() * 0.2) * e * 0.3)
    return out


if __name__ == "__main__":
    random.seed(7)  # reproducible output
    print("generating placeholder sfx:")
    _write("hit.wav", hit())
    _write("parry.wav", parry())
    _write("jump.wav", jump())
    _write("land.wav", land())
    _write("roll.wav", roll())
    _write("hurt.wav", hurt())
    print("done")

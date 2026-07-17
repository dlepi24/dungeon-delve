#!/usr/bin/env python3
"""Generate placeholder synthwave loops.

Run: python3 tools/gen_music.py  ->  assets/audio/music_delve.wav, music_hub.wav

Placeholder, like the SFX: synthesised from code, reproducible, and meant to be
replaced by a real/licensed track at M9. Dark retro synthwave — minor key, saw
bass, plucked arp, a slow pad, and (for the delve) a simple drum pulse. The hub
version drops the drums and softens everything into an ambient wash.

Written by hand (struct+wave), so no dependencies. Deterministic: the only
randomness is drum noise, seeded, so re-running produces the identical file.
"""

import math
import os
import random
import struct
import wave

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")

# A natural minor. Semitone offsets from A2 (110 Hz).
A2 = 110.0
def note(semitones, octave=0):
    return A2 * (2.0 ** (semitones / 12.0 + octave))

# Chord progression i - VI - III - VII in A minor: Am, F, C, G.
# Each entry: (root semitone, [chord tone semitones]).
PROG = [
    (0,  [0, 3, 7]),    # Am  (A C E)
    (-4, [0, 4, 7]),    # F   (F A C)
    (3,  [0, 4, 7]),    # C   (C E G)
    (-2, [0, 4, 7]),    # G   (G B D)
]

BPM = 96
BEAT = 60.0 / BPM
BAR = BEAT * 4
BARS_PER_CHORD = 2


def _saw(freq, t):
    return 2.0 * ((freq * t) % 1.0) - 1.0


def _square(freq, t, duty=0.5):
    return 1.0 if (freq * t) % 1.0 < duty else -1.0


def _adsr(i, n, a=0.01, d=0.2, s=0.6, r=0.2):
    at, dt, rt = int(a * RATE), int(d * RATE), int(r * RATE)
    if i < at:
        return i / max(1, at)
    if i < at + dt:
        return 1.0 - (1.0 - s) * (i - at) / max(1, dt)
    if i < n - rt:
        return s
    return s * max(0.0, 1.0 - (i - (n - rt)) / max(1, rt))


def _onepole_lp(samples, coeff):
    out = []
    prev = 0.0
    for x in samples:
        prev = prev + coeff * (x - prev)
        out.append(prev)
    return out


def _mix_into(buf, start, samples, gain):
    for i, s in enumerate(samples):
        j = start + i
        if 0 <= j < len(buf):
            buf[j] += s * gain


def _bass_note(freq, dur):
    n = int(dur * RATE)
    return [_saw(freq, i / RATE) * _adsr(i, n, 0.01, 0.1, 0.8, 0.1) for i in range(n)]


def _pluck(freq, dur):
    n = int(dur * RATE)
    out = []
    for i in range(n):
        t = i / RATE
        # Two detuned squares for a bright retro pluck.
        v = _square(freq, t, 0.5) * 0.6 + _square(freq * 1.005, t, 0.35) * 0.4
        out.append(v * _adsr(i, n, 0.002, 0.08, 0.25, 0.12))
    return out


def _pad_chord(freqs, dur):
    n = int(dur * RATE)
    out = []
    for i in range(n):
        t = i / RATE
        v = sum(math.sin(2 * math.pi * f * t) for f in freqs) / len(freqs)
        out.append(v * _adsr(i, n, 0.4, 0.3, 0.7, 0.6))
    return _onepole_lp(out, 0.08)


def _kick(dur=0.28):
    n = int(dur * RATE)
    out = []
    for i in range(n):
        t = i / RATE
        freq = 120.0 * math.exp(-t * 24.0) + 45.0
        out.append(math.sin(2 * math.pi * freq * t) * math.exp(-t * 7.0))
    return out


def _snare(dur=0.2):
    n = int(dur * RATE)
    body = [math.sin(2 * math.pi * 190.0 * i / RATE) * 0.4 for i in range(n)]
    return [(body[i] + random.uniform(-1, 1) * 0.6) * math.exp(-i / RATE * 16.0) for i in range(n)]


def _hat(dur=0.05):
    n = int(dur * RATE)
    return [random.uniform(-1, 1) * math.exp(-i / RATE * 60.0) * 0.5 for i in range(n)]


def build(with_drums):
    total_bars = len(PROG) * BARS_PER_CHORD
    length = total_bars * BAR
    n = int(length * RATE)
    buf = [0.0] * n

    for ci, (root, tones) in enumerate(PROG):
        chord_start = ci * BARS_PER_CHORD * BAR
        root_freq = note(root, -1)
        pad_freqs = [note(root + tn, 0) for tn in tones]

        # Pad holds the whole chord.
        _mix_into(buf, int(chord_start * RATE), _pad_chord(pad_freqs, BARS_PER_CHORD * BAR), 0.16)

        for bar in range(BARS_PER_CHORD):
            bar_start = chord_start + bar * BAR
            # Bass on each beat, root then fifth for a little movement.
            for beat in range(4):
                bf = root_freq if beat % 2 == 0 else note(root + 7, -1)
                _mix_into(buf, int((bar_start + beat * BEAT) * RATE), _bass_note(bf, BEAT * 0.9), 0.34)
            # Arp: chord tones as eighth notes, climbing.
            arp = [root + tones[0], root + tones[1], root + tones[2], root + tones[1]] * 2
            for k, semi in enumerate(arp):
                t0 = bar_start + k * (BEAT / 2)
                _mix_into(buf, int(t0 * RATE), _pluck(note(semi, 1), BEAT / 2 * 0.9), 0.14 if with_drums else 0.10)
            if with_drums:
                for beat in range(4):
                    bt = bar_start + beat * BEAT
                    if beat in (0, 2):
                        _mix_into(buf, int(bt * RATE), _kick(), 0.6)
                    if beat in (1, 3):
                        _mix_into(buf, int(bt * RATE), _snare(), 0.34)
                    _mix_into(buf, int(bt * RATE), _hat(), 0.16)
                    _mix_into(buf, int((bt + BEAT / 2) * RATE), _hat(), 0.12)

    peak = max(1e-6, max(abs(x) for x in buf))
    norm = 0.85 / peak
    return [x * norm for x in buf]


def write(name, samples):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32000)) for s in samples))
    print(f"  {name}  {len(samples) / RATE:.1f}s")


if __name__ == "__main__":
    random.seed(11)
    print("generating placeholder synthwave:")
    write("music_delve.wav", build(with_drums=True))
    write("music_hub.wav", build(with_drums=False))
    print("done")

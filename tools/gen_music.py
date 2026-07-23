#!/usr/bin/env python3
"""Generate the game's music — synthesised, reproducible, dependency-free.

Run: python3 tools/gen_music.py  ->  assets/audio/music_*.wav

Placeholder like the SFX (synthesised, licence-free, an eventual drop-in swap for
recorded audio), but this is the "less repetitive" overhaul: the old tracks were
one 4-chord loop with a fixed arp and no tune, so they blurred together. Now each
track is a COMPOSED PIECE with:
  - an actual MELODY (hand-authored motifs, not a repeated arp) sung by a lead
    voice over the chords — the single biggest anti-repetition win;
  - VERSE/CHORUS structure — two (or more) contrasting sections concatenated, so
    the music changes partway through instead of looping four chords forever;
  - per-track TIMBRE (square/saw/sine lead, arp on/off, drum density, sub-bass)
    so the moods are distinct, and more ENERGY (higher tempos, busier drums) on
    the driving beds.

Deterministic: the only randomness is seeded drum noise, so re-running is
byte-identical. Loops tile because every section is a whole number of bars and
every motif is a whole number of beats that divides the section.
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

# The natural-minor SCALE degrees (A B C D E F G), for melodies: degree -> semitone.
NAT_MINOR = [0, 2, 3, 5, 7, 8, 10]
def scale_note(degree, octave=2):
    """A diatonic melody note by scale degree (0 = tonic A). Degrees wrap past 6
    into the next octave, so degree 9 is the 3rd an octave up."""
    o, i = divmod(degree, 7)
    return note(NAT_MINOR[i] + 12 * o, octave)

# --- chord progressions (root semitone, [chord-tone semitones]) -------------
PROG = [
    (0,  [0, 3, 7]),    # Am
    (-4, [0, 4, 7]),    # F
    (3,  [0, 4, 7]),    # C
    (-2, [0, 4, 7]),    # G
]
PROG_B = [
    (0,  [0, 3, 7]),    # Am
    (5,  [0, 3, 7]),    # Dm
    (7,  [0, 3, 7]),    # Em
    (-4, [0, 4, 7]),    # F
]
PROG_C = [
    (0,  [0, 3, 7]),    # Am
    (-2, [0, 4, 7]),    # G
    (-4, [0, 4, 7]),    # F
    (7,  [0, 3, 7]),    # Em
]
PROG_D = [
    (0,  [0, 3, 7]),    # Am
    (3,  [0, 4, 7]),    # C
    (-2, [0, 4, 7]),    # G
    (5,  [0, 3, 7]),    # Dm
]
PROG_E = [
    (0,  [0, 3, 7]),    # Am
    (2,  [0, 3, 6]),    # B dim colour
    (-4, [0, 4, 7]),    # F
    (7,  [0, 3, 7]),    # Em
]
PROG_BOSS = [
    (0,  [0, 3, 7]),    # Am
    (1,  [0, 3, 6]),    # Bb dim — the wrongness is the point
    (0,  [0, 3, 7]),    # Am
    (7,  [0, 3, 7]),    # Em
]
PROG_EXTRACT = [
    (-4, [0, 4, 7]),    # F
    (-2, [0, 4, 7]),    # G
    (3,  [0, 4, 7]),    # C  — resolve up and out of the minor
]
PROG_DEATH = [
    (5,  [0, 3, 7]),    # Dm
    (0,  [0, 3, 7]),    # Am
    (-5, [0, 3, 7]),    # low sink
]

# --- melodies: (scale-degree, beats), None = rest. Each totals 8 beats (two 4/4
# bars) so it tiles a section exactly. Hand-authored — a composed line reads as
# a tune where random notes read as noodling. ------------------------------------
M_DRIVE  = [(4, 1), (7, 1), (4, .5), (3, .5), (2, 1), (0, 1), (2, .5), (3, .5), (4, 1), (None, 1)]
M_BRIGHT = [(7, 1), (9, .5), (7, .5), (4, 1), (5, 1), (4, .5), (2, .5), (4, 1), (0, 1), (None, 1)]
M_MOODY  = [(0, 1), (2, 1), (3, 2), (2, 1), (4, 1), (3, 1), (0, 1)]
M_DREAD  = [(0, 2), (3, 2), (2, 2), (0, 1), (None, 1)]
M_WARM   = [(4, 1), (3, 1), (2, 1), (3, 1), (4, 2), (2, 1), (0, 1)]
M_BOSS   = [(0, .5), (0, .5), (3, 1), (0, .5), (2, .5), (1, 1), (0, 2), (4, 2)]

BPM = 96
BARS_PER_CHORD = 2


# --- oscillators & envelopes -----------------------------------------------

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


def _pluck(freq, dur, kind="square"):
    """The arp voice. kind picks timbre: square (bright), saw (warm), sine (soft)."""
    n = int(dur * RATE)
    out = []
    for i in range(n):
        t = i / RATE
        if kind == "saw":
            v = _saw(freq, t) * 0.5 + _saw(freq * 1.007, t) * 0.4
        elif kind == "sine":
            v = math.sin(2 * math.pi * freq * t) * 0.7 + math.sin(2 * math.pi * freq * 2.0 * t) * 0.12
        else:
            v = _square(freq, t, 0.5) * 0.6 + _square(freq * 1.005, t, 0.35) * 0.4
        out.append(v * _adsr(i, n, 0.002, 0.08, 0.25, 0.12))
    if kind == "saw":
        out = _onepole_lp(out, 0.22)
    elif kind == "sine":
        out = _onepole_lp(out, 0.5)
    return out


def _lead(freq, dur, kind="square"):
    """The MELODY voice — sustained, with gentle vibrato and a longer release so
    it SINGS over the arp rather than plinking like it. This is the voice the ear
    follows, which is what makes a track feel composed instead of looped."""
    n = int(dur * RATE)
    out = []
    for i in range(n):
        t = i / RATE
        vib = 1.0 + 0.006 * math.sin(2 * math.pi * 5.5 * t)  # slight vibrato
        f = freq * vib
        if kind == "saw":
            v = _saw(f, t) * 0.5 + _saw(f * 1.006, t) * 0.4
        elif kind == "sine":
            v = math.sin(2 * math.pi * f * t) + math.sin(2 * math.pi * f * 2.0 * t) * 0.15
        else:
            v = _square(f, t, 0.5) * 0.5 + _square(f * 1.004, t, 0.4) * 0.4
        out.append(v * _adsr(i, n, 0.01, 0.06, 0.75, 0.28))
    if kind == "saw":
        out = _onepole_lp(out, 0.3)
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


# --- section renderer -------------------------------------------------------

def _place_melody(buf, motif, beat, kind, gain, octave):
    """Tile a motif across the whole section buffer in the lead voice."""
    section_beats = len(buf) / RATE / beat
    tpos, idx = 0.0, 0
    while tpos < section_beats - 1e-6:
        degree, beats = motif[idx % len(motif)]
        idx += 1
        if degree is not None:
            f = scale_note(degree, octave)
            _mix_into(buf, int(tpos * beat * RATE), _lead(f, beats * beat * 0.95, kind), gain)
        tpos += beats


def render_section(prog, bpm, motif=None, bars_per_chord=BARS_PER_CHORD,
                   arp=True, lead="square", drum="full", sub=False,
                   melody_kind=None, melody_gain=0.16, melody_octave=2):
    """One SECTION: pad + bass + (optional) arp + drums + (optional) melody. Songs
    are built by concatenating contrasting sections. `drum` is 'full'/'kick'/
    'sparse'/'none'; `sub` adds a held sub-bass drone for the dark moods."""
    beat = 60.0 / bpm
    bar = beat * 4
    total_bars = len(prog) * bars_per_chord
    n = int(total_bars * bar * RATE)
    buf = [0.0] * n
    has_drums = drum != "none"

    kick_beats = {"full": (0, 2), "kick": (0, 2), "sparse": (0,), "none": ()}
    snare_beats = {"full": (1, 3), "kick": (), "sparse": (), "none": ()}

    for ci, (root, tones) in enumerate(prog):
        chord_start = ci * bars_per_chord * bar
        root_freq = note(root, -1)
        pad_freqs = [note(root + tn, 0) for tn in tones]

        _mix_into(buf, int(chord_start * RATE), _pad_chord(pad_freqs, bars_per_chord * bar), 0.16)
        if sub:
            _mix_into(buf, int(chord_start * RATE),
                      _pad_chord([note(root, -2)], bars_per_chord * bar), 0.13)

        for bi in range(bars_per_chord):
            bar_start = chord_start + bi * bar
            for bt_i in range(4):
                bf = root_freq if bt_i % 2 == 0 else note(root + 7, -1)
                _mix_into(buf, int((bar_start + bt_i * beat) * RATE), _bass_note(bf, beat * 0.9), 0.34)
            if arp:
                arp_notes = [root + tones[0], root + tones[1], root + tones[2], root + tones[1]] * 2
                for k, semi in enumerate(arp_notes):
                    t0 = bar_start + k * (beat / 2)
                    _mix_into(buf, int(t0 * RATE), _pluck(note(semi, 1), beat / 2 * 0.9, lead),
                              0.13 if has_drums else 0.10)
            if has_drums:
                for bt_i in range(4):
                    bt = bar_start + bt_i * beat
                    if bt_i in kick_beats[drum]:
                        _mix_into(buf, int(bt * RATE), _kick(), 0.6)
                    if bt_i in snare_beats[drum]:
                        _mix_into(buf, int(bt * RATE), _snare(), 0.34)
                    if drum == "full":
                        _mix_into(buf, int(bt * RATE), _hat(), 0.16)
                        _mix_into(buf, int((bt + beat / 2) * RATE), _hat(), 0.12)
                    elif drum == "kick":
                        _mix_into(buf, int(bt * RATE), _hat(), 0.09)

    if motif is not None:
        _place_melody(buf, motif, beat, melody_kind or lead, melody_gain, melody_octave)
    return buf


def song(sections, peak=0.85):
    """Concatenate sections into one piece and normalise. The contrast BETWEEN
    sections is what keeps a long loop from feeling repetitive."""
    buf = []
    for s in sections:
        buf += s
    hi = max(1e-6, max(abs(x) for x in buf))
    return [x * (peak / hi) for x in buf]


def sting(sections):
    """A short, NON-LOOPING cue (extract win, death). Concatenate, then fade the
    last half-second so it lands rather than cuts."""
    buf = song(sections)
    fade = int(0.5 * RATE)
    for k in range(fade):
        j = len(buf) - fade + k
        if 0 <= j < len(buf):
            buf[j] *= 1.0 - k / fade
    return buf


def write(name, samples):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32000)) for s in samples))
    print(f"  {name:<20} {len(samples) / RATE:5.1f}s")


if __name__ == "__main__":
    random.seed(11)
    print("generating music (melodic, sectioned):")

    # Five delve moods, each a two-section piece (verse -> contrasting chorus)
    # with its own melody, timbre and energy. Verse/chorus contrast + a sung line
    # is what fixes the "slow repetitive" read.
    # (a) DRIVING — the main bed: fast, square lead, a climbing hook.
    write("music_delve.wav", song([
        render_section(PROG,   126, motif=M_DRIVE,  lead="square", drum="kick"),
        render_section(PROG_C, 126, motif=M_BRIGHT, lead="square", drum="full"),
    ]))
    # (b) MOODY — slower, saw lead, no arp, sub-bass; a brooding tune carries it.
    write("music_delve_b.wav", song([
        render_section(PROG_B, 96, motif=M_MOODY, lead="saw", arp=False, drum="kick", sub=True),
        render_section(PROG_E, 96, motif=M_DREAD, lead="saw", arp=False, drum="kick", sub=True),
    ]))
    # (c) BRIGHT & FAST — most energetic, busy drums, high hook.
    write("music_delve_c.wav", song([
        render_section(PROG_C, 134, motif=M_BRIGHT, lead="square", drum="full"),
        render_section(PROG,   134, motif=M_DRIVE,  lead="square", drum="full"),
    ]))
    # (d) WARM — reedy saw throughout, a lyrical mid-tempo line.
    write("music_delve_d.wav", song([
        render_section(PROG_D, 116, motif=M_WARM,  lead="saw", drum="full"),
        render_section(PROG,   116, motif=M_DRIVE, lead="saw", drum="full"),
    ]))
    # (e) DREAD — slow, sine bell, sparse kick, sub; a spare, haunting melody.
    write("music_delve_e.wav", song([
        render_section(PROG_E, 88, motif=M_DREAD, lead="sine", arp=False, drum="sparse", sub=True),
        render_section(PROG_B, 88, motif=M_MOODY, lead="sine", arp=False, drum="sparse", sub=True),
    ]))

    # Hub: calm, no drums, soft bell arp + a gentle tune. A place to breathe.
    write("music_hub.wav", song([
        render_section(PROG_D, 82, motif=M_WARM,  lead="sine", drum="none"),
        render_section(PROG,   82, motif=M_MOODY, lead="sine", drum="none"),
    ]))
    # Boss: fast, menacing, saw + sub, the wrong-note vamp with a stabbing motif.
    write("music_boss.wav", song([
        render_section(PROG_BOSS, 142, motif=M_BOSS,  lead="saw", drum="full", sub=True),
        render_section(PROG_BOSS, 142, motif=M_DREAD, lead="saw", drum="full", sub=True),
    ]))
    # Title: slow, dreamy, sub under a soft bell line — its own place, not the hub.
    write("music_title.wav", song([
        render_section(PROG_D, 74, motif=M_WARM, lead="sine", drum="none", sub=True),
        render_section(PROG,   74, motif=M_WARM, lead="sine", drum="none", sub=True, melody_octave=3),
    ]))

    # One-shot stings.
    write("music_extract.wav", sting([
        render_section(PROG_EXTRACT, 120, motif=M_BRIGHT, lead="square", drum="full", bars_per_chord=1),
    ]))
    write("music_death.wav", sting([
        render_section(PROG_DEATH, 66, motif=M_DREAD, lead="sine", arp=False, drum="none", sub=True, bars_per_chord=1),
    ]))
    print("done")

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


def _soft_clip(x, drive=1.6):
    """A gentle saturation curve instead of a hard digital clamp. song() already
    peak-normalises under 1.0, so this rarely engages as a safety limiter — it
    acts as warmth across the whole signal instead, which is most of what reads
    as "abrupt and sharp" about a purely dry, hard-clamped mix."""
    return math.tanh(x * drive) / math.tanh(drive)


def _comb(samples, delay, feedback, damp=0.2):
    """One damped feedback delay line -- a single resonance of a room. `delay` is
    a fixed sample count regardless of buffer length, so this stays one O(n) pass
    no matter how long the track is."""
    buf = [0.0] * delay
    out = [0.0] * len(samples)
    damp_state = 0.0
    for i, x in enumerate(samples):
        idx = i % delay
        y = buf[idx]
        damp_state = y * (1.0 - damp) + damp_state * damp
        out[i] = y
        buf[idx] = x + damp_state * feedback
    return out


def _allpass(samples, delay, gain=0.5):
    """A diffuser: smears the combs' periodicity into something that reads as
    space rather than a discrete echo."""
    buf = [0.0] * delay
    out = [0.0] * len(samples)
    for i, x in enumerate(samples):
        idx = i % delay
        fed = buf[idx]
        out[i] = -gain * x + fed
        buf[idx] = x + fed * gain
    return out


def _reverb(samples, wet):
    """A small Freeverb-style tank: four parallel damped combs at classic
    tunings, summed, then two series allpasses. Cheap enough for a ~30s buffer
    (each pass is one O(n) sweep) and the single biggest fix for a dry, harsh
    mix -- it is what turns a bedroom-synth loop into something that reads as a
    space instead of a signal."""
    if wet <= 0.0:
        return samples
    combs = [(1557, 0.84), (1617, 0.83), (1422, 0.85), (1188, 0.82)]
    wet_sig = [0.0] * len(samples)
    for delay, fb in combs:
        for i, v in enumerate(_comb(samples, delay, fb)):
            wet_sig[i] += v / len(combs)
    wet_sig = _allpass(wet_sig, 556, 0.5)
    wet_sig = _allpass(wet_sig, 225, 0.5)
    return [d * (1.0 - wet) + w * wet for d, w in zip(samples, wet_sig)]


def _mix_into(buf, start, samples, gain):
    for i, s in enumerate(samples):
        j = start + i
        if 0 <= j < len(buf):
            buf[j] += s * gain


def _bass_note(freq, dur):
    n = int(dur * RATE)
    out = [_saw(freq, i / RATE) * _adsr(i, n, 0.01, 0.1, 0.8, 0.1) for i in range(n)]
    # This voice was the one place the smoothing pass missed -- raw, unfiltered
    # saw, and it fires every beat of every bar of every track unconditionally.
    # That made it the one thing that never changed no matter what else got
    # layered on: the "same old song" underneath the new richness.
    return _onepole_lp(out, 0.4)


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
    else:
        # Square was the one unfiltered voice -- raw square-wave harmonics are
        # the single biggest source of "buzzy/harsh". A brighter coefficient
        # than saw's so the duty-cycle character still reads.
        out = _onepole_lp(out, 0.4)
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
    elif kind == "square":
        out = _onepole_lp(out, 0.35)
    return out


def _pad_chord(freqs, dur):
    n = int(dur * RATE)
    out = []
    for i in range(n):
        t = i / RATE
        v = sum(math.sin(2 * math.pi * f * t) for f in freqs) / len(freqs)
        out.append(v * _adsr(i, n, 0.4, 0.3, 0.7, 0.6))
    return _onepole_lp(out, 0.08)


def _choir(freqs, dur):
    """A distant choir/vox pad: a detuned unison stack per chord tone, a slow
    swelling attack and a gentle amplitude breathe. Distinct from _pad_chord
    (plain sine, snappier attack) -- this is slower, wider, breathier, for the
    grandeur/haunt Dark-Souls-style boss and dread cues want."""
    n = int(dur * RATE)
    detunes = (-0.006, -0.002, 0.002, 0.006)
    out = []
    for i in range(n):
        t = i / RATE
        swell = 1.0 + 0.08 * math.sin(2 * math.pi * 0.2 * t)
        v = 0.0
        for f in freqs:
            for d in detunes:
                v += math.sin(2 * math.pi * f * (1.0 + d) * t)
        v /= len(freqs) * len(detunes)
        out.append(v * swell * _adsr(i, n, 0.9, 0.6, 0.75, 1.2))
    return _onepole_lp(out, 0.12)


def _bell(freq, dur, ratio=3.5, index0=9.0):
    """A tolling FM bell. A non-integer carrier:modulator ratio gives inharmonic,
    metallic partials on the strike; the modulation index decays fast so the
    tail settles into a clean sine -- clang, then sing. The one instrument this
    file didn't have: a haunting, tolling cue rather than a sustained tone."""
    n = int(dur * RATE)
    fm = freq * ratio
    out = []
    for i in range(n):
        t = i / RATE
        idx = index0 * math.exp(-t * 3.2)
        mod = math.sin(2 * math.pi * fm * t) * idx
        out.append(math.sin(2 * math.pi * freq * t + mod) * math.exp(-t * 1.6))
    return out


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

def _place_melody(buf, motif, beat, kind, gain, octave, harmony=None):
    """Tile a motif across the whole section buffer in the lead voice. `harmony`,
    if set, is a scale-degree offset (e.g. -2 for a third below) sung alongside
    it at reduced gain -- a second voice instead of one lone melodic line."""
    section_beats = len(buf) / RATE / beat
    tpos, idx = 0.0, 0
    while tpos < section_beats - 1e-6:
        degree, beats = motif[idx % len(motif)]
        idx += 1
        if degree is not None:
            f = scale_note(degree, octave)
            start = int(tpos * beat * RATE)
            _mix_into(buf, start, _lead(f, beats * beat * 0.95, kind), gain)
            if harmony is not None:
                hf = scale_note(degree + harmony, octave)
                _mix_into(buf, start, _lead(hf, beats * beat * 0.95, kind), gain * 0.55)
        tpos += beats


def render_section(prog, bpm, motif=None, bars_per_chord=BARS_PER_CHORD,
                   arp=True, lead="square", drum="full", sub=False,
                   melody_kind=None, melody_gain=0.16, melody_octave=2,
                   choir=False, choir_gain=0.22, bell=False, harmony=None):
    """One SECTION: pad + bass + (optional) arp + drums + (optional) melody. Songs
    are built by concatenating contrasting sections. `drum` is 'full'/'kick'/
    'sparse'/'none'; `sub` adds a held sub-bass drone for the dark moods. `choir`
    layers a slow vox pad and `bell` tolls once per chord change -- both off by
    default so existing calls are unaffected; `harmony` sings a second melodic
    voice a scale-degree interval below the lead."""
    beat = 60.0 / bpm
    bar = beat * 4
    total_bars = len(prog) * bars_per_chord
    n = int(total_bars * bar * RATE)
    buf = [0.0] * n
    has_drums = drum != "none"

    kick_beats = {"full": (0, 2), "kick": (0, 2), "sparse": (0,), "none": ()}
    snare_beats = {"full": (1, 3), "kick": (), "sparse": (), "none": ()}
    # The bass pulse used to fire on all 4 beats regardless of mood -- the one
    # thing that never varied between a driving track and a "sparse"/"none"
    # dread or grand section. Tying it to the same density lever the drums
    # already use lets the quiet sections actually go quiet.
    bass_beats = {"full": (0, 1, 2, 3), "kick": (0, 1, 2, 3), "sparse": (0, 2), "none": (0,)}

    for ci, (root, tones) in enumerate(prog):
        chord_start = ci * bars_per_chord * bar
        chord_dur = bars_per_chord * bar
        root_freq = note(root, -1)
        pad_freqs = [note(root + tn, 0) for tn in tones]

        _mix_into(buf, int(chord_start * RATE), _pad_chord(pad_freqs, chord_dur), 0.16)
        if sub:
            _mix_into(buf, int(chord_start * RATE),
                      _pad_chord([note(root, -2)], chord_dur), 0.13)
        if choir:
            _mix_into(buf, int(chord_start * RATE), _choir(pad_freqs, chord_dur), choir_gain)
        if bell:
            _mix_into(buf, int(chord_start * RATE), _bell(note(root, 0), chord_dur), 0.4)

        for bi in range(bars_per_chord):
            bar_start = chord_start + bi * bar
            for bt_i in bass_beats[drum]:
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
        _place_melody(buf, motif, beat, melody_kind or lead, melody_gain, melody_octave, harmony)
    return buf


def song(sections, peak=0.85, crossfade_ms=160, wet=0.22):
    """Concatenate sections into one piece, equal-power crossfading the internal
    verse/chorus seams so they don't click, then reverb + normalise. The
    crossfade only touches INTERNAL boundaries -- the overall buffer still
    starts and ends exactly where the sections put it, so the loop point
    music.gd uses (and the "whole number of bars" tiling that depends on it) is
    unaffected. The contrast BETWEEN sections is what keeps a long loop from
    feeling repetitive; the crossfade just keeps that contrast from clicking."""
    if not sections:
        return []
    buf = list(sections[0])
    nx = int(crossfade_ms / 1000.0 * RATE)
    for nxt in sections[1:]:
        k = min(nx, len(buf) // 4, len(nxt) // 4)
        for i in range(k):
            theta = (i / k) * (math.pi / 2.0)
            buf[len(buf) - k + i] = buf[len(buf) - k + i] * math.cos(theta) + nxt[i] * math.sin(theta)
        buf += nxt[k:]
    buf = _reverb(buf, wet)
    hi = max(1e-6, max(abs(x) for x in buf))
    return [x * (peak / hi) for x in buf]


def sting(sections, wet=0.1):
    """A short, NON-LOOPING cue (extract win, death). Concatenate, then fade the
    last half-second so it lands rather than cuts. Stays drier than the beds
    (low default wet) -- a sting needs to read as immediate, not roomy."""
    buf = song(sections, wet=wet)
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
        w.writeframes(b"".join(struct.pack("<h", int(_soft_clip(s) * 32000)) for s in samples))
    print(f"  {name:<20} {len(samples) / RATE:5.1f}s")


if __name__ == "__main__":
    random.seed(11)
    print("generating music (melodic, sectioned):")

    # Five delve moods, each a two-section piece (verse -> contrasting chorus)
    # with its own melody, timbre and energy. Verse/chorus contrast + a sung line
    # is what fixes the "slow repetitive" read. Choir/bell/harmony are handed out
    # sparingly (never all three on one track) so each mood keeps a distinct
    # identity instead of every track reaching for the same new toys.
    # (a) DRIVING — the main bed: fast, square lead, a climbing hook. Stays the
    # leanest/driest track on purpose, for contrast against the others.
    write("music_delve.wav", song([
        render_section(PROG,   126, motif=M_DRIVE,  lead="square", drum="kick"),
        render_section(PROG_C, 126, motif=M_BRIGHT, lead="square", drum="full", harmony=-2),
    ], wet=0.14))
    # (b) MOODY — slower, saw lead, no arp, sub-bass, choir; a brooding tune
    # carries it, now with a distant vox pad deepening the atmosphere.
    write("music_delve_b.wav", song([
        render_section(PROG_B, 96, motif=M_MOODY, lead="saw", arp=False, drum="kick", sub=True, choir=True),
        render_section(PROG_E, 96, motif=M_DREAD, lead="saw", arp=False, drum="kick", sub=True, choir=True),
    ], wet=0.26))
    # (c) BRIGHT & FAST — most energetic, busy drums, high hook. Kept purest,
    # no new instruments — the contrast to everything else.
    write("music_delve_c.wav", song([
        render_section(PROG_C, 134, motif=M_BRIGHT, lead="square", drum="full"),
        render_section(PROG,   134, motif=M_DRIVE,  lead="square", drum="full"),
    ], wet=0.14))
    # (d) WARM — reedy saw throughout, a lyrical mid-tempo line, now sung with a
    # harmony a third below and a subtle choir bed under it.
    write("music_delve_d.wav", song([
        render_section(PROG_D, 116, motif=M_WARM,  lead="saw", drum="full", choir=True, choir_gain=0.12, harmony=-2),
        render_section(PROG,   116, motif=M_DRIVE, lead="saw", drum="full", choir=True, choir_gain=0.12, harmony=-2),
    ], wet=0.2))
    # (e) DREAD — slow, sine lead, sparse kick, sub, choir AND a tolling bell; a
    # spare, haunting melody. The delve mood closest to the boss-grand palette.
    write("music_delve_e.wav", song([
        render_section(PROG_E, 88, motif=M_DREAD, lead="sine", arp=False, drum="sparse", sub=True, choir=True, bell=True),
        render_section(PROG_B, 88, motif=M_MOODY, lead="sine", arp=False, drum="sparse", sub=True, choir=True, bell=True),
    ], wet=0.3))

    # Hub: calm, no drums, choir swell + a gentle tune. A place to breathe --
    # bell is reserved for haunting cues, not the safe room.
    write("music_hub.wav", song([
        render_section(PROG_D, 82, motif=M_WARM,  lead="sine", drum="none", choir=True),
        render_section(PROG,   82, motif=M_MOODY, lead="sine", drum="none", choir=True),
    ], wet=0.26))
    # Boss: a GRAND movement, then the fight. Dark Souls' shape, not "just
    # faster": a slow, sparse, choir + tolling-bell statement with no drums at
    # all (silence is what sells "weighty" here), crossfading into the existing
    # intense stabbing-motif section -- now with choir/bell carried underneath
    # so the fast half reads as the same piece, not a spliced-in different one.
    write("music_boss.wav", song([
        render_section(PROG_BOSS, 58, motif=M_DREAD, lead="sine", arp=False, drum="none",
                       sub=True, choir=True, bell=True, bars_per_chord=1,
                       melody_gain=0.13, melody_octave=1),
        render_section(PROG_BOSS, 142, motif=M_BOSS, lead="saw", drum="full", sub=True,
                       choir=True, bell=True),
    ], crossfade_ms=260, wet=0.28))
    # Title: slow, dreamy, sub under a choir + bell line — its own place, not
    # the hub, despite sharing chords/motif with it.
    write("music_title.wav", song([
        render_section(PROG_D, 74, motif=M_WARM, lead="sine", drum="none", sub=True, choir=True, bell=True),
        render_section(PROG,   74, motif=M_WARM, lead="sine", drum="none", sub=True, choir=True, bell=True,
                       melody_octave=3),
    ], wet=0.26))

    # One-shot stings. Untouched instrumentation -- these stay punchy/immediate
    # (sting()'s low default wet keeps them dry), not part of the space/richness
    # pass.
    write("music_extract.wav", sting([
        render_section(PROG_EXTRACT, 120, motif=M_BRIGHT, lead="square", drum="full", bars_per_chord=1),
    ]))
    write("music_death.wav", sting([
        render_section(PROG_DEATH, 66, motif=M_DREAD, lead="sine", arp=False, drum="none", sub=True, bars_per_chord=1),
    ]))
    print("done")

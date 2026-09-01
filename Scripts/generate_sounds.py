#!/usr/bin/env python3
"""
generate_sounds.py — synthesizes the app's UI sound set.

The palette mimics a Teenage Engineering OP-1: warm and musical.
Detuned two-layer FM notes (electric-piano and marimba registers)
carry the melodic sounds, rounded pitch-swept kicks the percussive
ones, layered with filtered-noise clicks and hats and finished with
a light sample-and-hold crush for a tape-ish patina. The scrub
detents are pure glass FM taps in the same warm voice, with pitch
and decay jitter baked per variant. Pure stdlib (wave + math), no
dependencies. Writes WAV to a temp dir, then converts to .caf via
afconvert into vivobody/Resources/Sounds/.

Multi-event pattern sounds (crescendo, breath, swell) bake the haptic
event timings into a single file so playback stays in sync with
CHHapticPattern. Rest feedback shares the same palette. The scrub detents
(sfx-scrub-reps/load 1-6) are six seeded variants each so the round-robin
in Sounds.swift never sounds machine-gunned. Ordinary controls, including
RIR choices, use the supplied click recording and are not generated here.
Signature sounds can still come from mastered WAV files in
AudioSources via SOURCE_OVERRIDES (currently unused).

Usage: python3 Scripts/generate_sounds.py
"""

import math
import os
import random
import struct
import subprocess
import tempfile
import wave

SR = 44100
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "vivobody", "Resources", "Sounds")
SOURCE_OVERRIDES = {}


def samples(duration):
    return int(SR * duration)


def pulse_blip(freq, dur, amp, *, width=0.5, width_end=None, freq_end=None,
               attack=0.001, decay_tau=None, lowpass_hz=6000.0):
    """PWM pulse blip: variable-width square, one-pole lowpass, linear
    attack, exponential decay. The chip-toy core of the palette."""
    n = samples(dur)
    out = [0.0] * n
    f0 = freq
    f1 = freq_end if freq_end is not None else freq
    w0 = width
    w1 = width_end if width_end is not None else width
    tau = decay_tau if decay_tau is not None else dur / 4.0
    phase = 0.0
    lp = 0.0
    lp_a = 1.0 - math.exp(-2.0 * math.pi * lowpass_hz / SR)
    for i in range(n):
        t = i / SR
        k = t / dur
        f = f0 * ((f1 / f0) ** k)
        phase += f / SR
        phase -= math.floor(phase)
        w = w0 + (w1 - w0) * k
        v = 1.0 if phase < w else -1.0
        lp += lp_a * (v - lp)
        env = min(1.0, t / attack) if attack > 0 else 1.0
        env *= math.exp(-t / tau)
        out[i] = lp * env * amp
    return out


def fm_blip(freq, dur, amp, *, ratio=2.0, index=2.0, freq_end=None,
            attack=0.001, decay_tau=None, mod_tau=None,
            vibrato_hz=0.0, vibrato_cents=0.0, lowpass_hz=6000.0):
    """Tight 2-operator FM chirp: modulation index decays fast so hits
    open bright and settle warm — the melodic voice."""
    n = samples(dur)
    out = [0.0] * n
    f0 = freq
    f1 = freq_end if freq_end is not None else freq
    tau = decay_tau if decay_tau is not None else dur / 4.0
    mtau = mod_tau if mod_tau is not None else tau * 0.6
    pc = 0.0
    pm = 0.0
    lp = 0.0
    lp_a = 1.0 - math.exp(-2.0 * math.pi * lowpass_hz / SR)
    for i in range(n):
        t = i / SR
        k = t / dur
        f = f0 * ((f1 / f0) ** k)
        if vibrato_hz > 0:
            onset = min(1.0, t / 0.12)
            f *= 2.0 ** (
                vibrato_cents * onset
                * math.sin(2.0 * math.pi * vibrato_hz * t) / 1200.0
            )
        pc += 2.0 * math.pi * f / SR
        pm += 2.0 * math.pi * f * ratio / SR
        s = math.sin(pc + index * math.exp(-t / mtau) * math.sin(pm))
        lp += lp_a * (s - lp)
        env = min(1.0, t / attack) if attack > 0 else 1.0
        env *= math.exp(-t / tau)
        out[i] = lp * env * amp
    return out


def warm_note(freq, dur, amp, *, ratio=1.0, index=1.6, detune=4.0,
              freq_end=None, attack=0.002, decay_tau=None, mod_tau=None,
              vibrato_hz=0.0, vibrato_cents=0.0, lowpass_hz=3500.0):
    """Two FM layers detuned a few cents for chorus warmth — the OP-1
    melodic voice. ratio 1 reads electric-piano, ~3.9 reads marimba."""
    r = 2.0 ** (detune / 1200.0)

    def layer(mult):
        return fm_blip(freq * mult, dur, amp * 0.5, ratio=ratio,
                       index=index,
                       freq_end=freq_end * mult if freq_end is not None else None,
                       attack=attack, decay_tau=decay_tau, mod_tau=mod_tau,
                       vibrato_hz=vibrato_hz, vibrato_cents=vibrato_cents,
                       lowpass_hz=lowpass_hz)

    return [a + b for a, b in zip(layer(r), layer(1.0 / r))]


def kick(f0, f1, dur, amp, *, drive=2.5, attack=0.0005, decay_tau=None,
         sweep_tau=0.03):
    """Drive-saturated pitch-swept sine — the drum-machine punch."""
    n = samples(dur)
    out = [0.0] * n
    tau = decay_tau if decay_tau is not None else dur / 3.0
    phase = 0.0
    for i in range(n):
        t = i / SR
        f = f1 + (f0 - f1) * math.exp(-t / sweep_tau)
        phase += 2.0 * math.pi * f / SR
        s = math.tanh(math.sin(phase) * drive)
        env = min(1.0, t / attack) if attack > 0 else 1.0
        env *= math.exp(-t / tau)
        out[i] = s * env * amp
    return out


def click(amp, dur=0.004, lowpass_hz=3500.0, seed=7):
    """Tiny filtered noise burst — the mechanical 'contact' transient."""
    rng = random.Random(seed)
    n = samples(dur)
    out = [0.0] * n
    lp = 0.0
    lp_a = 1.0 - math.exp(-2.0 * math.pi * lowpass_hz / SR)
    for i in range(n):
        v = rng.uniform(-1.0, 1.0)
        lp += lp_a * (v - lp)
        env = math.exp(-(i / SR) / (dur / 3.0))
        out[i] = lp * env * amp
    return out


def hat(amp, dur=0.025, *, seed=5, hipass_hz=6000.0):
    """Highpassed noise tick — the sparkly top of button presses."""
    rng = random.Random(seed)
    n = samples(dur)
    out = [0.0] * n
    lp = 0.0
    lp_a = 1.0 - math.exp(-2.0 * math.pi * hipass_hz / SR)
    for i in range(n):
        v = rng.uniform(-1.0, 1.0)
        lp += lp_a * (v - lp)
        env = math.exp(-(i / SR) / (dur / 4.0))
        out[i] = (v - lp) * env * amp
    return out


def clap(amp, *, dur=0.12, bursts=3, spacing=0.011, lowpass_hz=3200.0,
         seed=11):
    """Multi-burst noise clap: retriggered attacks into a longer tail."""
    rng = random.Random(seed)
    n = samples(dur)
    out = [0.0] * n
    lp = 0.0
    lp_a = 1.0 - math.exp(-2.0 * math.pi * lowpass_hz / SR)
    for i in range(n):
        t = i / SR
        b = min(int(t / spacing), bursts - 1)
        if b < bursts - 1:
            env = math.exp(-(t - b * spacing) / 0.004)
        else:
            env = math.exp(-(t - (bursts - 1) * spacing) / 0.035)
        v = rng.uniform(-1.0, 1.0)
        lp += lp_a * (v - lp)
        out[i] = lp * env * amp
    return out


def bitcrush(data, bits=12, downsample=3):
    """Sample-and-hold decimation + bit quantization — the sampler grit
    that ties every sound to the same lo-fi box."""
    levels = float(2 ** (bits - 1))
    out = [0.0] * len(data)
    held = 0.0
    for i, v in enumerate(data):
        if i % downsample == 0:
            held = math.floor(max(-1.0, min(1.0, v)) * levels) / levels
        out[i] = held
    return out


def place(canvas, event, at):
    start = samples(at)
    need = start + len(event)
    if need > len(canvas):
        canvas.extend([0.0] * (need - len(canvas)))
    for i, v in enumerate(event):
        canvas[start + i] += v
    return canvas


def finalize(canvas, tail=0.03):
    # Fade the actual signal before appending digital silence. Fading after
    # padding only multiplies zeros and leaves a discontinuity at the cut.
    fade = min(samples(0.005), len(canvas))
    for i in range(fade):
        canvas[-fade + i] *= 1.0 - ((i + 1) / fade)
    canvas = canvas + [0.0] * samples(tail)
    peak = max(abs(v) for v in canvas) or 1.0
    if peak > 0.98:
        canvas = [v * 0.98 / peak for v in canvas]
    return canvas


def scrub_detent(variant, *, deep):
    """One detent variant in the same warm voice as the buttons: pure
    glass taps, no noise click at all, just a small FM tone with a
    soft octave shimmer that fades rather than cuts — elegant over
    mechanical. Load speaks the same voice an octave below reps with
    more body and a darker top, matching its bigger numeral. Per-
    variant seeds bake in the pitch and decay jitter that Sounds.swift
    deliberately doesn't add at playback."""
    rng = random.Random((200 if deep else 100) + variant)
    tune = 2.0 ** (rng.uniform(-15.0, 15.0) / 1200.0)
    if deep:
        c = place([], fm_blip(660 * tune, 0.040, 0.18, ratio=2.0,
                              index=0.6, freq_end=640 * tune,
                              mod_tau=0.005, attack=0.0010,
                              decay_tau=rng.uniform(0.009, 0.012),
                              lowpass_hz=3200), 0.0)
    else:
        c = place([], fm_blip(1320 * tune, 0.028, 0.12, ratio=2.0,
                              index=0.5, freq_end=1280 * tune,
                              mod_tau=0.004, attack=0.0008,
                              decay_tau=rng.uniform(0.006, 0.008),
                              lowpass_hz=4800), 0.0)
    return finalize(bitcrush(c, downsample=2), tail=0.02)


def build_all():
    sounds = {}

    # crescendo — three ascending marimba notes (G4 C5 E5) at the
    # haptic pattern's exact timings (0.00 / 0.10 / 0.22) and matching
    # intensity ramp.
    c = place([], warm_note(392, 0.060, 0.13, ratio=3.9, index=1.1,
                            decay_tau=0.018, lowpass_hz=3600), 0.00)
    c = place(c, warm_note(523, 0.070, 0.22, ratio=3.9, index=1.1,
                           decay_tau=0.022, lowpass_hz=4000), 0.10)
    c = place(c, hat(0.05, dur=0.012, seed=24), 0.22)
    c = place(c, warm_note(659, 0.120, 0.34, ratio=3.9, index=1.2,
                           decay_tau=0.036, lowpass_hz=4400), 0.22)
    sounds["sfx-crescendo"] = finalize(bitcrush(c, downsample=2))

    # breath — two soft low pulses at the haptic timings (0.00 / 0.18).
    # Stays gentle: low FM, slow attack, only a whisper of crush.
    c = place([], fm_blip(330, 0.080, 0.11, ratio=1.0, index=0.3,
                          attack=0.012, decay_tau=0.026,
                          lowpass_hz=1500), 0.00)
    c = place(c, fm_blip(330, 0.080, 0.11, ratio=1.0, index=0.3,
                         attack=0.012, decay_tau=0.026,
                         lowpass_hz=1500), 0.18)
    sounds["sfx-breath"] = finalize(bitcrush(c, downsample=2))

    # swell — the haptic's 350ms build rendered as a fast pentatonic
    # run-up (C4 D4 E4 G4 A4) instead of a drone, then the hit at 0.38
    # (haptic-matched) lands on C4+G4+C5 under a rounded kick. Same
    # key as slam, so the PR sequence (swell entrance, slam landing)
    # reads as one musical phrase.
    c = []
    for freq, at, amp in [(262, 0.00, 0.10), (294, 0.07, 0.13),
                          (330, 0.14, 0.16), (392, 0.21, 0.19),
                          (440, 0.28, 0.22)]:
        c = place(c, warm_note(freq, 0.070, amp, decay_tau=0.020,
                               lowpass_hz=3400), at)
    c = place(c, click(0.18, dur=0.006), 0.38)
    c = place(c, kick(400, 65, 0.150, 0.45, sweep_tau=0.020,
                      decay_tau=0.045, drive=2.2), 0.38)
    c = place(c, warm_note(262, 0.220, 0.16, index=1.4,
                           decay_tau=0.065, lowpass_hz=2400), 0.38)
    c = place(c, warm_note(392, 0.200, 0.14, index=1.3,
                           decay_tau=0.060, lowpass_hz=2800), 0.38)
    c = place(c, warm_note(523, 0.200, 0.14, index=1.2,
                           decay_tau=0.060, lowpass_hz=3200), 0.38)
    sounds["sfx-swell"] = finalize(bitcrush(c, downsample=2))

    # rest-done — lock-screen notification chime ("rest over, lift").
    # An OP-1 boot-jingle style EP arpeggio (C5 E5 G5) swinging into a
    # held C6 with tape-wobble vibrato; longer and louder than the
    # in-app blips because it has to read from a pocket, but the same
    # warm voice as success so the identity carries through.
    c = place([], warm_note(523, 0.100, 0.30, decay_tau=0.032,
                            lowpass_hz=4200), 0.00)
    c = place(c, warm_note(659, 0.100, 0.32, decay_tau=0.032,
                           lowpass_hz=4200), 0.10)
    c = place(c, warm_note(784, 0.100, 0.34, decay_tau=0.032,
                           lowpass_hz=4200), 0.20)
    c = place(c, hat(0.06, dur=0.014, seed=34), 0.32)
    c = place(c, warm_note(1046, 0.420, 0.42, index=1.8, attack=0.004,
                           decay_tau=0.130, vibrato_hz=5.5,
                           vibrato_cents=14.0, lowpass_hz=4800), 0.32)
    sounds["sfx-rest-done"] = finalize(bitcrush(c, downsample=2))

    # scrub detents — six seeded variants per register for round-robin.
    for variant in range(1, 7):
        sounds[f"sfx-scrub-reps-{variant}"] = scrub_detent(variant, deep=False)
        sounds[f"sfx-scrub-load-{variant}"] = scrub_detent(variant, deep=True)

    return sounds


def write_wav(path, data):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, v)) * 32767)) for v in data
        )
        w.writeframes(frames)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    sounds = build_all()
    with tempfile.TemporaryDirectory() as tmp:
        for name, data in sounds.items():
            if name in SOURCE_OVERRIDES:
                continue
            wav_path = os.path.join(tmp, f"{name}.wav")
            caf_path = os.path.abspath(os.path.join(OUT_DIR, f"{name}.caf"))
            write_wav(wav_path, data)
            subprocess.run(
                ["afconvert", "-f", "caff", "-d", "LEI16", wav_path, caf_path],
                check=True,
            )
            dur_ms = len(data) / SR * 1000
            print(f"{name}.caf  ({dur_ms:.0f} ms)")

        for name, source_path in SOURCE_OVERRIDES.items():
            caf_path = os.path.abspath(os.path.join(OUT_DIR, f"{name}.caf"))
            subprocess.run(
                ["afconvert", "-f", "caff", "-d", f"LEI16@{SR}", source_path, caf_path],
                check=True,
            )
            with wave.open(source_path, "rb") as source:
                dur_ms = source.getnframes() / source.getframerate() * 1000
            print(f"{name}.caf  ({dur_ms:.0f} ms, AudioSources override)")
    print(f"\nWrote {len(sounds)} sounds to {os.path.abspath(OUT_DIR)}")


if __name__ == "__main__":
    main()

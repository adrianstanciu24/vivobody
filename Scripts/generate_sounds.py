#!/usr/bin/env python3
"""
generate_sounds.py — synthesizes the app's UI sound set.

Teenage-Engineering-style palette: short sine/square blips with fast
exponential decays, subtle pitch drops, and clicky transients. Pure
stdlib (wave + math), no dependencies. Writes WAV to a temp dir, then
converts to .caf via afconvert into vivobody/Resources/Sounds/.

Each sound maps 1:1 to a Haptics atom or pattern; multi-event pattern
sounds (crescendo, breath, swell) bake the haptic event timings into
a single file so playback stays in sync with CHHapticPattern.

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


def samples(duration):
    return int(SR * duration)


def blip(freq, dur, amp, *, freq_end=None, attack=0.002, decay_tau=None,
         square=0.35, lowpass_hz=5000.0):
    """One synth blip: sine core + soft-clipped square blend, one-pole
    lowpass, linear attack, exponential decay. Returns list of floats."""
    n = samples(dur)
    out = [0.0] * n
    f0 = freq
    f1 = freq_end if freq_end is not None else freq
    tau = decay_tau if decay_tau is not None else dur / 4.0
    phase = 0.0
    lp = 0.0
    lp_a = 1.0 - math.exp(-2.0 * math.pi * lowpass_hz / SR)
    for i in range(n):
        t = i / SR
        # exponential frequency glide from f0 to f1
        k = t / dur
        f = f0 * ((f1 / f0) ** k) if f0 > 0 else f1
        phase += 2.0 * math.pi * f / SR
        s = math.sin(phase)
        # soft square: heavily clipped sine adds TE-ish odd harmonics
        sq = max(-1.0, min(1.0, s * 8.0))
        v = (1.0 - square) * s + square * sq
        lp += lp_a * (v - lp)
        env = min(1.0, t / attack) if attack > 0 else 1.0
        env *= math.exp(-t / tau)
        out[i] = lp * env * amp
    return out


def click(amp, dur=0.004, lowpass_hz=3500.0):
    """Tiny filtered noise burst — the mechanical 'contact' transient."""
    rng = random.Random(7)
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


def place(canvas, event, at):
    start = samples(at)
    need = start + len(event)
    if need > len(canvas):
        canvas.extend([0.0] * (need - len(canvas)))
    for i, v in enumerate(event):
        canvas[start + i] += v
    return canvas


def finalize(canvas, tail=0.03):
    canvas = canvas + [0.0] * samples(tail)
    fade = samples(0.005)
    for i in range(fade):
        canvas[-fade + i] *= 1.0 - (i / fade)
    peak = max(abs(v) for v in canvas) or 1.0
    if peak > 0.98:
        canvas = [v * 0.98 / peak for v in canvas]
    return canvas


def swell_body(dur, f0, f1, amp):
    """Rising tone with a volume ramp — the audio twin of the haptic swell."""
    n = samples(dur)
    out = [0.0] * n
    phase = 0.0
    lp = 0.0
    lp_a = 1.0 - math.exp(-2.0 * math.pi * 2500.0 / SR)
    for i in range(n):
        t = i / SR
        k = t / dur
        f = f0 * ((f1 / f0) ** k)
        phase += 2.0 * math.pi * f / SR
        s = math.sin(phase) + 0.2 * math.sin(2.0 * phase)
        lp += lp_a * (s - lp)
        ramp = 0.35 + 0.65 * k
        edge = min(1.0, t / 0.01) * min(1.0, (dur - t) / 0.02)
        out[i] = lp * ramp * edge * amp
    return out


def build_all():
    sounds = {}

    # tick — encoder detent. High, tiny, mostly click.
    c = place([], click(0.10), 0.0)
    c = place(c, blip(1900, 0.025, 0.16, freq_end=1700, decay_tau=0.006,
                      square=0.5, lowpass_hz=6500), 0.0)
    sounds["sfx-tick"] = finalize(c)

    # tick-deep — the load scrubber's detent. An octave below tick
    # with more body and a duller click, so weight reads as "heavy
    # thing moving" while reps keep the light encoder tick. The same
    # ±600-cent drag tracking rides on top of this lower base.
    c = place([], click(0.10, lowpass_hz=2200), 0.0)
    c = place(c, blip(950, 0.040, 0.22, freq_end=820, decay_tau=0.011,
                      square=0.45, lowpass_hz=3000), 0.0)
    sounds["sfx-tick-deep"] = finalize(c)

    # selection — even smaller sibling of tick, for wheel rolls.
    c = place([], blip(2300, 0.018, 0.10, freq_end=2100, decay_tau=0.005,
                       square=0.4, lowpass_hz=7000), 0.0)
    sounds["sfx-selection"] = finalize(c)

    # soft — gentle low blip, ambient confirmation.
    c = place([], blip(440, 0.070, 0.14, attack=0.006, decay_tau=0.022,
                       square=0.15, lowpass_hz=2200), 0.0)
    sounds["sfx-soft"] = finalize(c)

    # thunk — the workhorse. Mid thud with pitch drop + contact click.
    c = place([], click(0.12), 0.0)
    c = place(c, blip(340, 0.080, 0.34, freq_end=210, decay_tau=0.024,
                      square=0.25, lowpass_hz=1800), 0.0)
    sounds["sfx-thunk"] = finalize(c)

    # rigid — dull hard stop. Click-forward, damped, unmusical.
    c = place([], click(0.20, dur=0.005, lowpass_hz=2800), 0.0)
    c = place(c, blip(820, 0.028, 0.16, freq_end=760, decay_tau=0.007,
                      square=0.2, lowpass_hz=1600), 0.0)
    sounds["sfx-rigid"] = finalize(c)

    # slam — PR hit. Deep pitch-drop thud with a hard transient.
    c = place([], click(0.25, dur=0.006), 0.0)
    c = place(c, blip(230, 0.160, 0.55, freq_end=75, decay_tau=0.050,
                      square=0.2, lowpass_hz=1400), 0.0)
    sounds["sfx-slam"] = finalize(c)

    # success — two rising blips (perfect fifth), bright but polite.
    c = place([], blip(660, 0.060, 0.22, decay_tau=0.020, square=0.4,
                       lowpass_hz=4500), 0.0)
    c = place(c, blip(990, 0.090, 0.26, decay_tau=0.028, square=0.4,
                      lowpass_hz=4500), 0.09)
    sounds["sfx-success"] = finalize(c)

    # warning — two even blips, same pitch. Neutral heads-up.
    for name, f in (("sfx-warning", 550),):
        c = place([], blip(f, 0.055, 0.22, decay_tau=0.018, square=0.35,
                           lowpass_hz=3500), 0.0)
        c = place(c, blip(f, 0.055, 0.22, decay_tau=0.018, square=0.35,
                          lowpass_hz=3500), 0.12)
        sounds[name] = finalize(c)

    # failure — descending pair, duller and lower.
    c = place([], blip(440, 0.070, 0.24, decay_tau=0.022, square=0.25,
                       lowpass_hz=2500), 0.0)
    c = place(c, blip(311, 0.110, 0.26, freq_end=290, decay_tau=0.034,
                      square=0.25, lowpass_hz=2200), 0.10)
    sounds["sfx-failure"] = finalize(c)

    # crescendo — three ascending blips at the haptic pattern's exact
    # timings (0.00 / 0.10 / 0.22) and matching intensity ramp.
    c = place([], blip(523, 0.050, 0.12, decay_tau=0.016, square=0.35,
                       lowpass_hz=3800), 0.00)
    c = place(c, blip(659, 0.055, 0.22, decay_tau=0.018, square=0.40,
                      lowpass_hz=4200), 0.10)
    c = place(c, blip(880, 0.090, 0.34, decay_tau=0.028, square=0.45,
                      lowpass_hz=4800), 0.22)
    sounds["sfx-crescendo"] = finalize(c)

    # breath — two soft low pulses at the haptic timings (0.00 / 0.18).
    c = place([], blip(330, 0.080, 0.11, attack=0.010, decay_tau=0.026,
                       square=0.1, lowpass_hz=1600), 0.00)
    c = place(c, blip(330, 0.080, 0.11, attack=0.010, decay_tau=0.026,
                      square=0.1, lowpass_hz=1600), 0.18)
    sounds["sfx-breath"] = finalize(c)

    # swell — 350ms rising tone, then the slam hit at 0.38 (haptic-matched).
    c = place([], swell_body(0.35, 130, 260, 0.30), 0.0)
    c = place(c, click(0.22, dur=0.006), 0.38)
    c = place(c, blip(220, 0.150, 0.50, freq_end=80, decay_tau=0.045,
                      square=0.2, lowpass_hz=1400), 0.38)
    sounds["sfx-swell"] = finalize(c)

    # rest-done — lock-screen notification chime ("rest over, lift").
    # Rising major triad into a held octave; longer and louder than the
    # in-app blips because it has to read from a pocket, but still the
    # same synth voice so the identity carries through.
    c = place([], blip(523, 0.090, 0.30, decay_tau=0.030, square=0.35,
                       lowpass_hz=4200), 0.00)
    c = place(c, blip(659, 0.090, 0.32, decay_tau=0.030, square=0.35,
                      lowpass_hz=4200), 0.12)
    c = place(c, blip(784, 0.090, 0.34, decay_tau=0.030, square=0.35,
                      lowpass_hz=4200), 0.24)
    c = place(c, blip(1046, 0.360, 0.42, attack=0.004, decay_tau=0.110,
                      square=0.30, lowpass_hz=5000), 0.40)
    sounds["sfx-rest-done"] = finalize(c)

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
            wav_path = os.path.join(tmp, f"{name}.wav")
            caf_path = os.path.abspath(os.path.join(OUT_DIR, f"{name}.caf"))
            write_wav(wav_path, data)
            subprocess.run(
                ["afconvert", "-f", "caff", "-d", "LEI16", wav_path, caf_path],
                check=True,
            )
            dur_ms = len(data) / SR * 1000
            print(f"{name}.caf  ({dur_ms:.0f} ms)")
    print(f"\nWrote {len(sounds)} sounds to {os.path.abspath(OUT_DIR)}")


if __name__ == "__main__":
    main()

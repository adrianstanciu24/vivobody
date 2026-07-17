#!/usr/bin/env python3
"""
Split Kenney's one-second scroll loops into scrubber one-shots.

scroll_001 supplies standard/reps detents; scroll_003 supplies deeper
load/weight detents. Each source contains one click every 50 ms. We
locate the strongest contact in six consecutive periods, retain 42 ms,
add sub-millisecond edge fades, and export mono 44.1 kHz PCM CAF files.

Usage:
    python3 Scripts/extract_scroll_ticks.py
"""

import os
import struct
import subprocess
import tempfile
import wave


SCRIPT_DIR = os.path.dirname(__file__)
SOURCES = (
    ("reps", os.path.join(SCRIPT_DIR, "AudioSources", "scroll_001.ogg")),
    ("load", os.path.join(SCRIPT_DIR, "AudioSources", "scroll_003.ogg")),
)
OUT_DIR = os.path.abspath(
    os.path.join(SCRIPT_DIR, "..", "vivobody", "Resources", "Sounds")
)
SAMPLE_RATE = 44_100
VARIANT_COUNT = 6


def read_wav(path: str) -> list[float]:
    with wave.open(path, "rb") as wav:
        if wav.getnchannels() != 1 or wav.getsampwidth() != 2:
            raise ValueError("Expected mono 16-bit PCM")
        frames = wav.getnframes()
        values = struct.unpack(f"<{frames}h", wav.readframes(frames))
    return [value / 32_768.0 for value in values]


def write_wav(path: str, samples: list[float]) -> None:
    with wave.open(path, "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(SAMPLE_RATE)
        wav.writeframes(
            b"".join(
                struct.pack("<h", round(max(-1.0, min(1.0, value)) * 32_767))
                for value in samples
            )
        )


def extract_click(signal: list[float], period: int) -> list[float]:
    period_start = round(period * 0.050 * SAMPLE_RATE)
    period_end = round((period + 1) * 0.050 * SAMPLE_RATE)

    # The loop's clicks sit near the end of each 50 ms period. Find
    # the largest sample-to-sample change so every slice starts on its
    # actual contact rather than relying on a hard-coded timestamp.
    search = signal[period_start:period_end]
    local_onset = max(
        range(1, len(search)),
        key=lambda index: abs(search[index] - search[index - 1]),
    )
    onset = period_start + local_onset

    pre_roll = round(0.0008 * SAMPLE_RATE)
    duration = round(0.042 * SAMPLE_RATE)
    start = max(0, onset - pre_roll)
    click = signal[start : start + duration]
    if len(click) < duration:
        click.extend([0.0] * (duration - len(click)))

    attack = max(1, round(0.0003 * SAMPLE_RATE))
    release = max(1, round(0.004 * SAMPLE_RATE))
    for index in range(attack):
        click[index] *= index / attack
    for index in range(release):
        click[-release + index] *= 1.0 - index / release
    return click


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    with tempfile.TemporaryDirectory() as temporary:
        for role, source in SOURCES:
            decoded = os.path.join(temporary, f"scroll-{role}.wav")
            subprocess.run(
                [
                    "afconvert",
                    "-f",
                    "WAVE",
                    "-d",
                    "LEI16@44100",
                    "-c",
                    "1",
                    source,
                    decoded,
                ],
                check=True,
            )
            signal = read_wav(decoded)

            for variant in range(1, VARIANT_COUNT + 1):
                samples = extract_click(signal, variant - 1)
                name = f"sfx-scrub-{role}-{variant}"
                wav_path = os.path.join(temporary, f"{name}.wav")
                caf_path = os.path.join(OUT_DIR, f"{name}.caf")
                write_wav(wav_path, samples)
                subprocess.run(
                    [
                        "afconvert",
                        "-f",
                        "caff",
                        "-d",
                        "LEI16@44100",
                        wav_path,
                        caf_path,
                    ],
                    check=True,
                )
                print(f"{name}.caf ({len(samples) / SAMPLE_RATE * 1_000:.0f} ms)")


if __name__ == "__main__":
    main()

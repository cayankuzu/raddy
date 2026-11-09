"""Bakes a stone hitting a windshield (assets/audio/car/stone_glass_N.wav): the sharp tick of the hit and the short high ring of the
pane, a few variants, nothing recorded. Pure Python (Smart App Control blocks numpy here).
Usage: python tools/make_stone_sounds.py
"""
import math
import os
import random
import struct
import wave

RATE = 44100
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "audio", "car")
# Hz and decay (s) of the ring of the pane; each variant moves them a little.
MODES = [(2350.0, 0.024), (3920.0, 0.016), (6180.0, 0.009), (8740.0, 0.006), (11300.0, 0.004)]
SECONDS = 0.11
PEAK = 0.85


def stone(seed: int) -> list:
    rng = random.Random(seed)
    modes = [(hz * rng.uniform(0.9, 1.12), decay * rng.uniform(0.8, 1.25), rng.uniform(0.5, 1.0), rng.uniform(0.0, math.tau)) for hz, decay in MODES]
    samples = []
    for i in range(int(SECONDS * RATE)):
        t = i / RATE
        ring = sum(gain * math.exp(-t / decay) * math.sin(math.tau * hz * t + phase) for hz, decay, gain, phase in modes)
        tick = rng.uniform(-1.0, 1.0) * math.exp(-t / 0.0011) * 2.2
        # A dull knock of the whole pane under the tick.
        body = 0.5 * math.exp(-t / 0.02) * math.sin(math.tau * 640.0 * t)
        samples.append(ring + tick + body)
    # A hard start: no fade in, the end faded out so it cannot click.
    fade = int(0.01 * RATE)
    for i in range(fade):
        samples[-1 - i] *= i / fade
    most = max(abs(s) for s in samples)
    return [s / most * PEAK for s in samples]


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    for n in range(3):
        path = os.path.join(OUT, f"stone_glass_{n}.wav")
        with wave.open(path, "wb") as file:
            file.setnchannels(1)
            file.setsampwidth(2)
            file.setframerate(RATE)
            file.writeframes(b"".join(struct.pack("<h", int(s * 32767)) for s in stone(50 + n)))
        print("wrote", path)


main()

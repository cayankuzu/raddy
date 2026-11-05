"""Synthesises the exhaust's pops on overrun (pure Python, no downloads, deterministic):
assets/audio/car/exhaust_pop_{0,1,2}.wav - a short low thump with a crack of noise on its front (about 0.15 s)
Run from the repo root: python tools/make_exhaust_pops.py
"""
import math
import os
import random
import struct
import wave

RATE = 44100


def write(path, samples):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    peak = max(1e-9, max(abs(s) for s in samples))
    scale = 0.89 / peak  # about -1 dBFS
    with wave.open(path, 'wb') as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(b''.join(struct.pack('<h', int(max(-1.0, min(1.0, s * scale)) * 32767)) for s in samples))


def pop(seed, thump_hz, seconds=0.16):
    rng = random.Random(seed)
    n = int(seconds * RATE)
    out = [0.0] * n
    low = 0.0
    phase = 0.0
    for i in range(n):
        t = i / RATE
        # The thump falls in pitch as the gas burns out in the pipe.
        phase += (thump_hz * (1.0 + 1.5 * math.exp(-t * 70.0))) / RATE
        thump = math.sin(phase * math.tau) * math.exp(-t * 38.0)
        # The crack: noise on the very front, smoothed a little so it is a bark, not a click.
        noise = rng.uniform(-1.0, 1.0)
        low += (noise - low) * 0.35
        crack = low * math.exp(-t * 170.0) * 1.1
        # A rattle in the pipe after it.
        rattle = rng.uniform(-1.0, 1.0) * math.exp(-t * 48.0) * 0.16 * (0.6 + 0.4 * math.sin(t * 760.0))
        attack = min(1.0, i / (RATE * 0.0008))
        out[i] = (thump + crack + rattle) * attack
    return out


def main():
    for i, hz in enumerate([92.0, 118.0, 74.0]):
        write('assets/audio/car/exhaust_pop_%d.wav' % i, pop(31 + i, hz))


if __name__ == '__main__':
    main()

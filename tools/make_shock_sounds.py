"""Synthesises the shock gun's sounds (pure Python, no downloads, deterministic):
assets/audio/shock/zap.wav  - the electric crackle on the target (1.1 s)
assets/audio/shock/fire.wav - the cartridge pop and the wires whipping out (0.3 s)
Run from the repo root: python tools/make_shock_sounds.py
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


def zap(seconds=1.1, seed=7):
    rng = random.Random(seed)
    n = int(seconds * RATE)
    out = [0.0] * n
    # A buzzing arc: a harsh pulse train around 60-90 Hz with jitter, gated by crackle bursts.
    phase = 0.0
    burst_left = 0
    burst_gain = 0.0
    last_noise = 0.0
    for i in range(n):
        t = i / RATE
        freq = 72.0 + 18.0 * math.sin(t * 9.0) + rng.uniform(-6.0, 6.0)
        phase += freq / RATE
        pulse = 1.0 if (phase % 1.0) < 0.18 else -0.25
        if burst_left <= 0:
            burst_left = rng.randint(int(0.004 * RATE), int(0.03 * RATE))
            burst_gain = rng.choice([0.0, 0.3, 0.7, 1.0, 1.0])
        burst_left -= 1
        noise = rng.uniform(-1.0, 1.0)
        hiss = noise - last_noise  # crude high-pass: the snap of the arc
        last_noise = noise
        attack = min(1.0, t / 0.008)
        release = min(1.0, (seconds - t) / 0.18)
        env = attack * max(0.0, release)
        out[i] = env * (0.55 * pulse * (0.4 + 0.6 * burst_gain) + 0.5 * hiss * burst_gain)
    return out


def fire(seconds=0.3, seed=11):
    rng = random.Random(seed)
    n = int(seconds * RATE)
    out = [0.0] * n
    phase = 0.0
    for i in range(n):
        t = i / RATE
        pop = rng.uniform(-1.0, 1.0) * math.exp(-t / 0.006)
        freq = 2600.0 * math.exp(-t / 0.05) + 500.0
        phase += freq / RATE
        whip = math.sin(phase * 2.0 * math.pi) * math.exp(-t / 0.07) * 0.5
        rattle = rng.uniform(-1.0, 1.0) * 0.15 * math.exp(-t / 0.12)
        out[i] = pop + whip + rattle
    return out


if __name__ == '__main__':
    write('assets/audio/shock/zap.wav', zap())
    write('assets/audio/shock/fire.wav', fire())
    print('wrote assets/audio/shock/zap.wav and fire.wav')

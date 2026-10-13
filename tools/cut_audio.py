"""Turns the approved raw recordings in raw_assets/audio/ (tools/fetch_audio.py) into the small
loops and one-shots in assets/audio/ that ship with the game, and synthesises the few sounds no
recording covers (gravel under the tyres, wind, water). Mono 16-bit 48 kHz WAV; loops carry a
"smpl" chunk so Godot's importer loops them seamlessly. Deterministic (fixed random seeds).

  python -I tools/cut_audio.py

Engine loops come from the Sonniss "Toyota Corolla 1998 rally car" onboard exhaust recording:
steady stretches at three engine speeds, pitch-flattened (the recording's own firing frequency,
measured by autocorrelation, is resampled to a constant) and cross-faded into seamless loops.
Their firing frequencies are written to assets/audio/engine/loops.json for CarAudio (a
four-cylinder four-stroke fires twice per revolution: f0 = rpm / 30).
numpy's FFT module is blocked by Smart App Control on the dev PC, so nothing here uses it.
"""
import json
import os
import shutil
import struct
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "raw_assets", "audio")
OUT = os.path.join(ROOT, "assets", "audio")
RATE = 48000
TOYOTA = os.path.join(RAW, "sonniss", "Toyota Rally Car, t9, Onbrd, Fast, Drive, Various, Exhaust, Center, DPA4062.wav")
HORN = os.path.join(RAW, "sonniss", "Toyota Rally Car, t11, Var SFX, Horn, Various, Interior, AMBEO2.wav")
SKIDS = os.path.join(RAW, "sonniss", "Skids_Tarmac_t4_exterior_skidding_in_circles_MKH8060_stand.wav")
CRASHES = os.path.join(RAW, "sonniss", "Car_Destruction_Designed_t44_Impacts_Interor.wav")


# --- reading and writing ---

def read_wav(path):
    """Mono float32 at RATE from a 16- or 24-bit PCM WAV (96 kHz sources are halved)."""
    w = wave.open(path, "rb")
    n, ch, width, rate = w.getnframes(), w.getnchannels(), w.getsampwidth(), w.getframerate()
    raw = w.readframes(n)
    if width == 3:
        b = np.frombuffer(raw, dtype=np.uint8).reshape(-1, 3)
        data = b[:, 0].astype(np.int32) | (b[:, 1].astype(np.int32) << 8) | (b[:, 2].astype(np.int32) << 16)
        data = np.where(data & 0x800000, data - 0x1000000, data).astype(np.float32) / 8388608.0
    elif width == 2:
        data = np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768.0
    else:
        raise ValueError(f"{path}: {width * 8}-bit is not handled")
    data = data.reshape(-1, ch).mean(axis=1)
    if rate == 2 * RATE:
        # Averaging pairs is a gentle low-pass with a zero at the new Nyquist: enough here.
        data = data[: len(data) // 2 * 2].reshape(-1, 2).mean(axis=1)
    elif rate != RATE:
        raise ValueError(f"{path}: {rate} Hz is not handled")
    return data.astype(np.float32)


def write_wav(name, x, loop=False):
    """16-bit mono WAV under assets/audio; a loop gets a smpl chunk spanning the whole file."""
    path = os.path.join(OUT, name)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    pcm = (np.clip(x, -1.0, 1.0) * 32767.0).astype("<i2").tobytes()
    chunks = [b"fmt " + struct.pack("<IHHIIHH", 16, 1, 1, RATE, RATE * 2, 2, 16),
              b"data" + struct.pack("<I", len(pcm)) + pcm]
    if loop:
        smpl = struct.pack("<9I", 0, 0, int(1e9 / RATE), 60, 0, 0, 0, 1, 0)
        smpl += struct.pack("<6I", 0, 0, 0, len(x) - 1, 0, 0)
        chunks.insert(1, b"smpl" + struct.pack("<I", len(smpl)) + smpl)
    body = b"WAVE" + b"".join(chunks)
    with open(path, "wb") as f:
        f.write(b"RIFF" + struct.pack("<I", len(body)) + body)
    print(f"{name}: {len(x) / RATE:.2f} s{' loop' if loop else ''}")


def copy(src, name):
    dst = os.path.join(OUT, name)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copyfile(src, dst)
    print(f"{name}: copied")


# --- signal helpers (no FFT) ---

def lowpass(x, cutoff, rate=RATE):
    """Two cascaded one-pole low-pass filters. A plain Python loop: only a few seconds of
    synthesised audio go through it."""
    a = float(np.exp(-2.0 * np.pi * cutoff / rate))
    data = x.tolist()
    for _ in range(2):
        acc = 0.0
        for i, v in enumerate(data):
            acc = (1.0 - a) * v + a * acc
            data[i] = acc
    return np.array(data, dtype=np.float32)


def highpass(x, cutoff, rate=RATE):
    return x - lowpass(x, cutoff, rate)


def normalize(x, peak=0.89):
    m = float(np.max(np.abs(x))) or 1.0
    return x * (peak / m)


def fade(x, fade_in=0.005, fade_out=0.05):
    x = x.copy()
    i = int(fade_in * RATE)
    o = int(fade_out * RATE)
    if i:
        x[:i] *= np.linspace(0.0, 1.0, i)
    if o:
        x[-o:] *= np.linspace(1.0, 0.0, o) ** 2
    return x


def loop(x, crossfade):
    """Makes `x` loop seamlessly: its tail (crossfade seconds) is blended into its head."""
    n = int(crossfade * RATE)
    body = x[:-n].copy()
    t = np.linspace(0.0, 1.0, n)
    body[:n] = body[:n] * np.sqrt(t) + x[-n:] * np.sqrt(1.0 - t)
    return body


def cut(x, start, end):
    return x[int(start * RATE):int(end * RATE)]


def f0_track(x, hop=0.02, win=0.08, lo=35.0, hi=330.0):
    """Engine firing frequency every `hop` seconds (autocorrelation on a 4 kHz copy)."""
    factor = 12
    y = x[: len(x) // factor * factor].reshape(-1, factor).mean(axis=1)
    r = RATE / factor
    y = y - np.convolve(y, np.ones(64) / 64, mode="same")
    n = int(win * r)
    h = int(hop * r)
    lags = np.arange(int(r / hi), int(r / lo) + 1)
    out = []
    for start in range(0, len(y) - n, h):
        seg = y[start:start + n]
        energy = float(np.dot(seg, seg)) + 1e-12
        ac = np.array([np.dot(seg[:-lag], seg[lag:]) for lag in lags]) / energy
        best = int(np.argmax(ac))
        for i in range(1, len(ac) - 1):
            if ac[i] > 0.85 * ac[best] and ac[i] >= ac[i - 1] and ac[i] >= ac[i + 1]:
                best = i
                break
        out.append(r / lags[best])
    return np.array(out), hop


def flatten_pitch(x, target):
    """Resamples `x` so its firing frequency stays at `target` Hz (a steady-rpm loop)."""
    track, hop = f0_track(x)
    track = np.convolve(track, np.ones(5) / 5, mode="same")
    out = []
    pos = 0.0
    while pos < len(x) - 2:
        f0 = track[min(int(pos / RATE / hop), len(track) - 1)]
        i = int(pos)
        frac = pos - i
        out.append(x[i] * (1.0 - frac) + x[i + 1] * frac)
        pos += target / f0  # read slower where the recording is higher than the target
    return np.array(out, dtype=np.float32)


# --- synthesis ---

def gravel(seconds, seed):
    """Stones crunching under tyres: a rumble bed plus thousands of tiny stone clicks."""
    rng = np.random.default_rng(seed)
    n = int(seconds * RATE)
    bed = lowpass(rng.standard_normal(n).astype(np.float32), 700.0) * 0.35
    clicks = np.zeros(n, dtype=np.float32)
    for _ in range(int(seconds * 900)):
        at = rng.integers(0, n - 400)
        length = rng.integers(60, 320)
        burst = rng.standard_normal(length).astype(np.float32) * np.exp(-np.linspace(0, 6, length))
        clicks[at:at + length] += burst * rng.uniform(0.1, 1.0) ** 2
    clicks = highpass(lowpass(clicks, 5000.0), 600.0)
    return normalize(bed + clicks * 0.8)


def rumble(seconds, seed):
    """Smooth rolling on a hard surface: low rumble and a little hiss."""
    rng = np.random.default_rng(seed)
    n = int(seconds * RATE)
    low = lowpass(rng.standard_normal(n).astype(np.float32), 180.0)
    hiss = highpass(rng.standard_normal(n).astype(np.float32), 3000.0) * 0.02
    return normalize(low + hiss)


def wind(seconds, seed):
    """Wind past the car: band-limited noise with slow gusts."""
    rng = np.random.default_rng(seed)
    n = int(seconds * RATE)
    noise = rng.standard_normal(n).astype(np.float32)
    body = lowpass(noise, 900.0) - lowpass(noise, 120.0) * 0.6
    t = np.arange(n) / RATE
    gust = 0.75 + 0.25 * np.sin(2 * np.pi * 0.31 * t) * np.sin(2 * np.pi * 0.13 * t + 1.0)
    return normalize(body * gust)


def bubbles(n, rng, rate_per_second, seconds):
    out = np.zeros(n, dtype=np.float32)
    for _ in range(int(rate_per_second * seconds)):
        at = rng.integers(0, max(n - 4000, 1))
        f = rng.uniform(250.0, 900.0)
        length = rng.integers(800, 3500)
        t = np.arange(length) / RATE
        out[at:at + length] += np.sin(2 * np.pi * f * t * (1.0 + 2.0 * t)) * np.exp(-t * 40.0) * rng.uniform(0.2, 1.0)
    return out


def slosh(seconds, seed):
    """Driving through water: churning low noise and bubbles."""
    rng = np.random.default_rng(seed)
    n = int(seconds * RATE)
    noise = lowpass(rng.standard_normal(n).astype(np.float32), 1400.0)
    t = np.arange(n) / RATE
    churn = 0.6 + 0.4 * np.abs(np.sin(2 * np.pi * 3.1 * t)) * np.abs(np.sin(2 * np.pi * 1.7 * t + 0.5))
    return normalize(noise * churn + bubbles(n, rng, 40, seconds) * 0.25)


def splash(seed):
    """Hitting a water splash: a burst of water that falls back."""
    rng = np.random.default_rng(seed)
    n = int(1.4 * RATE)
    t = np.arange(n) / RATE
    noise = rng.standard_normal(n).astype(np.float32)
    burst = (lowpass(noise, 2500.0) * np.exp(-t * 4.0) + highpass(noise, 2000.0) * 0.4 * np.exp(-t * 7.0))
    burst[: int(0.01 * RATE)] *= np.linspace(0.0, 1.0, int(0.01 * RATE))
    return fade(normalize(burst + bubbles(n, rng, 25, 1.4) * 0.2), 0.0, 0.2)


def main():
    meta = {}
    # Engine: three steady loops (low cruise, mid pull, high pull), pitch-flattened.
    toyota = read_wav(TOYOTA)
    for name, start, end, target in [("low", 59.5, 62.6, 51.5), ("mid", 143.4, 144.7, 111.0), ("high", 92.0, 94.6, 172.0)]:
        steady = flatten_pitch(cut(toyota, start, end), target)
        write_wav(f"engine/engine_{name}.wav", normalize(loop(steady, 0.12)), loop=True)
        meta[name] = target
    with open(os.path.join(OUT, "engine", "loops.json"), "w") as f:
        json.dump({"firing_hz": meta, "source": "Sonniss GDC 2020, Pole Position - Toyota Corolla 1998 rally car, t9 onboard exhaust"}, f, indent=1)
    # Tyres.
    skids = read_wav(SKIDS)
    write_wav("tyres/skid.wav", normalize(loop(cut(skids, 19.0, 23.3), 0.3)), loop=True)
    write_wav("tyres/gravel.wav", loop(gravel(3.3, 11), 0.3), loop=True)
    write_wav("tyres/rumble.wav", loop(rumble(2.4, 12), 0.2), loop=True)
    # Air and water.
    write_wav("ambience/wind.wav", loop(wind(5.3, 13), 0.3), loop=True)
    write_wav("water/slosh.wav", loop(slosh(2.3, 14), 0.2), loop=True)
    write_wav("water/splash.wav", splash(15))
    # Horn: the sustained part of the onboard horn recording.
    horn = read_wav(HORN)
    write_wav("car/horn.wav", normalize(loop(cut(horn, 17.0, 19.6), 0.15)), loop=True)
    # Crashes: the first strike of each designed impact, and some of the smaller hits in the tails.
    crashes = read_wav(CRASHES)
    for i, (start, length) in enumerate([(0.45, 1.6), (7.7, 1.4), (16.7, 1.5), (27.2, 1.6), (36.45, 1.5), (49.2, 1.6)]):
        write_wav(f"impacts/crash_heavy_{i}.wav", fade(normalize(cut(crashes, start, start + length)), 0.002, 0.4))
    for i, (start, length) in enumerate([(4.45, 0.6), (11.95, 0.6), (32.45, 0.5), (33.7, 0.45), (42.0, 0.4), (45.0, 0.45)]):
        write_wav(f"impacts/crash_light_{i}.wav", fade(normalize(cut(crashes, start, start + length), 0.7), 0.002, 0.15))
    # CC0 files used as they are.
    bsb = os.path.join(RAW, "bigsoundbank")
    copy(os.path.join(bsb, "1293.ogg"), "ambience/rain_on_roof.ogg")
    copy(os.path.join(bsb, "2718.ogg"), "ambience/thunder.ogg")
    copy(os.path.join(bsb, "2799.ogg"), "car/map_rustle_0.ogg")
    copy(os.path.join(bsb, "2805.ogg"), "car/map_rustle_1.ogg")
    impacts = os.path.join(RAW, "kenney", "kenney_impact-sounds")
    for kind in ["impactMetal_light", "impactMetal_medium", "impactGlass_heavy", "impactTin_medium", "impactPlate_heavy", "impactWood_heavy"]:
        for k in range(3):
            copy(os.path.join(impacts, f"{kind}_00{k}.ogg"), f"impacts/{kind}_{k}.ogg")
    ui = os.path.join(RAW, "kenney", "kenney_interface-sounds")
    for kind in ["click_001", "click_003", "confirmation_002", "back_002", "error_004", "select_003", "switch_002", "tick_002", "glass_002"]:
        copy(os.path.join(ui, f"{kind}.ogg"), f"ui/{kind}.ogg")


if __name__ == "__main__":
    main()

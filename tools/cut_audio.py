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

Pure Python on purpose: Smart App Control on the dev PC blocks numpy's compiled modules. Only the
needed stretch of each long recording is read, so it stays quick.
"""
import array
import json
import math
import os
import random
import shutil
import struct
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "raw_assets", "audio")
OUT = os.path.join(ROOT, "assets", "audio")
RATE = 48000
TOYOTA = os.path.join(RAW, "sonniss", "Toyota Rally Car, t9, Onbrd, Fast, Drive, Various, Exhaust, Center, DPA4062.wav")
HORN = os.path.join(RAW, "sonniss", "Toyota Rally Car, t11, Var SFX, Horn, Various, Interior, AMBEO2.wav")
SKIDS = os.path.join(RAW, "sonniss", "Skids_Tarmac_t4_exterior_skidding_in_circles_MKH8060_stand.wav")
CRASHES = os.path.join(RAW, "sonniss", "Car_Destruction_Designed_t44_Impacts_Interor.wav")


# --- reading and writing ---

def read_wav(path, start=0.0, end=None):
    """Mono floats at RATE from a 16- or 24-bit PCM WAV, seconds `start`..`end` only (96 kHz
    sources are halved by averaging sample pairs: a gentle low-pass with a zero at the new Nyquist)."""
    w = wave.open(path, "rb")
    ch, width, rate, frames = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
    first = int(start * rate)
    last = frames if end is None else min(int(end * rate), frames)
    w.setpos(first)
    raw = w.readframes(last - first)
    step = ch * width
    out = []
    if width == 3:
        for i in range(0, len(raw) - step + 1, step):
            total = 0
            for c in range(ch):
                k = i + c * 3
                v = raw[k] | (raw[k + 1] << 8) | (raw[k + 2] << 16)
                total += v - 0x1000000 if v & 0x800000 else v
            out.append(total / ch / 8388608.0)
    elif width == 2:
        values = array.array("h", raw)
        for i in range(0, len(values) - ch + 1, ch):
            out.append(sum(values[i:i + ch]) / ch / 32768.0)
    else:
        raise ValueError(f"{path}: {width * 8}-bit is not handled")
    if rate == 2 * RATE:
        out = [(out[i] + out[i + 1]) * 0.5 for i in range(0, len(out) - 1, 2)]
    elif rate != RATE:
        raise ValueError(f"{path}: {rate} Hz is not handled")
    return out


def write_wav(name, x, loop=False):
    """16-bit mono WAV under assets/audio; a loop gets a smpl chunk spanning the whole file."""
    path = os.path.join(OUT, name)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    pcm = array.array("h", (int(max(-1.0, min(1.0, v)) * 32767.0) for v in x)).tobytes()
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


# --- signal helpers ---

def lowpass(x, cutoff, rate=RATE):
    """Two cascaded one-pole low-pass filters."""
    a = math.exp(-2.0 * math.pi * cutoff / rate)
    data = list(x)
    for _ in range(2):
        acc = 0.0
        for i, v in enumerate(data):
            acc = (1.0 - a) * v + a * acc
            data[i] = acc
    return data


def highpass(x, cutoff, rate=RATE):
    low = lowpass(x, cutoff, rate)
    return [a - b for a, b in zip(x, low)]


def add(*signals):
    return [sum(values) for values in zip(*signals)]


def scale(x, k):
    return [v * k for v in x]


def normalize(x, peak=0.89):
    m = max(abs(v) for v in x) or 1.0
    return [v * (peak / m) for v in x]


def fade(x, fade_in=0.005, fade_out=0.05):
    x = list(x)
    n_in = int(fade_in * RATE)
    n_out = int(fade_out * RATE)
    for i in range(min(n_in, len(x))):
        x[i] *= i / n_in
    for i in range(min(n_out, len(x))):
        x[len(x) - 1 - i] *= (i / n_out) ** 2
    return x


def loop(x, crossfade):
    """Makes `x` loop seamlessly: its tail (crossfade seconds) is blended into its head."""
    n = int(crossfade * RATE)
    body = list(x[:-n])
    tail = x[-n:]
    for i in range(n):
        t = i / (n - 1)
        body[i] = body[i] * math.sqrt(t) + tail[i] * math.sqrt(1.0 - t)
    return body


def f0_track(x, hop=0.02, win=0.08, lo=35.0, hi=330.0):
    """Engine firing frequency every `hop` seconds (autocorrelation on a 4 kHz copy)."""
    factor = 12
    y = [sum(x[i:i + factor]) / factor for i in range(0, len(x) - factor + 1, factor)]
    r = RATE / factor
    # Remove the slow drift (64-sample moving average), as the analysis script did.
    half = 32
    prefix = [0.0]
    for v in y:
        prefix.append(prefix[-1] + v)
    y = [y[i] - (prefix[min(i + half, len(y))] - prefix[max(i - half, 0)]) / (min(i + half, len(y)) - max(i - half, 0))
         for i in range(len(y))]
    n = int(win * r)
    h = int(hop * r)
    lags = list(range(int(r / hi), int(r / lo) + 1))
    out = []
    for start in range(0, len(y) - n, h):
        seg = y[start:start + n]
        energy = sum(v * v for v in seg) + 1e-12
        ac = [sum(seg[k] * seg[k + lag] for k in range(n - lag)) / energy for lag in lags]
        best = max(range(len(ac)), key=lambda k: ac[k])
        for i in range(1, len(ac) - 1):
            if ac[i] > 0.85 * ac[best] and ac[i] >= ac[i - 1] and ac[i] >= ac[i + 1]:
                best = i
                break
        out.append(r / lags[best])
    return out, hop


def flatten_pitch(x, target):
    """Resamples `x` so its firing frequency stays at `target` Hz (a steady-rpm loop)."""
    track, hop = f0_track(x)
    # Smooth over five frames, padding with the end values (zero padding read the ends of each
    # take up to 1.67x too fast).
    padded = [track[0]] * 2 + track + [track[-1]] * 2
    track = [sum(padded[i:i + 5]) / 5.0 for i in range(len(track))]
    out = []
    pos = 0.0
    while pos < len(x) - 2:
        f0 = track[min(int(pos / RATE / hop), len(track) - 1)]
        i = int(pos)
        frac = pos - i
        out.append(x[i] * (1.0 - frac) + x[i + 1] * frac)
        pos += target / f0  # read slower where the recording is higher than the target
    return out


# --- synthesis ---

def noise(n, rng):
    return [rng.gauss(0.0, 1.0) for _ in range(n)]


def gravel(seconds, seed):
    """Stones crunching under tyres: a rumble bed plus thousands of tiny stone clicks."""
    rng = random.Random(seed)
    n = int(seconds * RATE)
    bed = scale(lowpass(noise(n, rng), 700.0), 0.35)
    clicks = [0.0] * n
    for _ in range(int(seconds * 900)):
        at = rng.randrange(0, n - 400)
        length = rng.randrange(60, 320)
        amp = rng.uniform(0.1, 1.0) ** 2
        for k in range(length):
            clicks[at + k] += rng.gauss(0.0, 1.0) * math.exp(-6.0 * k / length) * amp
    clicks = highpass(lowpass(clicks, 5000.0), 600.0)
    return normalize(add(bed, scale(clicks, 0.8)))


def rumble(seconds, seed):
    """Smooth rolling on a hard surface: low rumble and a little hiss."""
    rng = random.Random(seed)
    n = int(seconds * RATE)
    low = lowpass(noise(n, rng), 180.0)
    hiss = scale(highpass(noise(n, rng), 3000.0), 0.02)
    return normalize(add(low, hiss))


def wind(seconds, seed):
    """Wind past the car: band-limited noise with slow gusts."""
    rng = random.Random(seed)
    n = int(seconds * RATE)
    raw = noise(n, rng)
    body = [a - b * 0.6 for a, b in zip(lowpass(raw, 900.0), lowpass(raw, 120.0))]
    gust = [0.75 + 0.25 * math.sin(2 * math.pi * 0.31 * i / RATE) * math.sin(2 * math.pi * 0.13 * i / RATE + 1.0) for i in range(n)]
    return normalize([a * b for a, b in zip(body, gust)])


def bubbles(n, rng, rate_per_second, seconds):
    out = [0.0] * n
    for _ in range(int(rate_per_second * seconds)):
        at = rng.randrange(0, max(n - 4000, 1))
        f = rng.uniform(250.0, 900.0)
        length = rng.randrange(800, 3500)
        amp = rng.uniform(0.2, 1.0)
        for k in range(length):
            t = k / RATE
            out[at + k] += math.sin(2 * math.pi * f * t * (1.0 + 2.0 * t)) * math.exp(-t * 40.0) * amp
    return out


def slosh(seconds, seed):
    """Driving through water: churning low noise and bubbles."""
    rng = random.Random(seed)
    n = int(seconds * RATE)
    water = lowpass(noise(n, rng), 1400.0)
    churn = [0.6 + 0.4 * abs(math.sin(2 * math.pi * 3.1 * i / RATE)) * abs(math.sin(2 * math.pi * 1.7 * i / RATE + 0.5)) for i in range(n)]
    return normalize(add([a * b for a, b in zip(water, churn)], scale(bubbles(n, rng, 40, seconds), 0.25)))


def splash(seed):
    """Hitting a water splash: a burst of water that falls back."""
    rng = random.Random(seed)
    n = int(1.4 * RATE)
    raw = noise(n, rng)
    low = lowpass(raw, 2500.0)
    high = highpass(raw, 2000.0)
    burst = [low[i] * math.exp(-i / RATE * 4.0) + high[i] * 0.4 * math.exp(-i / RATE * 7.0) for i in range(n)]
    attack = int(0.01 * RATE)
    for i in range(attack):
        burst[i] *= i / attack
    return fade(normalize(add(burst, scale(bubbles(n, rng, 25, 1.4), 0.2))), 0.0, 0.2)


def main():
    meta = {}
    # Engine: three steady loops (low cruise, mid pull, high pull), pitch-flattened.
    for name, start, end, target in [("low", 59.5, 62.6, 51.5), ("mid", 143.4, 144.7, 111.0), ("high", 92.0, 94.6, 172.0)]:
        steady = flatten_pitch(read_wav(TOYOTA, start, end), target)
        write_wav(f"engine/engine_{name}.wav", normalize(loop(steady, 0.12)), loop=True)
        meta[name] = target
    with open(os.path.join(OUT, "engine", "loops.json"), "w") as f:
        json.dump({"firing_hz": meta, "source": "Sonniss GDC 2020, Pole Position - Toyota Corolla 1998 rally car, t9 onboard exhaust"}, f, indent=1)
    # Tyres.
    write_wav("tyres/skid.wav", normalize(loop(read_wav(SKIDS, 19.0, 23.3), 0.3)), loop=True)
    write_wav("tyres/gravel.wav", loop(gravel(3.3, 11), 0.3), loop=True)
    write_wav("tyres/rumble.wav", loop(rumble(2.4, 12), 0.2), loop=True)
    # Air and water.
    write_wav("ambience/wind.wav", loop(wind(5.3, 13), 0.3), loop=True)
    write_wav("water/slosh.wav", loop(slosh(2.3, 14), 0.2), loop=True)
    write_wav("water/splash.wav", splash(15))
    # Horn: the sustained part of the onboard horn recording.
    write_wav("car/horn.wav", normalize(loop(read_wav(HORN, 17.0, 19.6), 0.15)), loop=True)
    # Crashes: the first strike of each designed impact, and some of the smaller hits in the tails.
    for i, (start, length) in enumerate([(0.45, 1.6), (7.7, 1.4), (16.7, 1.5), (27.2, 1.6), (36.45, 1.5), (49.2, 1.6)]):
        write_wav(f"impacts/crash_heavy_{i}.wav", fade(normalize(read_wav(CRASHES, start, start + length)), 0.002, 0.4))
    for i, (start, length) in enumerate([(4.45, 0.6), (11.95, 0.6), (32.45, 0.5), (33.7, 0.45), (42.0, 0.4), (45.0, 0.45)]):
        write_wav(f"impacts/crash_light_{i}.wav", fade(normalize(read_wav(CRASHES, start, start + length), 0.7), 0.002, 0.15))
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

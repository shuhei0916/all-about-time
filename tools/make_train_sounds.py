"""列車の音(走行音の繰り返しと警笛)を合成し、wav に書き出す。標準ライブラリだけで動く。

使い方(プロジェクトのフォルダで):
    python tools/make_train_sounds.py
書き出し先は assets/sounds/train/。録音の素材が見つかったら、同じ名前のファイルに差し替えてよい。

- train_engine.wav: ディーゼルエンジンの低いうなり(全速の時)。ゲームの側で、止まると低くしてアイドリングにする。
- train_clatter.wav: レールの継ぎ目を車輪が渡る「タタン、タタン」(全速の時)。ゲームの側で、
  遅いほど刻みをゆっくり、音を小さくし、止まると消す。
  走行音の2つは繰り返して鳴らすので、終わりと始まりが継ぎ目なくつながる。
- train_horn.wav: 警笛。アメリカのディーゼル機関車の5音の和音(D#、F#、G#、B、D#)を2回鳴らす。
"""
import math
import os
import random
import struct
import wave

RATE = 44100
PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(PROJECT, "assets", "sounds", "train")

## 走行音の長さ(秒)。周波数は 1/LOOP_SECONDS の倍数にして、繰り返しの継ぎ目で波がずれないようにする。
LOOP_SECONDS = 4.0


def write_wav(name, samples):
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, name)
    peak = max(abs(s) for s in samples) or 1.0
    scale = 0.9 / peak
    with wave.open(path, "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(b"".join(struct.pack("<h", int(s * scale * 32767)) for s in samples))
    print("WROTE", path, "%.1f 秒" % (len(samples) / RATE))


def snap(freq):
    """繰り返しの継ぎ目で波がそろうよう、周波数を 1/LOOP_SECONDS の倍数に丸める。"""
    step = 1.0 / LOOP_SECONDS
    return round(freq / step) * step


def lowpass(samples, cutoff):
    """1次の低域通過フィルター。"""
    a = 1.0 - math.exp(-2.0 * math.pi * cutoff / RATE)
    out = []
    y = 0.0
    for s in samples:
        y += a * (s - y)
        out.append(y)
    return out


def loop_noise(count, cutoff, rng):
    """継ぎ目なく繰り返せる、低域のこもった雑音。終わりの部分を始まりに重ねてなじませる。"""
    fade = int(RATE * 0.5)
    raw = lowpass([rng.uniform(-1, 1) for _ in range(count + fade)], cutoff)
    out = raw[:count]
    for i in range(fade):
        t = i / fade
        out[i] = raw[count + i] * (1.0 - t) + out[i] * t
    return out


def engine(count, rng):
    """ディーゼルエンジンのうなり。低い基音の倍音を、爆発の周期で脈打たせる。"""
    base = snap(38.0)
    firing = snap(base / 2.0)
    harmonics = [(base * n, 1.0 / n ** 0.8, rng.uniform(0, 2 * math.pi)) for n in range(1, 14)]
    rumble = loop_noise(count, 120.0, rng)
    out = []
    for i in range(count):
        t = i / RATE
        tone = sum(a * math.sin(2 * math.pi * f * t + p) for f, a, p in harmonics)
        pulse = 0.65 + 0.35 * math.sin(2 * math.pi * firing * t) ** 2
        out.append(tone * pulse * 0.25 + rumble[i] * 3.0)
    return out


def clatter(count, rng):
    """レールの継ぎ目を車輪が渡る音。台車の2つの車輪が続けて叩く「タタン」を、2秒ごとに2組。"""
    out = [0.0] * count
    hits = []
    for start in (0.0, 2.0):
        for bogie in (0.15, 1.05):
            hits += [start + bogie, start + bogie + 0.13]
    ring = [(snap(f), rng.uniform(0, 2 * math.pi)) for f in (310.0, 740.0, 1190.0, 2100.0)]
    burst = lowpass([rng.uniform(-1, 1) for _ in range(int(RATE * 0.25))], 1800.0)
    for k, hit in enumerate(hits):
        loud = 1.0 if k % 2 == 0 else 0.8
        begin = int(hit * RATE)
        for j in range(len(burst)):
            t = j / RATE
            env = math.exp(-t * 28.0)
            metal = sum(math.sin(2 * math.pi * f * t + p) for f, p in ring) * math.exp(-t * 40.0) * 0.15
            out[(begin + j) % count] += (burst[j] * 2.5 * env + metal) * loud
    return out


def make_run():
    rng = random.Random(7)
    count = int(RATE * LOOP_SECONDS)
    hum = engine(count, rng)
    hiss = loop_noise(count, 2500.0, rng)
    write_wav("train_engine.wav", [h + n * 0.08 for h, n in zip(hum, hiss)])
    write_wav("train_clatter.wav", clatter(count, rng))


def make_horn():
    rng = random.Random(11)
    chord = [311.13, 369.99, 415.30, 493.88, 622.25]
    blasts = [(0.0, 1.1), (1.4, 1.8)]
    length = blasts[-1][0] + blasts[-1][1] + 0.4
    count = int(RATE * length)
    voices = []
    for f in chord:
        for detune in (-0.6, 0.6):
            voices.append((f + detune, rng.uniform(0, 2 * math.pi)))
    out = []
    for i in range(count):
        t = i / RATE
        env = 0.0
        for begin, duration in blasts:
            local = t - begin
            if 0.0 <= local <= duration + 0.25:
                attack = min(1.0, local / 0.06)
                release = 1.0 if local < duration else math.exp(-(local - duration) * 18.0)
                env = max(env, attack * release)
        if env == 0.0:
            out.append(0.0)
            continue
        wobble = 1.0 + 0.003 * math.sin(2 * math.pi * 5.0 * t)
        s = 0.0
        for f, p in voices:
            phase = 2 * math.pi * f * wobble * t + p
            # 金管のように明るい音色にするため、奇数と偶数の倍音を少しずつ足す
            s += math.sin(phase) + 0.5 * math.sin(2 * phase) + 0.3 * math.sin(3 * phase) + 0.15 * math.sin(4 * phase)
        out.append(s * env)
    write_wav("train_horn.wav", lowpass(out, 3500.0))


make_run()
make_horn()

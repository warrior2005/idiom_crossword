"""生成游戏音效（纯 Python 标准库，输出 16-bit PCM WAV）

输出:
  - assets/audio/fill.wav       填入格子（短促点击）
  - assets/audio/correct.wav    填入正确（上行双音）
  - assets/audio/wrong.wav      填入错误（低音）
  - assets/audio/idiom.wav      成语完成（琶音）
  - assets/audio/complete.wav   关卡完成（短小号角）

使用:
  python scripts/generate_audio.py
"""

import math
import os
import struct
import wave

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
AUDIO_DIR = os.path.join(os.path.dirname(SCRIPT_DIR), 'assets', 'audio')

SAMPLE_RATE = 44100


def write_wav(path, samples):
    """samples: [-1.0, 1.0] 浮点列表 → 16-bit 单声道 WAV"""
    with wave.open(path, 'w') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        frames = b''.join(
            struct.pack('<h', max(-32767, min(32767, int(s * 32767))))
            for s in samples
        )
        w.writeframes(frames)


def sine(freq, duration, volume=0.5, decay=8.0):
    """带指数衰减的正弦音"""
    n = int(SAMPLE_RATE * duration)
    out = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-decay * t)
        out.append(volume * env * math.sin(2 * math.pi * freq * t))
    return out


def tone_sequence(freqs, note=0.14, gap=0.03, volume=0.5):
    """连续音符（小琶音/号角）"""
    out = []
    for f in freqs:
        out.extend(sine(f, note, volume, decay=6.0))
        out.extend([0.0] * int(SAMPLE_RATE * gap))
    return out


def main():
    os.makedirs(AUDIO_DIR, exist_ok=True)
    sounds = {
        'fill.wav': sine(880, 0.06, volume=0.35, decay=12.0),
        'correct.wav': tone_sequence([880, 1174.66], note=0.10, gap=0.02, volume=0.4),
        'wrong.wav': sine(220, 0.18, volume=0.4, decay=6.0),
        'idiom.wav': tone_sequence([523.25, 659.25, 783.99], note=0.12, gap=0.03, volume=0.4),
        'complete.wav': tone_sequence(
            [523.25, 659.25, 783.99, 1046.5],
            note=0.16,
            gap=0.05,
            volume=0.45,
        ),
    }
    for name, samples in sounds.items():
        path = os.path.join(AUDIO_DIR, name)
        write_wav(path, samples)
        size_kb = os.path.getsize(path) / 1024
        print(f'  生成 {name} ({size_kb:.1f} KB)')
    print(f'\n音效目录: {AUDIO_DIR}')


if __name__ == '__main__':
    main()

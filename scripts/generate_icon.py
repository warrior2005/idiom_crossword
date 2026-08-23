"""生成 iOS 应用图标（纯 Python 标准库，无第三方依赖）

设计：仿古纸色底 + 棕色圆角边框 + 2×2 田字格（左上格为"起始字"色块，
右下格为候选字圆点），贴合"成语接龙"主题。

输出到 ios/Runner/Assets.xcassets/AppIcon.appiconset/ 的全部尺寸。

使用：python scripts/generate_icon.py
"""

import math
import os
import struct
import zlib

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ICON_DIR = os.path.join(
    os.path.dirname(SCRIPT_DIR),
    'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset',
)

# Contents.json 中 filename → 像素尺寸
SIZES = {
    'Icon-App-20x20@1x.png': 20,
    'Icon-App-20x20@2x.png': 40,
    'Icon-App-20x20@3x.png': 60,
    'Icon-App-29x29@1x.png': 29,
    'Icon-App-29x29@2x.png': 58,
    'Icon-App-29x29@3x.png': 87,
    'Icon-App-40x40@1x.png': 40,
    'Icon-App-40x40@2x.png': 80,
    'Icon-App-40x40@3x.png': 120,
    'Icon-App-60x60@2x.png': 120,
    'Icon-App-60x60@3x.png': 180,
    'Icon-App-76x76@1x.png': 76,
    'Icon-App-76x76@2x.png': 152,
    'Icon-App-83.5x83.5@2x.png': 167,
    'Icon-App-1024x1024@1x.png': 1024,
}

BASE = 1024
PAPER = (245, 240, 232, 255)
BROWN = (139, 69, 19, 255)
BROWN_LIGHT = (212, 197, 176, 255)
BROWN_DARK = (93, 46, 13, 255)


def rounded_rect_sdf(x, y, cx, cy, half_w, half_h, radius):
    """中心 (cx,cy)、半宽高 half_w/half_h、圆角 radius 的圆角矩形 SDF（负值在内）"""
    dx = max(abs(x - cx) - half_w + radius, 0.0)
    dy = max(abs(y - cy) - half_h + radius, 0.0)
    return math.hypot(dx, dy) - radius


def render_base():
    """渲染 1024×1024 RGBA 图标"""
    img = [[PAPER for _ in range(BASE)] for _ in range(BASE)]

    # 圆角矩形：外框（棕色）与内底（浅纸色）
    frame = (BASE / 2, BASE / 2, BASE / 2 - 36, BASE / 2 - 36, 200)
    inner = (BASE / 2, BASE / 2, BASE / 2 - 46, BASE / 2 - 46, 184)
    for y in range(BASE):
        for x in range(BASE):
            d_frame = rounded_rect_sdf(x + 0.5, y + 0.5, *frame)
            d_inner = rounded_rect_sdf(x + 0.5, y + 0.5, *inner)
            if d_frame <= 0 and d_inner > 0:
                img[y][x] = BROWN

    # 2×2 田字格
    margin = 0.24 * BASE
    gap = 0.045 * BASE
    top = margin
    left = margin
    cell = (BASE - 2 * margin - gap) / 2
    cells = [
        (left, top),
        (left + cell + gap, top),
        (left, top + cell + gap),
        (left + cell + gap, top + cell + gap),
    ]
    radius = 0.06 * BASE

    for ci, (ox, oy) in enumerate(cells):
        ccx, ccy = ox + cell / 2, oy + cell / 2
        for y in range(int(oy) - 2, int(oy + cell) + 3):
            for x in range(int(ox) - 2, int(ox + cell) + 3):
                if not (0 <= x < BASE and 0 <= y < BASE):
                    continue
                d = rounded_rect_sdf(x + 0.5, y + 0.5, ccx, ccy, cell / 2, cell / 2, radius)
                if d <= 0:
                    img[y][x] = BROWN_LIGHT

        # 左上格：填充色块（起始字）；右下格：候选字圆点
        if ci == 0:
            pad = 0.20 * cell
            bx, by = ox + pad, oy + pad
            bsize = cell - 2 * pad
            for y in range(int(by), int(by + bsize)):
                for x in range(int(bx), int(bx + bsize)):
                    if 0 <= x < BASE and 0 <= y < BASE:
                        img[y][x] = BROWN_DARK
        elif ci == 3:
            ddot = 0.10 * cell
            cx, cy = ox + cell / 2, oy + cell / 2
            for y in range(int(cy - ddot), int(cy + ddot) + 1):
                for x in range(int(cx - ddot), int(cx + ddot) + 1):
                    if 0 <= x < BASE and 0 <= y < BASE:
                        dx, dy = x + 0.5 - cx, y + 0.5 - cy
                        if math.hypot(dx, dy) <= ddot:
                            img[y][x] = BROWN_DARK
    return img


def downscale(img, size):
    """箱式平均降采样"""
    out = [[None for _ in range(size)] for _ in range(size)]
    step = BASE / size
    for oy in range(size):
        y0, y1 = int(oy * step), max(int((oy + 1) * step), int(oy * step) + 1)
        for ox in range(size):
            x0, x1 = int(ox * step), max(int((ox + 1) * step), int(ox * step) + 1)
            r = g = b = a = 0
            n = 0
            for y in range(y0, min(y1, BASE)):
                for x in range(x0, min(x1, BASE)):
                    pr, pg, pb, pa = img[y][x]
                    r += pr
                    g += pg
                    b += pb
                    a += pa
                    n += 1
            if n == 0:
                out[oy][ox] = PAPER
            else:
                out[oy][ox] = (r // n, g // n, b // n, a // n)
    return out


def write_png(path, img):
    h = len(img)
    w = len(img[0])

    def chunk(tag, data):
        c = struct.pack('>I', len(data)) + tag + data
        c += struct.pack('>I', zlib.crc32(tag + data) & 0xFFFFFFFF)
        return c

    raw = b''.join(
        b'\x00' + b''.join(struct.pack('4B', *px) for px in row)
        for row in img
    )
    png = b'\x89PNG\r\n\x1a\n'
    png += chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(raw, 9))
    png += chunk(b'IEND', b'')
    with open(path, 'wb') as f:
        f.write(png)


def main():
    os.makedirs(ICON_DIR, exist_ok=True)
    base = render_base()
    for name, size in SIZES.items():
        img = base if size == BASE else downscale(base, size)
        path = os.path.join(ICON_DIR, name)
        write_png(path, img)
        print(f'  生成 {name} ({size}×{size}, {os.path.getsize(path) / 1024:.1f} KB)')
    print(f'\n图标目录: {ICON_DIR}')


if __name__ == '__main__':
    main()

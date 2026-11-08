#!/usr/bin/env python3
"""生成连连看 App 图标（旧式 PNG + Android 8.0+ 自适应图标）

设计：藏蓝底 + 两块米白圆角方块（各印一个红圆 = 同图案配对）+ 金色 S 连线。
用法: python3 scripts/make_icon.py   （需 Pillow）
"""
import math
import os

from PIL import Image, ImageDraw, ImageFont

EMOJI_FONT = '/System/Library/Fonts/Apple Color Emoji.ttc'

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')

NAVY = (27, 58, 92, 255)        # 底色
CREAM = (253, 251, 246, 255)    # 方块
RED = (229, 57, 53, 255)        # 配对图案
GOLD = (255, 179, 0, 255)       # 连线

BASE = 2048  # 超采样画布（4x of 512），缩小抗锯齿


def rounded_tile(draw, center, size, radius, fill):
    x, y = center
    half = size / 2
    draw.rounded_rectangle(
        (x - half, y - half, x + half, y + half),
        radius=radius, fill=fill,
    )


def draw_composition(scale=1.0, bg=NAVY):
    """在 BASE 画布上绘制完整图标；scale<1 时内容向中心收缩（自适应前景用）"""
    img = Image.new('RGBA', (BASE, BASE), (0, 0, 0, 0) if bg is None else bg)
    draw = ImageDraw.Draw(img)

    s = scale
    cx = cy = BASE / 2

    def pt(x, y):
        # 以画布中心为基准缩放
        return (cx + (x - cx) * s, cy + (y - cy) * s)

    tile_a = pt(600, 700)
    tile_b = pt(1448, 1348)
    tile_size = 600 * s
    radius = 140 * s

    # Z 字连线：恰好两个转折点 —— 连连看的消除规则本体
    a_pt = pt(600, 700)
    c1 = pt(1024, 700)
    c2 = pt(1024, 1348)
    b_pt = pt(1448, 1348)
    draw.line([a_pt, c1, c2, b_pt], fill=GOLD, width=int(118 * s), joint='curve')
    for end in (a_pt, b_pt):
        r = 59 * s
        draw.ellipse((end[0] - r, end[1] - r, end[0] + r, end[1] + r), fill=GOLD)

    # 两块米白圆角方块
    tile_a = pt(600, 700)
    tile_b = pt(1448, 1348)
    tile_size = 600 * s
    radius = 140 * s
    rounded_tile(draw, tile_a, tile_size, radius, CREAM)
    rounded_tile(draw, tile_b, tile_size, radius, CREAM)

    # 方块图案：🍋 —— Apple Color Emoji 是位图字体，只支持固定字号（≤160px），
    # 先按支持的字号渲染再缩放到目标尺寸；全部失败则手绘柠檬兜底
    flower_size = int(400 * s)

    def render_emoji(char):
        for size in (160, 150, 128, 112, 96):
            try:
                f = ImageFont.truetype(EMOJI_FONT, size, index=0)
            except Exception:
                continue
            canvas = size * 3
            tmp = Image.new('RGBA', (canvas, canvas), (0, 0, 0, 0))
            d2 = ImageDraw.Draw(tmp)
            try:
                d2.text((canvas / 2, canvas / 2), char, font=f,
                        embedded_color=True, anchor='mm')
            except Exception:
                continue
            bbox = tmp.getbbox()
            if not bbox:
                continue
            return tmp.crop(bbox)
        return None

    emoji = render_emoji('\U0001F34B')  # 🍋
    target = int(flower_size)
    for center in (tile_a, tile_b):
        if emoji is not None:
            img.alpha_composite(emoji.resize((target, target), Image.LANCZOS),
                                (int(center[0] - target / 2), int(center[1] - target / 2)))
        else:
            # 手绘柠檬兜底：黄色斜椭圆 + 端凸 + 绿叶
            layer = Image.new('RGBA', (target * 2, target * 2), (0, 0, 0, 0))
            ld = ImageDraw.Draw(layer)
            w, h = target, int(target * 0.62)
            ld.ellipse((target - w / 2, target - h / 2, target + w / 2, target + h / 2),
                       fill=(255, 214, 64, 255), outline=(214, 158, 22, 255), width=int(target * 0.04))
            ld.ellipse((target + w * 0.30, target - h * 0.14,
                        target + w * 0.30 + target * 0.12, target + h * 0.14),
                       fill=(255, 214, 64, 255))
            ld.ellipse((target - w * 0.12, target - h * 0.62,
                        target + w * 0.22, target - h * 0.30),
                       fill=(111, 168, 62, 255))
            layer = layer.rotate(28, resample=Image.BICUBIC, center=(target, target))
            img.alpha_composite(layer, (int(center[0] - target), int(center[1] - target)))
    return img


    return img


    return img


def export(img, path, size):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.resize((size, size), Image.LANCZOS).save(path, optimize=True)
    print('  ', os.path.relpath(path, ROOT), f'{size}x{size}')


def main():
    # 1) 旧式启动图标：满幅设计
    full = draw_composition(scale=1.0)
    densities = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
    for name, size in densities.items():
        export(full, f'{RES}/mipmap-{name}/ic_launcher.png', size)

    # 2) 自适应前景：内容缩到 62%（108dp 安全区约 66%），背景透明
    fg = draw_composition(scale=0.62, bg=None)
    fg_densities = {'mdpi': 108, 'hdpi': 162, 'xhdpi': 216, 'xxhdpi': 324, 'xxxhdpi': 432}
    for name, size in fg_densities.items():
        export(fg, f'{RES}/mipmap-{name}/ic_launcher_foreground.png', size)

    # 3) 自适应图标 XML（背景=纯色藏蓝）+ 颜色资源
    anydpi = f'{RES}/mipmap-anydpi-v26'
    os.makedirs(anydpi, exist_ok=True)
    for name in ('ic_launcher.xml', 'ic_launcher_round.xml'):
        with open(os.path.join(anydpi, name), 'w') as f:
            f.write(
                '<?xml version="1.0" encoding="utf-8"?>\n'
                '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
                '    <background android:drawable="@color/ic_launcher_background"/>\n'
                '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
                '</adaptive-icon>\n'
            )
    print('   mipmap-anydpi-v26/ic_launcher.xml')

    values = f'{RES}/values'
    os.makedirs(values, exist_ok=True)
    with open(os.path.join(values, 'ic_launcher_background.xml'), 'w') as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<resources>\n'
            '    <color name="ic_launcher_background">#1B3A5C</color>\n'
            '</resources>\n'
        )
    print('   values/ic_launcher_background.xml')
    print('✅ 图标生成完毕')


if __name__ == '__main__':
    main()

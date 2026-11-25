#!/usr/bin/env python3
"""生成调色板 ramp 图：每个色一条「同色族明度阶梯」，供 LutCanvas shader 查表。

思路来自 LutLight2D（Unity 插件）：不用 multiply/lerp 压暗——那会把画面拉灰、
把饱和色洗淡；而是给调色板的**每个颜色**预定义一条明暗梯度，压暗时直接换成
同色族里更暗的那个真实调色板色，色相和饱和度天然保持。

色族检测：按调色板**声明顺序**做块切分。相邻两色 Δ色相 > 20° 或 chroma 比 > 2×
即认为换族。切完后逐块验证 L* 单调递增（不单调说明切错了，直接报错）。

用法：
  python3 gen_palette_ramp.py                       # 用内置 north 39 色
  python3 gen_palette_ramp.py --from-unify <path>   # 从 palette_unify.py 读 north
  python3 gen_palette_ramp.py --bands 7 --out-dir <dir>

依赖：Pillow（本机用 ~/miniconda3/bin/python）
"""

import argparse
import json
import math
import os
import re
import sys

try:
    from PIL import Image
except ImportError:
    sys.exit("需要 Pillow。macOS 上用 ~/miniconda3/bin/python 跑本脚本。")

# north 39 色（数据源：godot-village-demo/tools/palette_unify.py 的 north 数组，
# 2026-11-25 提取。改调色板后必须重新生成 ramp，见 --from-unify 做漂移校验。）
NORTH = [
    "#14140e", "#1e1e16", "#2a2618", "#36301f", "#423a26",
    "#504530", "#5e5238", "#6c5e42", "#7a6a4c", "#8a7a58",
    "#9a8a66", "#aa9a76", "#baa886", "#cab896", "#d8c8a8",
    "#3a4a24", "#4a5a2e", "#5a6a38", "#6e7a48", "#82905a",
    "#6a3a28", "#7a4630", "#8a5238", "#9a5e42", "#aa6a4a",
    "#b8862e", "#c89638", "#d8a848", "#e8bc62", "#f0cc80",
    "#8a3a30", "#a04a3a", "#b85a44",
    "#4a4c4a", "#585a58", "#666866", "#747674", "#828482",
    "#909290",
]

HUE_GAP = 20.0   # 分族：色相角跨度阈值
CH_RATIO = 2.0   # 分族：chroma 比值阈值


# ---------- 色彩空间 ----------

def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_to_rgb(hx):
    return tuple(int(hx[i:i + 2], 16) for i in (1, 3, 5))


def rgb_to_hex(rgb):
    return "#%02x%02x%02x" % tuple(rgb)


def hex_to_lab(hx):
    r, g, b = (c / 255 for c in hex_to_rgb(hx))
    r, g, b = srgb_to_linear(r), srgb_to_linear(g), srgb_to_linear(b)
    x = r * 0.4124564 + g * 0.3575761 + b * 0.1804375
    y = r * 0.2126729 + g * 0.7151522 + b * 0.0721750
    z = r * 0.0193339 + g * 0.1191920 + b * 0.9503041
    xn, yn, zn = x / 0.95047, y, z / 1.08883

    def f(t):
        return t ** (1.0 / 3) if t > 0.008856 else (7.787 * t + 16.0 / 116.0)

    fx, fy, fz = f(xn), f(yn), f(zn)
    return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz))


# ---------- 色族检测 ----------

def detect_families(colors):
    """按声明顺序切块。返回 [[idx...], ...]，每块按 L* 升序。"""
    lab = [hex_to_lab(c) for c in colors]
    hue = [math.degrees(math.atan2(b, a)) % 360 for _, a, b in lab]
    chroma = [math.hypot(a, b) for _, a, b in lab]

    def is_boundary(i, j):
        dh = abs(hue[i] - hue[j])
        dh = min(dh, 360 - dh)
        lo, hi = min(chroma[i], chroma[j]), max(chroma[i], chroma[j])
        ratio = hi / lo if lo > 0.5 else float("inf")
        return dh > HUE_GAP or ratio > CH_RATIO

    blocks, cur = [], [0]
    for i in range(1, len(colors)):
        if is_boundary(i - 1, i):
            blocks.append(cur)
            cur = [i]
        else:
            cur.append(i)
    blocks.append(cur)

    # 每块按 L* 升序，并验证单调（L* 排序后必然有序，此处校验的是原始声明顺序）
    for bi, blk in enumerate(blocks):
        ls = [lab[i][0] for i in blk]
        if any(ls[k] >= ls[k + 1] for k in range(len(ls) - 1)):
            print(f"⚠️  色族 {bi} 的 L* 在声明顺序上不是单调递增，已按 L* 重排："
                  f"{[round(v, 1) for v in ls]}")
        blk.sort(key=lambda i: lab[i][0])

    return blocks, lab


# ---------- ramp 生成 ----------

def build_ramp(colors, blocks, bands):
    """返回 ramp[i][k] = 第 i 个颜色在第 k 档的替代色索引。

    bands 必须为奇数，中间档 = 原色。
    """
    assert bands % 2 == 1, "bands 必须是奇数，才有居中的原色档"
    center = bands // 2

    # 颜色 -> (色族, 族内位置)
    pos = {}
    for blk in blocks:
        for p, idx in enumerate(blk):
            pos[idx] = (blk, p)

    ramp = []
    for i in range(len(colors)):
        blk, p = pos[i]
        row = []
        for k in range(bands):
            target = max(0, min(len(blk) - 1, p + (k - center)))
            row.append(blk[target])
        ramp.append(row)
    return ramp


def write_png(colors, ramp, dst):
    """每列一个源色、每行一个明度档。行序：上暗下亮。"""
    n, bands = len(colors), len(ramp[0])
    im = Image.new("RGB", (n, bands))
    px = im.load()
    for i in range(n):
        for k in range(bands):
            px[i, k] = hex_to_rgb(colors[ramp[i][k]])
    im.save(dst)
    return im.size


# ---------- 校验 ----------

def verify(colors, blocks, ramp):
    """硬性校验：输出必须全部是调色板内的真实颜色，且中间档等于原色。"""
    center = len(ramp[0]) // 2
    palette = set(c.lower() for c in colors)
    problems = []

    for i, row in enumerate(ramp):
        if colors[row[center]] != colors[i]:
            problems.append(f"色 {i} 中间档不是原色：{colors[row[center]]} != {colors[i]}")
        for k, j in enumerate(row):
            if colors[j].lower() not in palette:
                problems.append(f"色 {i} 档 {k} 跑出调色板：{colors[j]}")

    # 每档的族内位置必须单调不降（暗→亮）
    for blk in blocks:
        idx_of = {c: p for p, c in enumerate(blk)}
        for i in blk:
            seq = [idx_of[ramp[i][k]] for k in range(len(ramp[i]))]
            if any(seq[k] > seq[k + 1] for k in range(len(seq) - 1)):
                problems.append(f"色 {i} 的 ramp 不单调：{seq}")
    return problems


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--bands", type=int, default=7, help="明度档数，必须奇数（默认 7 = -3..+3）")
    ap.add_argument("--out-dir", default=None, help="输出目录")
    ap.add_argument("--name", default="north_ramp", help="输出文件名前缀")
    ap.add_argument("--from-unify", default=None,
                    help="从 palette_unify.py 读取 north 色板（校验漂移用）")
    args = ap.parse_args()

    colors = list(NORTH)
    if args.from_unify:
        src = open(os.path.expanduser(args.from_unify), encoding="utf-8").read()
        m = re.search(r'"north":\s*\[(.*?)\]', src, re.S)
        if not m:
            sys.exit(f"在 {args.from_unify} 里找不到 north 数组")
        ext = re.findall(r'#[0-9a-fA-F]{6}', m.group(1))
        if ext != colors:
            print(f"⚠️  色板漂移！palette_unify.py 有 {len(ext)} 色，内置 {len(colors)} 色")
            if len(ext) == len(colors):
                diff = [(i, a, b) for i, (a, b) in enumerate(zip(colors, ext)) if a.lower() != b.lower()]
                for i, a, b in diff:
                    print(f"   idx{i}: 内置 {a} → 实际 {b}")
        else:
            print(f"✅ 色板一致（{len(colors)} 色）")
        colors = ext

    blocks, lab = detect_families(colors)
    print(f"\n色族 {len(blocks)} 个：" + ", ".join(f"{len(b)}色" for b in blocks))
    for bi, blk in enumerate(blocks):
        hs = [math.degrees(math.atan2(lab[i][2], lab[i][1])) % 360 for i in blk]
        print(f"  族{bi}: {len(blk)} 色  色相 {min(hs):.0f}–{max(hs):.0f}°  "
              f"{[colors[i] for i in blk]}")

    ramp = build_ramp(colors, blocks, args.bands)

    problems = verify(colors, blocks, ramp)
    if problems:
        print("\n❌ 校验失败：")
        for p in problems[:10]:
            print("  ", p)
        sys.exit(1)
    print(f"\n✅ 校验通过：{len(colors)} 色 × {args.bands} 档，输出全在调色板内")

    out_dir = args.out_dir or "."
    os.makedirs(out_dir, exist_ok=True)
    png = os.path.join(out_dir, args.name + f"_{args.bands}.png")
    size = write_png(colors, ramp, png)
    print(f"写出 {png} ({size[0]}×{size[1]})")

    meta = {
        "paletteSize": len(colors),
        "bands": args.bands,
        "center": args.bands // 2,
        "colors": colors,
        "families": blocks,
        "ramp": ramp,
        "paletteHexRamp": [[colors[j] for j in row] for row in ramp],
    }
    jp = os.path.join(out_dir, args.name + f"_{args.bands}.json")
    with open(jp, "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, indent=1)
    print(f"写出 {jp}")


if __name__ == "__main__":
    main()

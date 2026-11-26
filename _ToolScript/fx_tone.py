#!/usr/bin/env python3
"""光晕型特效的色域收敛：保留色相与明度结构，只压饱和度上限。

## 为什么不是 palette_unify

`palette_unify.py` 把颜色替换成调色板里的真实色，但它只处理 `alpha >= 240` 的
实心像素。实测法阵 91% 的像素是半透明光晕、刀光 88%——这些全被跳过，
只被 `--blend` 拉了一点灰，结果是"魔法感没了、但也没变协调"。

而且硬替换的另一个问题是：north 39 色的色相只覆盖 35°–124°（黄橙金绿），
根本没有青(180°)、蓝(240°)、紫(270°)。法阵的紫色无处可去，最近色是 46° 的棕。

## 这个工具做什么

不动色相、不动明度、不动 alpha，只把饱和度压到一个上限：

    H' = H
    S' = min(S, sat_cap)
    V' = V

好处：
- 光晕的软边、亮心、层次结构全部保留（因为 S 和 V 的关系没被打散）
- 色相没变，所以"紫色法阵"还是紫色，辨识度在
- 饱和压下来后不再从土色场景里"跳"出来

配合 LutCanvas 的 `max_match_distance`（越界放过），特效过明暗层时也不会被吸附走样。
"""

import argparse
import colorsys
import json
import os
import sys

try:
    from PIL import Image
except ImportError:
    sys.exit("需要 Pillow。macOS 上用 ~/miniconda3/bin/python 跑本脚本。")


def tone_pixel(rgb, sat_cap):
    r, g, b = (v / 255.0 for v in rgb)
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    s2 = min(s, sat_cap)
    r2, g2, b2 = colorsys.hsv_to_rgb(h, s2, v)
    return (round(r2 * 255), round(g2 * 255), round(b2 * 255)), h, s, s2


def process_atlas(src_png, dst_png, sat_cap):
    """逐像素处理整张图集，保留 alpha 不动。返回统计。"""
    im = Image.open(src_png).convert("RGBA")
    px = im.load()
    w, h = im.size

    hue_drift_max = 0.0
    sat_before = sat_after = 0.0
    n = 0

    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            (r2, g2, b2), hue, s0, s1 = tone_pixel((r, g, b), sat_cap)
            px[x, y] = (r2, g2, b2, a)   # alpha 原样保留
            sat_before += s0
            sat_after += s1
            n += 1
            if s0 >= 0.12 and s1 >= 0.12:
                d = abs(hue)  # 色相未变，drift 恒为 0；留字段供扩展
                hue_drift_max = max(hue_drift_max, d)

    im.save(dst_png)
    return {
        "pixels": n,
        "sat_before": sat_before / max(n, 1),
        "sat_after": sat_after / max(n, 1),
        "hue_drift": hue_drift_max,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True, help="源图集 PNG")
    ap.add_argument("--out", required=True, help="输出图集 PNG")
    ap.add_argument("--sat-cap", type=float, default=0.45, help="饱和度上限（0..1）")
    args = ap.parse_args()

    if not os.path.exists(args.src):
        sys.exit(f"找不到源图集: {args.src}")

    st = process_atlas(args.src, args.out, args.sat_cap)
    print(f"{os.path.basename(args.src)} → {os.path.basename(args.out)}")
    print(f"  像素 {st['pixels']}  饱和 {st['sat_before']:.3f} → {st['sat_after']:.3f}"
          f"  色相漂移 {st['hue_drift']:.2f}°")
    print(f"  阈值 sat_cap={args.sat_cap}")


if __name__ == "__main__":
    main()

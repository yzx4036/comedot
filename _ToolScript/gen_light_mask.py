#!/usr/bin/env python3
"""生成光照贴图：一张覆盖整个屏幕的灰度图，给 LutCanvas 当驱动信号。

## 为什么要它

LutCanvas 默认用「像素自身亮度」决定该压深还是该提亮。那本质是调色板空间里的
对比度曲线——同一块地面站在灯下还是缩在墙角，得到的处理完全一样，画面没有体积感。

改成用光照强度驱动后，同一块颜色在不同光照位置会落到不同档位：
亮处提档、暗处压档，才有真正的高低起伏。

## 输出约定

- 灰度 PNG，尺寸 = 屏幕尺寸（LutCanvas 用 SCREEN_UV 采样，不做坐标变换）
- 0 = 全黑，255 = 全亮
- 多个光源按「叠加后 clamp」处理，可以先铺一层 ambient 再叠灯

## 用法

```bash
~/miniconda3/bin/python _ToolScript/gen_light_mask.py \
  --size 960x540 --ambient 0.10 \
  --light 210,320,300,1.0 --light 700,190,220,0.55 \
  --out Assets/Shaders/Lights/test_light.png --quantize 8
```

`--light x,y,radius,intensity` 可重复。`--quantize N` 把光照量化成 N 档，
像素美术里这种做法比平滑渐变更自然（不会有噪点般的抖动）。
"""

import argparse
import math
import os
import sys

try:
    from PIL import Image
except ImportError:
    sys.exit("需要 Pillow。macOS 上用 ~/miniconda3/bin/python 跑本脚本。")


def parse_size(text):
    try:
        w, h = text.lower().split("x")
        return int(w), int(h)
    except Exception:
        sys.exit(f"--size 格式应为 WxH，收到: {text}")


def parse_light(text):
    parts = text.split(",")
    if len(parts) != 4:
        sys.exit(f"--light 格式应为 x,y,radius,intensity，收到: {text}")
    x, y, r, i = (float(p) for p in parts)
    if r <= 0:
        sys.exit(f"光源半径必须为正: {text}")
    return {"x": x, "y": y, "radius": r, "intensity": i}


def build(size, ambient, lights, quantize):
    w, h = size
    im = Image.new("L", (w, h))
    px = im.load()

    for y in range(h):
        for x in range(w):
            total = ambient
            for lt in lights:
                dx = x - lt["x"]
                dy = y - lt["y"]
                d = math.hypot(dx, dy)
                if d >= lt["radius"]:
                    continue
                # 平方衰减：中心附近保持亮，边缘平滑收掉
                k = 1.0 - d / lt["radius"]
                total += lt["intensity"] * k * k
            if quantize > 1:
                # 量化：先 clamp 再落到 N 档，像素风更干净
                total = round(min(max(total, 0.0), 1.0) * (quantize - 1)) / (quantize - 1)
            px[x, y] = int(round(min(max(total, 0.0), 1.0) * 255))
    return im


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--size", default="960x540", help="WxH，须与游戏视口一致")
    ap.add_argument("--ambient", type=float, default=0.10, help="环境光 0..1")
    ap.add_argument("--light", action="append", default=[], help="x,y,radius,intensity")
    ap.add_argument("--quantize", type=int, default=0, help="量化档数，0/1 = 不量化")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    size = parse_size(args.size)
    lights = [parse_light(t) for t in args.light]

    im = build(size, args.ambient, lights, args.quantize)

    out = os.path.abspath(args.out)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    im.save(out)

    # 统计：确认光源真的在起作用，别生成出一张纯色图
    lo, hi = im.getextrema()
    hist = im.histogram()
    dark = sum(hist[:64]) / (size[0] * size[1]) * 100
    bright = sum(hist[192:]) / (size[0] * size[1]) * 100
    print(f"写出 {out}  {size[0]}x{size[1]}")
    print(f"  亮度范围 {lo}..{hi}  暗区(<25%) {dark:.1f}%  亮区(>75%) {bright:.1f}%")
    print(f"  环境光 {args.ambient}  光源 {len(lights)} 个  量化 {args.quantize or '关'}")
    if hi - lo < 10:
        print("  ⚠️ 亮度范围过窄，光源可能没覆盖到画面")


if __name__ == "__main__":
    main()

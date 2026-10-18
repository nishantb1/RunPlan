"""Draws RunPlan's app icon: five rising weekly bars (the fourth a cutback) on a warm gradient."""
import sys
from PIL import Image, ImageDraw

out = sys.argv[1]
S = 4096  # draw at 4x, then downsample for anti-aliasing
top, bottom = (255, 122, 69), (226, 44, 74)  # orange -> red, diagonal

grad = Image.new("RGB", (S, S))
px = grad.load()
for y in range(S):
    for x in range(0, S, 8):
        t = (x + y) / (2 * (S - 1))
        c = tuple(round(a + (b - a) * t) for a, b in zip(top, bottom))
        for dx in range(8):
            px[x + dx, y] = c

draw = ImageDraw.Draw(grad)
heights = [0.30, 0.44, 0.58, 0.42, 0.72]  # build, build, build, cutback, build
n = len(heights)
left, right = 0.20 * S, 0.80 * S
base = 0.73 * S
gap_ratio = 0.45
bar_w = (right - left) / (n + (n - 1) * gap_ratio)
gap = bar_w * gap_ratio
radius = bar_w / 2
for i, h in enumerate(heights):
    x0 = left + i * (bar_w + gap)
    y0 = base - h * (0.62 * S)
    fill = (255, 255, 255) if i != 3 else (255, 214, 200)
    draw.rounded_rectangle([x0, y0, x0 + bar_w, base], radius=radius, fill=fill)

grad.resize((1024, 1024), Image.LANCZOS).save(out, "PNG", optimize=True)
print("wrote", out)

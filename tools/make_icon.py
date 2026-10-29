#!/usr/bin/env python3
"""Генератор иконки SOBATOVSKY OS (1024x1024, без альфа-канала).
Запуск: python3 tools/make_icon.py  (нужен Pillow)"""
import math, os
from PIL import Image, ImageDraw

SS = 4                      # supersampling
N = 1024 * SS
BG = (0x09, 0x09, 0x0B)
EDGE = (0x2B, 0x2B, 0x31)
SILVER = (0xE4, 0xE4, 0xE7)
MID = (0x71, 0x71, 0x7A)

img = Image.new("RGB", (N, N), BG)
d = ImageDraw.Draw(img)

# тонкая внутренняя рамка
m = int(N * 0.07)
d.rounded_rectangle([m, m, N - m, N - m], radius=int(N * 0.19), outline=EDGE, width=int(N * 0.004))

def P(x, y):
    return (x * N, y * N)

def rounded_polyline(pts, r, steps=24):
    out = [pts[0]]
    for i in range(1, len(pts) - 1):
        p0, p1, p2 = pts[i - 1], pts[i], pts[i + 1]
        def unit(a, b):
            dx, dy = b[0] - a[0], b[1] - a[1]
            l = math.hypot(dx, dy)
            return dx / l, dy / l
        u1, u2 = unit(p1, p0), unit(p1, p2)
        a = (p1[0] + u1[0] * r, p1[1] + u1[1] * r)
        b = (p1[0] + u2[0] * r, p1[1] + u2[1] * r)
        for s in range(steps + 1):
            t = s / steps
            x = (1 - t) ** 2 * a[0] + 2 * (1 - t) * t * p1[0] + t ** 2 * b[0]
            y = (1 - t) ** 2 * a[1] + 2 * (1 - t) * t * p1[1] + t ** 2 * b[1]
            out.append((x, y))
    out.append(pts[-1])
    return out

# геометрическая буква S — те же координаты, что в SMark.swift
pts = [P(0.78, 0.18), P(0.26, 0.18), P(0.26, 0.50), P(0.74, 0.50), P(0.74, 0.82), P(0.22, 0.82)]
path = rounded_polyline(pts, 0.14 * N)

def stroke(path, width, color):
    d.line(path, fill=color, width=width, joint="curve")
    r = width / 2
    for (x, y) in path:
        d.ellipse([x - r, y - r, x + r, y + r], fill=color)

W = int(N * 0.085)
stroke(path, W, SILVER)
# тонкая внутренняя линия для «технического» характера
stroke(path, int(W * 0.12), (0x3F, 0x3F, 0x46))

img = img.resize((1024, 1024), Image.LANCZOS)
out = os.path.join(os.path.dirname(__file__), "..", "SOBATOVSKY-OS", "Resources",
                   "Assets.xcassets", "AppIcon.appiconset", "icon-1024.png")
img.save(out, "PNG")
print("saved", os.path.abspath(out))

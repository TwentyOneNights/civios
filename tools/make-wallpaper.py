#!/usr/bin/env python3
"""Erzeugt das CiviOS-Hintergrundbild reproduzierbar.

Aufbau: tiefschwarzer Grund mit Verlauf zu Anthrazit, ein weiches warmes
Leuchten unten rechts und zwei feine Bögen in der Akzentfarbe. Ein leichtes
Rauschen verhindert Farbstufen auf 8-Bit-Bildschirmen.

Nutzung: python3 tools/make-wallpaper.py [Ausgabeordner]
Benötigt: numpy, pillow
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

W, H = 3840, 2160
ACCENT = np.array([242, 192, 85], dtype=np.float32)
DEEP = np.array([10, 10, 11], dtype=np.float32)
ANTHRACITE = np.array([30, 30, 33], dtype=np.float32)


def render(w=W, h=H, seed=7):
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    nx, ny = x / w, y / h

    # Diagonaler Grundverlauf: oben links fast schwarz, unten rechts Anthrazit.
    t = np.clip((nx * 0.6 + ny * 0.4), 0, 1)[..., None]
    img = DEEP * (1 - t) + ANTHRACITE * t

    # Warmes Leuchten, Zentrum ausserhalb des Bildes unten rechts.
    cx, cy = 1.05 * w, 1.15 * h
    d = np.sqrt((x - cx) ** 2 + (y - cy) ** 2) / h
    glow = np.exp(-((d / 0.62) ** 2))[..., None]
    img = img * (1 - glow * 0.55) + ACCENT * glow * 0.55 * 0.62

    # Zwei feine Bögen um dasselbe Zentrum.
    for radius, strength in ((0.92, 0.55), (1.08, 0.28)):
        ring = np.exp(-(((d - radius) / 0.0016) ** 2))
        fade = np.clip(1.2 - (cx - x) / w * 1.1, 0, 1)
        a = (ring * fade * strength)[..., None]
        img = img * (1 - a) + ACCENT * a

    # Vignette für Tiefe.
    vx, vy = nx - 0.5, ny - 0.5
    vig = 1 - 0.35 * np.clip((vx ** 2 + vy ** 2) * 1.6, 0, 1)
    img *= vig[..., None]

    # Dithering gegen Banding.
    rng = np.random.default_rng(seed)
    img += rng.normal(0, 0.9, img.shape).astype(np.float32)
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB")


def main():
    out = Path(sys.argv[1] if len(sys.argv) > 1 else "overlay/usr/share")
    wall = out / "wallpapers/CiviOS/contents/images"
    prev = out / "plasma/look-and-feel/org.civios.desktop/contents/previews"
    wall.mkdir(parents=True, exist_ok=True)
    prev.mkdir(parents=True, exist_ok=True)

    img = render()
    img.save(wall / "3840x2160.png", optimize=True)
    img.resize((1920, 1080), Image.LANCZOS).save(wall / "1920x1080.png", optimize=True)
    img.resize((2560, 1440), Image.LANCZOS).save(wall / "2560x1440.png", optimize=True)
    img.resize((1920, 1080), Image.LANCZOS).save(prev / "fullscreenpreview.jpg", quality=88)
    img.resize((560, 315), Image.LANCZOS).save(prev / "preview.png", optimize=True)
    print("Hintergrundbilder erzeugt in", wall)


if __name__ == "__main__":
    main()

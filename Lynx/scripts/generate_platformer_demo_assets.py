#!/usr/bin/env python3
"""Генерирует PNG для projects/platformer-demo (4 тайла 32x32 в ряд)."""
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    raise SystemExit("pip install pillow")

root = Path(__file__).resolve().parent.parent / "projects" / "platformer-demo"
out = root / "assets" / "tilesets" / "platform.png"
out.parent.mkdir(parents=True, exist_ok=True)

colors = [(0x5C, 0x7A, 0x4A), (0x6B, 0x8E, 0x5A), (0x4A, 0x62, 0x3C), (0x7A, 0x9A, 0x6A)]
img = Image.new("RGBA", (128, 32))
for i, rgb in enumerate(colors):
    tile = Image.new("RGBA", (32, 32), rgb + (255,))
    img.paste(tile, (i * 32, 0))

img.save(out)
print(f"Wrote {out}")

hero = root / "assets" / "sprites" / "hero.png"
hero.parent.mkdir(parents=True, exist_ok=True)
sheet = Image.new("RGBA", (64, 32))
for i, shade in enumerate([(0x3D, 0x8B, 0xD9), (0x2E, 0x6F, 0xAD)]):
    tile = Image.new("RGBA", (32, 32), shade + (255,))
    sheet.paste(tile, (i * 32, 0))
sheet.save(hero)
print(f"Wrote {hero}")

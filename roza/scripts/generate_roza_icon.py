"""Генерация roza/assets/roza.ico (нужен pillow: pip install pillow)."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT_ICO = ROOT / "roza" / "assets" / "roza.ico"
OUT_PNG = ROOT / "roza" / "assets" / "roza.png"
OUT_WEB = ROOT / "roza" / "web" / "static" / "favicon.png"


def _draw(size: int) -> Image.Image:
    img = Image.new("RGBA", (size, size), (13, 20, 33, 255))
    draw = ImageDraw.Draw(img)
    cx, cy = size // 2, size // 2
    r = int(size * 0.38)
    for i in range(r, 0, -1):
        t = i / r
        b = int(26 + (138 - 26) * t)
        g = int(115 + (180 - 115) * t)
        rr = int(26 + (74 - 26) * t)
        color = (rr, g, b, 255)
        draw.ellipse((cx - i, cy - i, cx + i, cy + i), fill=color)
    # лёгкое кольцо
    draw.ellipse(
        (cx - r - 2, cy - r - 2, cx + r + 2, cy + r + 2),
        outline=(138, 180, 248, 220),
        width=max(1, size // 64),
    )
    # буква R
    try:
        font = ImageFont.truetype("segoeui.ttf", int(size * 0.52))
    except OSError:
        font = ImageFont.load_default()
    letter = "R"
    if hasattr(draw, "textbbox"):
        x0, y0, x1, y1 = draw.textbbox((0, 0), letter, font=font)
        tw, th = x1 - x0, y1 - y0
    else:
        tw, th = draw.textsize(letter, font=font)
    tx = cx - tw // 2
    ty = cy - th // 2 - int(size * 0.04)
    draw.text((tx, ty), letter, fill=(255, 255, 255, 255), font=font)
    # блик
    br = max(2, size // 16)
    draw.ellipse(
        (cx - r // 2, cy - r // 2, cx - r // 2 + br, cy - r // 2 + br),
        fill=(255, 255, 255, 90),
    )
    return img


def main() -> None:
    OUT_ICO.parent.mkdir(parents=True, exist_ok=True)
    sizes = (16, 24, 32, 48, 64, 128, 256)
    images = [_draw(s) for s in sizes]
    images[0].save(
        OUT_ICO,
        format="ICO",
        sizes=[(s, s) for s in sizes],
        append_images=images[1:],
    )
    _draw(512).save(OUT_PNG, "PNG")
    OUT_WEB.parent.mkdir(parents=True, exist_ok=True)
    _draw(192).save(OUT_WEB, "PNG")
    print(f"OK: {OUT_ICO}\nOK: {OUT_PNG}\nOK: {OUT_WEB}")


if __name__ == "__main__":
    main()

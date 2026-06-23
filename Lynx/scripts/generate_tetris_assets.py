#!/usr/bin/env python3
"""PNG-спрайты для projects/tetris-demo (блоки + рамка поля)."""
from pathlib import Path

try:
    from PIL import Image, ImageDraw
except ImportError:
    raise SystemExit("pip install pillow")

ROOT = Path(__file__).resolve().parent.parent / "projects" / "tetris-demo" / "assets" / "sprites"
ROOT.mkdir(parents=True, exist_ok=True)

BLOCKS = [
    ("block_I", (0, 240, 240, 255)),
    ("block_O", (240, 240, 0, 255)),
    ("block_T", (160, 0, 240, 255)),
    ("block_S", (0, 240, 0, 255)),
    ("block_Z", (240, 0, 0, 255)),
    ("block_J", (0, 0, 240, 255)),
    ("block_L", (240, 160, 0, 255)),
]


def block_png(name: str, rgba: tuple[int, int, int, int]) -> None:
    img = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle((1, 1, 22, 22), fill=rgba, outline=(255, 255, 255, 90))
    d.rectangle((3, 3, 10, 10), fill=(255, 255, 255, 40))
    img.save(ROOT / f"{name}.png")


def board_frame() -> None:
    w, h = 240, 480
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, w - 1, h - 1), outline=(120, 130, 150, 220), width=2)
    d.rectangle((4, 4, w - 5, h - 5), outline=(60, 70, 90, 180), width=1)
    img.save(ROOT / "board_frame.png")


def ghost_cell() -> None:
    img = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle((2, 2, 21, 21), outline=(200, 200, 200, 120), width=1)
    img.save(ROOT / "ghost_cell.png")


def main() -> None:
    for name, color in BLOCKS:
        block_png(name, color)
    board_frame()
    ghost_cell()
    print(f"OK: {ROOT}")


if __name__ == "__main__":
    main()

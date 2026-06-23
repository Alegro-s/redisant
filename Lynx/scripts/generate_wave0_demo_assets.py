#!/usr/bin/env python3
"""Генерирует PNG и scenes/main.json для projects/platformer-demo (волна 0) и 3D-вариант (волна 1)."""
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path

try:
    from PIL import Image, ImageDraw
except ImportError:
    raise SystemExit("pip install pillow")

DEMO = Path(__file__).resolve().parent.parent / "projects" / "platformer-demo"
TILE = DEMO / "assets" / "tilesets"
SPR = DEMO / "assets" / "sprites"
SCENES = DEMO / "scenes"

TW = 30
TH = 14


def make_tilemap_arrays() -> tuple[list[int], list[int]]:
    n = TW * TH
    tile_ids = [0] * n
    collision = [0] * n
    for row in range(TH):
        for col in range(TW):
            i = row * TW + col
            if row >= TH - 3:
                tile_ids[i] = 1
                collision[i] = 1
            elif row == TH - 4 and 8 <= col <= 20:
                tile_ids[i] = 2
                collision[i] = 2
    return tile_ids, collision


def main() -> None:
    TILE.mkdir(parents=True, exist_ok=True)
    SPR.mkdir(parents=True, exist_ok=True)
    SCENES.mkdir(parents=True, exist_ok=True)

    atlas = Image.new("RGBA", (128, 32), (0, 0, 0, 0))
    draw = ImageDraw.Draw(atlas)
    colors = [
        (60, 90, 120, 255),
        (80, 130, 70, 255),
        (140, 110, 60, 255),
        (90, 70, 130, 255),
    ]
    for i, c in enumerate(colors):
        draw.rectangle([i * 32, 0, i * 32 + 31, 31], fill=c)
        draw.rectangle([i * 32, 0, i * 32 + 31, 31], outline=(20, 20, 20, 255))
    atlas.save(TILE / "platform.png")

    hero = Image.new("RGBA", (64, 32), (0, 0, 0, 0))
    hd = ImageDraw.Draw(hero)
    hd.rectangle([4, 4, 27, 27], fill=(220, 80, 90, 255))
    hd.rectangle([36, 6, 59, 25], fill=(240, 180, 60, 255))
    hero.save(SPR / "hero.png")

    meta = {
        "colliderKind": "aabb",
        "colliderWidth": 28,
        "colliderHeight": 28,
        "sheetAnimation": {
            "fps": 8,
            "frames": [
                {"x": 0, "y": 0, "w": 32, "h": 32},
                {"x": 32, "y": 0, "w": 32, "h": 32},
            ],
        },
    }
    (SPR / "hero.meta.json").write_text(json.dumps(meta, indent=2), encoding="utf-8")

    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z")
    tile_ids, collision = make_tilemap_arrays()
    scene = {
        "formatVersion": 3,
        "id": "main",
        "name": "Main",
        "objects": [
            {
                "id": "player_1",
                "name": "Player",
                "x": 160,
                "y": 320,
                "width": 32,
                "height": 32,
                "rotation": 0,
                "scaleX": 1,
                "scaleY": 1,
                "z": 10,
                "active": True,
                "visible": True,
                "locked": False,
                "layerId": "default",
                "assetId": "assets_sprites_hero.png",
                "scriptId": "assets_scripts_player.lua",
                "properties": {
                    "rustPlatformerMotor": {
                        "enabled": True,
                        "run_speed": 260,
                        "jump_velocity": 520,
                        "gravity_scale": 1,
                        "coyote_time": 0.12,
                        "jump_buffer_time": 0.14,
                        "use_gamepad": True,
                    },
                    "rustAnimStateMachine": {
                        "enabled": True,
                        "fallback_clip": "idle",
                        "rules": [
                            {
                                "clip_id": "run",
                                "conditions": ["speed_x_above"],
                                "speed_threshold": 20,
                            },
                            {
                                "clip_id": "idle",
                                "conditions": ["on_ground"],
                                "speed_threshold": 0,
                            },
                        ],
                    },
                    "rustAnimationClips": {
                        "idle": {
                            "frames": [{"x": 0, "y": 0, "w": 32, "h": 32}],
                            "fps": 4,
                        },
                        "run": {
                            "frames": [
                                {"x": 0, "y": 0, "w": 32, "h": 32},
                                {"x": 32, "y": 0, "w": 32, "h": 32},
                            ],
                            "fps": 10,
                        },
                    },
                },
            }
        ],
        "layers": [{"id": "default", "name": "Default", "sortOrder": 0}],
        "camera": {
            "x": 480,
            "y": 270,
            "zoom": 1,
            "followInstanceId": "player_1",
            "deadZoneHalfW": 80,
            "deadZoneHalfH": 60,
        },
        "backgroundColorArgb": 4280822316,
        "physics": {"gravityY": 980},
        "tilemaps": [
            {
                "id": "ground",
                "tileW": 32,
                "tileH": 32,
                "zOrder": -100,
                "visible": True,
                "tilesetId": "platform",
                "autotile": False,
                "chunks": [
                    {
                        "cx": 0,
                        "cy": 0,
                        "tw": TW,
                        "th": TH,
                        "tile_ids": tile_ids,
                        "collision": collision,
                    }
                ],
            }
        ],
        "rooms": [
            {
                "id": "main_room",
                "x": 0,
                "y": 0,
                "w": 960,
                "h": 540,
                "cameraMinX": 0,
                "cameraMinY": 0,
                "cameraMaxX": 960,
                "cameraMaxY": 540,
            }
        ],
        "createdAt": now,
        "modifiedAt": now,
        "revision": 1,
    }
    (SCENES / "main.json").write_text(json.dumps(scene, indent=2), encoding="utf-8")

    lua = (DEMO / "assets" / "scripts" / "player.lua")
    lua.parent.mkdir(parents=True, exist_ok=True)
    lua.write_text(
        """-- Platformer demo (wave 0)
local speed = 260
local jump = 520
local nvx = 0
local nvy = vy

if key_a then nvx = -speed end
if key_d then nvx = speed end
if not key_a and not key_d then nvx = 0 end
if key_space and on_ground then nvy = -jump end
set_velocity(nvx, nvy)
""",
        encoding="utf-8",
    )

    print("Wave 0 demo generated at", DEMO)
    _write_wave1_3d_variant()
    _write_wave2_demo()
    _write_wave6_3d_room()


def _write_wave1_3d_variant() -> None:
    """Копия demo с включённым плагином lynx.3d (волна 1)."""
    import shutil

    root = Path(__file__).resolve().parent.parent
    src = root / "projects" / "platformer-demo"
    dst = root / "projects" / "platformer-demo-3d"
    if dst.exists():
        shutil.rmtree(dst)
    shutil.copytree(src, dst)

    proj = json.loads((dst / "project.json").read_text(encoding="utf-8"))
    proj["displayName"] = "Platformer Demo 3D (Wave 1)"
    proj["projectMode"] = "3d"
    proj["lynxPlugins"] = {
        "apiVersion": 1,
        "enabled": ["lynx.3d"],
        "config": {"lynx.3d": {"defaultCamera": "perspective"}},
    }
    (dst / "project.json").write_text(json.dumps(proj, indent=2), encoding="utf-8")

    scene_path = dst / "scenes" / "main.json"
    scene = json.loads(scene_path.read_text(encoding="utf-8"))
    scene["extensions"] = {
        "lynx.3d": {
            "active": True,
            "world": {"ambientColor": "#404050", "gravity": [0, -9.81, 0]},
            "camera": {"type": "perspective", "fovY": 60, "near": 0.1, "far": 500},
        }
    }
    scene_path.write_text(json.dumps(scene, indent=2), encoding="utf-8")

    plug_src = root / "plugins" / "lynx_3d"
    plug_dst = dst / "plugins" / "lynx_3d"
    plug_dst.parent.mkdir(parents=True, exist_ok=True)
    if plug_src.exists():
        shutil.copytree(plug_src, plug_dst)

    print("Wave 1 demo (3D plugin) at", dst)


def _write_wave2_demo() -> None:
    """Demo волны 2: меню → уровень, autoload, input map."""
    import shutil

    root = Path(__file__).resolve().parent.parent
    src = root / "projects" / "platformer-demo"
    dst = root / "projects" / "platformer-wave2"
    if dst.exists():
        shutil.rmtree(dst)
    shutil.copytree(src, dst)

    proj = json.loads((dst / "project.json").read_text(encoding="utf-8"))
    proj["displayName"] = "Platformer Wave 2 (Runtime)"
    proj["startupSceneId"] = "menu"
    proj["autoloadSceneIds"] = ["bootstrap"]
    proj["inputMap"] = {
        "move_left": ["A", "Left"],
        "move_right": ["D", "Right"],
        "jump": ["Space", "W"],
        "confirm": ["Return", "Space"],
    }
    (dst / "project.json").write_text(json.dumps(proj, indent=2), encoding="utf-8")

    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z")
    menu = {
        "formatVersion": 3,
        "id": "menu",
        "name": "Menu",
        "objects": [
            {
                "id": "menu_play_ui",
                "name": "PlayButton",
                "type": "empty",
                "x": 640,
                "y": 420,
                "z": 0,
                "active": True,
                "visible": True,
                "width": 200,
                "height": 48,
                "layerId": "layer_ui",
                "properties": {
                    "lynxUi": {
                        "type": "button",
                        "text": "Играть (UI)",
                        "action": "load_scene:main",
                    }
                },
            },
            {
                "id": "menu_ctrl",
                "name": "MenuController",
                "type": "empty",
                "x": 640,
                "y": 360,
                "z": 0,
                "active": True,
                "visible": True,
                "properties": {
                    "script": {
                        "code": (
                            '-- Волна 2: Enter / Space → уровень\n'
                            'if action_confirm then\n'
                            '  load_scene("main")\n'
                            'end\n'
                        )
                    }
                },
            },
            {
                "id": "title",
                "name": "Title",
                "type": "sprite",
                "x": 640,
                "y": 280,
                "z": 0,
                "active": True,
                "visible": True,
                "properties": {
                    "static": True,
                    "tint": 0xFF4FC3F7,
                },
            },
        ],
        "layers": [{"id": "default", "name": "Default", "sortOrder": 0}],
        "camera": {"x": 640, "y": 360, "zoom": 1, "followInstanceId": None},
        "backgroundColorArgb": 4278190080,
        "physics": {"gravityY": 980},
        "tilemaps": [],
        "rooms": [],
        "createdAt": now,
        "modifiedAt": now,
        "revision": 1,
    }
    (dst / "scenes" / "menu.json").write_text(json.dumps(menu, indent=2), encoding="utf-8")

    bootstrap = {
        "formatVersion": 3,
        "id": "bootstrap",
        "name": "Bootstrap",
        "objects": [
            {
                "id": "autoload_marker",
                "name": "AutoloadMarker",
                "type": "empty",
                "x": 24,
                "y": 24,
                "z": 0,
                "active": True,
                "visible": True,
                "properties": {"static": True, "tint": 0xFF9E9E9E},
            }
        ],
        "layers": [{"id": "default", "name": "Default", "sortOrder": 0}],
        "camera": {"x": 640, "y": 360, "zoom": 1},
        "backgroundColorArgb": 4278190080,
        "physics": {"gravityY": 980},
        "tilemaps": [],
        "rooms": [],
        "createdAt": now,
        "modifiedAt": now,
        "revision": 1,
    }
    (dst / "scenes" / "bootstrap.json").write_text(
        json.dumps(bootstrap, indent=2), encoding="utf-8"
    )

    main_path = dst / "scenes" / "main.json"
    main = json.loads(main_path.read_text(encoding="utf-8"))
    for o in main.get("objects", []):
        if o.get("name") == "Player":
            props = o.setdefault("properties", {})
            script = props.setdefault("script", {})
            script["code"] = (
                "local speed = 260\n"
                "local jump = 520\n"
                "local nvx = 0\n"
                "local nvy = vy\n"
                "if action_move_left or key_a then nvx = -speed end\n"
                "if action_move_right or key_d then nvx = speed end\n"
                "if not (action_move_left or key_a) and not (action_move_right or key_d) then nvx = 0 end\n"
                "if (action_jump or key_space) and on_ground then nvy = -jump end\n"
                "set_velocity(nvx, nvy)\n"
            )
    main_path.write_text(json.dumps(main, indent=2), encoding="utf-8")

    print("Wave 2 demo at", dst)


def _write_crate_glb(path: Path) -> None:
    """Минимальный GLB (куб 1×1×1) для демо 3D-рендера."""
    import struct

    verts = [
        -0.5, -0.5, -0.5, 0.5, -0.5, -0.5, 0.5, 0.5, -0.5, -0.5, 0.5, -0.5,
        -0.5, -0.5, 0.5, 0.5, -0.5, 0.5, 0.5, 0.5, 0.5, -0.5, 0.5, 0.5,
    ]
    idx = [
        0, 1, 2, 0, 2, 3, 4, 6, 5, 4, 7, 6, 0, 4, 5, 0, 5, 1, 2, 6, 7, 2, 7, 3,
        0, 3, 7, 0, 7, 4, 1, 5, 6, 1, 6, 2,
    ]
    bin_data = struct.pack("<24f", *verts) + struct.pack("<36H", *idx)
    gltf = {
        "asset": {"version": "2.0"},
        "buffers": [{"byteLength": len(bin_data)}],
        "bufferViews": [
            {"buffer": 0, "byteOffset": 0, "byteLength": 96, "target": 34962},
            {"buffer": 0, "byteOffset": 96, "byteLength": 72, "target": 34963},
        ],
        "accessors": [
            {
                "bufferView": 0,
                "componentType": 5126,
                "count": 8,
                "type": "VEC3",
                "max": [0.5, 0.5, 0.5],
                "min": [-0.5, -0.5, -0.5],
            },
            {"bufferView": 1, "componentType": 5123, "count": 36, "type": "SCALAR"},
        ],
        "meshes": [{"primitives": [{"attributes": {"POSITION": 0}, "indices": 1}]}],
    }
    json_bytes = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    json_pad = (4 - len(json_bytes) % 4) % 4
    json_bytes += b" " * json_pad
    bin_pad = (4 - len(bin_data) % 4) % 4
    bin_data_padded = bin_data + b"\x00" * bin_pad
    total = 12 + 8 + len(json_bytes) + 8 + len(bin_data_padded)
    out = bytearray()
    out += b"glTF"
    out += struct.pack("<I", 2)
    out += struct.pack("<I", total)
    out += struct.pack("<I", len(json_bytes))
    out += struct.pack("<I", 0x4E4F534A)
    out += json_bytes
    out += struct.pack("<I", len(bin_data_padded))
    out += struct.pack("<I", 0x004E4942)
    out += bin_data_padded
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(bytes(out))


def _write_wave6_3d_room() -> None:
    """Демо волны 6/14: полный 3D room (PBR + walk + terrain)."""
    from generate_wave14_3d_assets import generate_wave14_demo

    generate_wave14_demo()


if __name__ == "__main__":
    main()

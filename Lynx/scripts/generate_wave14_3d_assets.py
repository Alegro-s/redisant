#!/usr/bin/env python3
"""Wave 14 demo assets: PBR crate, walk hero, terrain, scene JSON."""
from __future__ import annotations

import json
import math
import struct
import struct as st
from pathlib import Path

try:
    from PIL import Image, ImageDraw
except ImportError:
    Image = None  # type: ignore


ROOT = Path(__file__).resolve().parent.parent
DEMO = ROOT / "projects" / "platformer-demo-3d-room"


def _pack_glb(gltf: dict, bin_data: bytes) -> bytes:
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
    return bytes(out)


def _write_crate_glb(path: Path) -> None:
    """Cube 1×1 with UVs and normals (24 verts)."""
    faces = [
        ([-0.5, -0.5, -0.5], [0, 0, -1], [0, 0]),
        ([0.5, -0.5, -0.5], [0, 0, -1], [1, 0]),
        ([0.5, 0.5, -0.5], [0, 0, -1], [1, 1]),
        ([-0.5, 0.5, -0.5], [0, 0, -1], [0, 1]),
        ([0.5, -0.5, -0.5], [1, 0, 0], [0, 0]),
        ([0.5, -0.5, 0.5], [1, 0, 0], [1, 0]),
        ([0.5, 0.5, 0.5], [1, 0, 0], [1, 1]),
        ([0.5, 0.5, -0.5], [1, 0, 0], [0, 1]),
        ([0.5, -0.5, 0.5], [0, 0, 1], [0, 0]),
        ([-0.5, -0.5, 0.5], [0, 0, 1], [1, 0]),
        ([-0.5, 0.5, 0.5], [0, 0, 1], [1, 1]),
        ([0.5, 0.5, 0.5], [0, 0, 1], [0, 1]),
        ([-0.5, -0.5, 0.5], [-1, 0, 0], [0, 0]),
        ([-0.5, -0.5, -0.5], [-1, 0, 0], [1, 0]),
        ([-0.5, 0.5, -0.5], [-1, 0, 0], [1, 1]),
        ([-0.5, 0.5, 0.5], [-1, 0, 0], [0, 1]),
        ([-0.5, 0.5, -0.5], [0, 1, 0], [0, 0]),
        ([0.5, 0.5, -0.5], [0, 1, 0], [1, 0]),
        ([0.5, 0.5, 0.5], [0, 1, 0], [1, 1]),
        ([-0.5, 0.5, 0.5], [0, 1, 0], [0, 1]),
        ([-0.5, -0.5, 0.5], [0, -1, 0], [0, 0]),
        ([0.5, -0.5, 0.5], [0, -1, 0], [1, 0]),
        ([0.5, -0.5, -0.5], [0, -1, 0], [1, 1]),
        ([-0.5, -0.5, -0.5], [0, -1, 0], [0, 1]),
    ]
    positions, normals, uvs, indices = [], [], [], []
    for i, (p, n, uv) in enumerate(faces):
        positions.extend(p)
        normals.extend(n)
        uvs.extend(uv)
        base = i * 4
        indices.extend([base, base + 1, base + 2, base, base + 2, base + 3])
    pos_b = st.pack(f"<{len(positions)}f", *positions)
    nrm_b = st.pack(f"<{len(normals)}f", *normals)
    uv_b = st.pack(f"<{len(uvs)}f", *uvs)
    idx_b = st.pack(f"<{len(indices)}H", *indices)
    off = 0
    views = []
    accessors = []

    def add_view(data: bytes, target: int | None = None) -> int:
        nonlocal off
        idx = len(views)
        v = {"buffer": 0, "byteOffset": off, "byteLength": len(data)}
        if target is not None:
            v["target"] = target
        views.append(v)
        off += len(data)
        return idx

    def pad4() -> None:
        nonlocal off, bin_parts
        pad = (4 - off % 4) % 4
        if pad:
            bin_parts.append(b"\x00" * pad)
            off += pad

    bin_parts: list[bytes] = []
    off = 0
    bv_pos = add_view(pos_b, 34962)
    pad4()
    bv_nrm = add_view(nrm_b, 34962)
    pad4()
    bv_uv = add_view(uv_b, 34962)
    pad4()
    bv_idx = add_view(idx_b, 34963)
    pad4()
    bin_data = b"".join(bin_parts)

    accessors = [
        {
            "bufferView": bv_pos,
            "componentType": 5126,
            "count": 24,
            "type": "VEC3",
            "max": [0.5, 0.5, 0.5],
            "min": [-0.5, -0.5, -0.5],
        },
        {
            "bufferView": bv_nrm,
            "componentType": 5126,
            "count": 24,
            "type": "VEC3",
        },
        {
            "bufferView": bv_uv,
            "componentType": 5126,
            "count": 24,
            "type": "VEC2",
        },
        {
            "bufferView": bv_idx,
            "componentType": 5123,
            "count": 36,
            "type": "SCALAR",
        },
    ]
    gltf = {
        "asset": {"version": "2.0"},
        "buffers": [{"byteLength": len(bin_data)}],
        "bufferViews": views,
        "accessors": accessors,
        "meshes": [
            {
                "primitives": [
                    {
                        "attributes": {
                            "POSITION": 0,
                            "NORMAL": 1,
                            "TEXCOORD_0": 2,
                        },
                        "indices": 3,
                    }
                ]
            }
        ],
        "nodes": [{"mesh": 0}],
        "scenes": [{"nodes": [0]}],
        "scene": 0,
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(_pack_glb(gltf, bin_data))


def _write_hero_skinned_glb(path: Path) -> None:
    """Capsule-like quad + 2-joint skin + walk rotation clip."""
    # 4 verts in bind pose (body panel)
    positions = [-0.3, 0.0, 0.0, 0.3, 0.0, 0.0, 0.3, 1.2, 0.0, -0.3, 1.2, 0.0]
    normals = [0.0, 0.0, 1.0] * 4
    uvs = [0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0]
    joints = [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1]
    weights = [
        1.0, 0.0, 0.0, 0.0,
        1.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0,
    ]
    indices = [0, 1, 2, 0, 2, 3]
    identity = [
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1,
    ]
    ibm_root = identity[:]
    ibm_leg = [
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, -0.6, 0, 1,
    ]
    ibm_data = st.pack("<32f", *ibm_root, *ibm_leg)

    pos_b = st.pack("<12f", *positions)
    nrm_b = st.pack("<12f", *normals)
    uv_b = st.pack("<8f", *uvs)
    jnt_b = st.pack("<16H", *joints)
    wgt_b = st.pack("<16f", *weights)
    idx_b = st.pack("<6H", *indices)

    off = 0
    views: list[dict] = []
    bin_parts: list[bytes] = []

    def add(data: bytes, target: int | None = None) -> int:
        nonlocal off
        idx = len(views)
        v: dict = {"buffer": 0, "byteOffset": off, "byteLength": len(data)}
        if target is not None:
            v["target"] = target
        views.append(v)
        bin_parts.append(data)
        off += len(data)
        pad = (4 - off % 4) % 4
        if pad:
            bin_parts.append(b"\x00" * pad)
            off += pad
        return idx

    bv_pos = add(pos_b, 34962)
    bv_nrm = add(nrm_b, 34962)
    bv_uv = add(uv_b, 34962)
    bv_jnt = add(jnt_b, 34962)
    bv_wgt = add(wgt_b, 34962)
    bv_idx = add(idx_b, 34963)
    bv_ibm = add(ibm_data)

    # walk clip: rotate joint 1 (leg) around X
    times = [0.0, 0.25, 0.5, 0.75, 1.0]
    rots: list[float] = []
    for t in times:
        ang = math.sin(t * math.pi * 2) * 0.35
        rots.extend([math.sin(ang / 2), 0.0, 0.0, math.cos(ang / 2)])
    time_b = st.pack(f"<{len(times)}f", *times)
    rot_b = st.pack(f"<{len(rots)}f", *rots)
    bv_times = add(time_b)
    bv_rots = add(rot_b)
    bin_data = b"".join(bin_parts)

    accessors = [
        {"bufferView": bv_pos, "componentType": 5126, "count": 4, "type": "VEC3",
         "max": [0.3, 1.2, 0.0], "min": [-0.3, 0.0, 0.0]},
        {"bufferView": bv_nrm, "componentType": 5126, "count": 4, "type": "VEC3"},
        {"bufferView": bv_uv, "componentType": 5126, "count": 4, "type": "VEC2"},
        {"bufferView": bv_jnt, "componentType": 5123, "count": 4, "type": "VEC4"},
        {"bufferView": bv_wgt, "componentType": 5126, "count": 4, "type": "VEC4"},
        {"bufferView": bv_idx, "componentType": 5123, "count": 6, "type": "SCALAR"},
        {"bufferView": bv_ibm, "componentType": 5126, "count": 2, "type": "MAT4"},
        {"bufferView": bv_times, "componentType": 5126, "count": 5, "type": "SCALAR",
         "max": [1.0], "min": [0.0]},
        {"bufferView": bv_rots, "componentType": 5126, "count": 5, "type": "VEC4"},
    ]
    gltf = {
        "asset": {"version": "2.0", "generator": "lynx-wave14"},
        "buffers": [{"byteLength": len(bin_data)}],
        "bufferViews": views,
        "accessors": accessors,
        "meshes": [{
            "primitives": [{
                "attributes": {
                    "POSITION": 0,
                    "NORMAL": 1,
                    "TEXCOORD_0": 2,
                    "JOINTS_0": 3,
                    "WEIGHTS_0": 4,
                },
                "indices": 5,
                "skin": 0,
            }]
        }],
        "nodes": [
            {"name": "root", "translation": [0, 0.6, -2.5]},
            {"name": "leg", "translation": [0, 0.6, 0], "children": []},
            {"name": "mesh", "mesh": 0, "skin": 0},
        ],
        "skins": [{
            "inverseBindMatrices": 6,
            "joints": [0, 1],
        }],
        "animations": [{
            "name": "walk",
            "channels": [{
                "sampler": 0,
                "target": {"node": 1, "path": "rotation"},
            }],
            "samplers": [{
                "input": 7,
                "output": 8,
                "interpolation": "LINEAR",
            }],
        }],
        "scenes": [{"nodes": [2]}],
        "scene": 0,
    }
    # fix node hierarchy: leg child of root
    gltf["nodes"][0]["children"] = [1]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(_pack_glb(gltf, bin_data))


def _write_textures(tex_dir: Path) -> None:
    tex_dir.mkdir(parents=True, exist_ok=True)
    if Image is None:
        # minimal PNG header fallback — PIL expected in dev env
        raise RuntimeError("Pillow required: pip install Pillow")
    albedo = Image.new("RGBA", (128, 128), (161, 136, 127, 255))
    d = ImageDraw.Draw(albedo)
    for y in range(0, 128, 16):
        for x in range(0, 128, 16):
            c = (120, 90, 70, 255) if ((x // 16) + (y // 16)) % 2 == 0 else (180, 150, 120, 255)
            d.rectangle([x, y, x + 15, y + 15], fill=c)
    albedo.save(tex_dir / "crate_albedo.png")

    normal = Image.new("RGBA", (128, 128), (128, 128, 255, 255))
    nd = ImageDraw.Draw(normal)
    nd.rectangle([8, 8, 120, 120], outline=(140, 140, 255, 255), width=4)
    normal.save(tex_dir / "crate_normal.png")

    hm = Image.new("RGBA", (64, 64), (0, 0, 0, 255))
    hd = ImageDraw.Draw(hm)
    for z in range(64):
        for x in range(64):
            u = x / 63.0
            v = z / 63.0
            h = int(
                128
                + 40 * math.sin(u * math.pi * 2)
                + 30 * math.cos(v * math.pi * 2)
            )
            hm.putpixel((x, z), (max(0, min(255, h)), 0, 0, 255))
    hm.save(tex_dir.parent / "terrain" / "hm.png")


def _write_scene_json() -> None:
    scene = {
        "formatVersion": 3,
        "id": "main",
        "name": "3D Room Wave14",
        "objects": [
            {
                "id": "crate_3d",
                "name": "Crate",
                "x": 480, "y": 400, "width": 32, "height": 32,
                "rotation": 0, "scaleX": 1, "scaleY": 1, "z": 0,
                "active": True, "visible": True, "locked": False,
                "layerId": "default",
                "assetId": "assets_sprites_hero.png",
                "scriptId": None,
                "properties": {
                    "lynx.3d": {
                        "mesh": "assets/models/crate.glb",
                        "transform": {
                            "position": [0, 3, 0],
                            "rotationEuler": [0, 25, 0],
                            "scale": [1, 1, 1],
                        },
                        "halfExtents": [0.5, 0.5, 0.5],
                        "color": "#FFFFFF",
                        "material": {
                            "metallic": 0.15,
                            "roughness": 0.65,
                            "albedoTexture": "assets/textures/crate_albedo.png",
                            "normalTexture": "assets/textures/crate_normal.png",
                        },
                        "physics": {
                            "bodyType": "dynamic",
                            "restitution": 0.15,
                            "friction": 0.55,
                        },
                    }
                },
            },
            {
                "id": "hero_3d",
                "name": "Hero",
                "x": 520, "y": 400, "width": 32, "height": 32,
                "rotation": 0, "scaleX": 1, "scaleY": 1, "z": 0,
                "active": True, "visible": True, "locked": False,
                "layerId": "default",
                "assetId": "assets_sprites_hero.png",
                "scriptId": None,
                "properties": {
                    "lynx.3d": {
                        "mesh": "assets/models/hero_skinned.glb",
                        "transform": {
                            "position": [2.5, 0, -2.5],
                            "rotationEuler": [0, -30, 0],
                            "scale": [1, 1, 1],
                        },
                        "halfExtents": [0.3, 0.6, 0.15],
                        "color": "#90CAF9",
                        "animationClip": "walk",
                        "animationTime": 0,
                        "physics": {"bodyType": "static"},
                    }
                },
            },
        ],
        "layers": [{"id": "default", "name": "Default", "visible": True, "locked": False, "z": 0}],
        "tilemaps": [],
        "createdAt": "2026-06-02T12:00:00.000Z",
        "modifiedAt": "2026-06-05T12:00:00.000Z",
        "revision": 2,
        "extensions": {
            "lynx.3d": {
                "active": True,
                "world": {
                    "ambientColor": "#2A3040",
                    "gravity": [0, -9.81, 0],
                    "culling": {"frustum": True, "hiZ": True, "hiZSize": 64},
                    "render": {
                        "iblStrength": 0.45,
                        "postEnabled": True,
                        "exposure": 1.05,
                        "bloom": 0.18,
                    },
                    "lighting": {
                        "directionalColor": "#FFEECC",
                        "directionalIntensity": 1.0,
                    },
                },
                "camera": {
                    "type": "perspective",
                    "fovY": 55,
                    "near": 0.1,
                    "far": 500,
                    "orbitDistance": 14,
                },
                "room": {
                    "width": 8,
                    "height": 4,
                    "depth": 8,
                    "center": [0, 2, 0],
                },
                "terrain": {
                    "heightmap": "assets/terrain/hm.png",
                    "size": [12, 1.5, 12],
                    "center": [0, 0.5, 0],
                    "segments": 32,
                    "maxLod": 2,
                    "lodSplitDistance": 8,
                    "clipmapLevels": 2,
                    "color": "#3D5C3D",
                    "material": {"metallic": 0.0, "roughness": 0.9},
                },
                "physicsJoints": [
                    {
                        "type": "hinge",
                        "bodyA": "crate_3d",
                        "bodyB": "hero_3d",
                        "anchor": [1.2, 1.0, -2.5],
                        "axis": [0, 1, 0],
                        "minAngleDeg": -25,
                        "maxAngleDeg": 25,
                    }
                ],
                "objects": [
                    {
                        "id": "crate_3d",
                        "mesh": "assets/models/crate.glb",
                        "transform": {
                            "position": [0, 3, 0],
                            "rotationEuler": [0, 25, 0],
                            "scale": [1, 1, 1],
                        },
                        "halfExtents": [0.5, 0.5, 0.5],
                        "color": "#FFFFFF",
                        "material": {
                            "metallic": 0.15,
                            "roughness": 0.65,
                            "albedoTexture": "assets/textures/crate_albedo.png",
                            "normalTexture": "assets/textures/crate_normal.png",
                        },
                        "physics": {
                            "bodyType": "dynamic",
                            "restitution": 0.15,
                            "friction": 0.55,
                        },
                    },
                    {
                        "id": "hero_3d",
                        "mesh": "assets/models/hero_skinned.glb",
                        "transform": {
                            "position": [2.5, 0, -2.5],
                            "rotationEuler": [0, -30, 0],
                            "scale": [1, 1, 1],
                        },
                        "halfExtents": [0.3, 0.6, 0.15],
                        "color": "#90CAF9",
                        "animationClip": "walk",
                        "animationTime": 0,
                        "physics": {"bodyType": "static"},
                    },
                ],
            }
        },
    }
    scenes = DEMO / "scenes"
    scenes.mkdir(parents=True, exist_ok=True)
    (scenes / "main.json").write_text(
        json.dumps(scene, indent=2, ensure_ascii=False), encoding="utf-8"
    )


def generate_wave14_demo() -> None:
    models = DEMO / "assets" / "models"
    tex = DEMO / "assets" / "textures"
    (DEMO / "assets" / "terrain").mkdir(parents=True, exist_ok=True)
    _write_crate_glb(models / "crate.glb")
    _write_hero_skinned_glb(models / "hero_skinned.glb")
    _write_textures(tex)
    meta = {"source": "assets/models/crate.glb", "halfExtents": [0.5, 0.5, 0.5]}
    (models / "crate.lynx3d.json").write_text(json.dumps(meta, indent=2), encoding="utf-8")
    _write_scene_json()
    print("Wave 14 demo assets at", DEMO)


if __name__ == "__main__":
    generate_wave14_demo()

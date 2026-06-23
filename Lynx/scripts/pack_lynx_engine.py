#!/usr/bin/env python3
"""Pack Lynx Engine release into proprietary .lynxengine (encrypted zip payload)."""

from __future__ import annotations

import argparse
import hashlib
import hmac
import json
import os
import struct
import sys
import zipfile
from datetime import datetime, timezone
from io import BytesIO
from pathlib import Path

try:
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM
except ImportError as exc:  # pragma: no cover
    print("Install cryptography: pip install cryptography", file=sys.stderr)
    raise SystemExit(1) from exc

MAGIC = b"LYNXENG1"
HEADER_SCHEMA = 1
MASTER_SEED = b"LynxEnginePack:v1:PO-Lynx-2026"

PLATFORM_LIBS = {
    "windows": "engine.dll",
    "linux": "libengine.so",
    "macos": "libengine.dylib",
}

# E24c — optional iOS static lib / xcframework zip entry (extras/ios/).
IOS_ARTIFACT_NAME = "engine.xcframework.zip"


def derive_key(version: str, platform: str) -> bytes:
    root = hashlib.sha256(MASTER_SEED).digest()
    return hmac.new(root, f"{version}:{platform}".encode("utf-8"), hashlib.sha256).digest()


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def build_inner_zip(
    lib_path: Path,
    lib_name: str,
    shaders_dir: Path | None,
    extras_dir: Path | None = None,
    ios_xcframework_zip: Path | None = None,
) -> bytes:
    buf = BytesIO()
    has_shell = False
    has_player = False
    has_templates = False
    with zipfile.ZipFile(buf, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        zf.write(lib_path, lib_name)
        if shaders_dir and shaders_dir.is_dir():
            for p in shaders_dir.rglob("*"):
                if p.is_file():
                    arc = str(Path("shaders") / p.relative_to(shaders_dir))
                    zf.write(p, arc.replace("\\", "/"))
        if extras_dir and extras_dir.is_dir():
            for p in extras_dir.rglob("*"):
                if not p.is_file():
                    continue
                rel = p.relative_to(extras_dir).as_posix()
                arc = f"extras/{rel}"
                zf.write(p, arc)
                low = rel.lower()
                if low.endswith("lynxengine.exe"):
                    has_shell = True
                if "/player/" in f"/{low}/" or low.startswith("player/"):
                    has_player = True
                if "/templates/" in f"/{low}/" or low.startswith("templates/"):
                    has_templates = True
        if ios_xcframework_zip and ios_xcframework_zip.is_file():
            zf.write(ios_xcframework_zip, f"extras/ios/{IOS_ARTIFACT_NAME}")
        inner = {
            "format": "lynxengine_inner",
            "schema": 2,
            "libraryName": lib_name,
            "hasShell": has_shell,
            "hasPlayerTemplate": has_player,
            "hasTemplates": has_templates,
            "hasIosXcframework": bool(ios_xcframework_zip and ios_xcframework_zip.is_file()),
        }
        zf.writestr("inner_manifest.json", json.dumps(inner, indent=2))
    return buf.getvalue()


def pack_lynxengine(
    *,
    version: str,
    platform: str,
    lib_path: Path,
    out_path: Path,
    lynx_core_version: str = "0.6.0-m6",
    core_api_version: int = 4,
    shaders_dir: Path | None = None,
    extras_dir: Path | None = None,
    ios_xcframework_zip: Path | None = None,
) -> None:
    lib_name = PLATFORM_LIBS.get(platform)
    if not lib_name:
        raise ValueError(f"unsupported platform: {platform}")
    if not lib_path.is_file():
        raise FileNotFoundError(lib_path)

    plain = build_inner_zip(lib_path, lib_name, shaders_dir, extras_dir, ios_xcframework_zip)
    key = derive_key(version, platform)
    nonce = os.urandom(12)
    encrypted = nonce + AESGCM(key).encrypt(nonce, plain, None)

    manifest = {
        "format": "lynxengine",
        "schema": HEADER_SCHEMA,
        "version": version,
        "lynxCoreVersion": lynx_core_version,
        "coreApiVersion": core_api_version,
        "platform": platform,
        "libraryName": lib_name,
        "payloadSha256": sha256_bytes(plain),
        "builtAt": datetime.now(timezone.utc).isoformat(),
    }
    manifest_bytes = json.dumps(manifest, ensure_ascii=False).encode("utf-8")

    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("wb") as f:
        f.write(MAGIC)
        f.write(struct.pack("<I", HEADER_SCHEMA))
        f.write(struct.pack("<I", len(manifest_bytes)))
        f.write(manifest_bytes)
        f.write(encrypted)

    print(f"OK: {out_path} ({len(encrypted)} bytes encrypted payload)")


def main() -> None:
    parser = argparse.ArgumentParser(description="Pack Lynx Engine into .lynxengine")
    parser.add_argument("--version", required=True)
    parser.add_argument("--platform", choices=sorted(PLATFORM_LIBS), default="windows")
    parser.add_argument("--lib", type=Path, help="Path to engine.dll / libengine.so")
    parser.add_argument("--engine-dir", type=Path, help="Repo engine/ folder (uses target/release)")
    parser.add_argument("--shaders", type=Path, help="Compiled HLSL shaders directory")
    parser.add_argument(
        "--ios-xcframework-zip",
        type=Path,
        help="E24c: zipped engine.xcframework for iOS (optional)",
    )
    parser.add_argument(
        "--extras-dir",
        type=Path,
        help="E22c/E23c: shell/LynxEngine.exe, player/, templates/ staged under this folder",
    )
    parser.add_argument("--lynx-core-version", default="1.0.0")
    parser.add_argument("--core-api-version", type=int, default=5)
    parser.add_argument("-o", "--out", type=Path, required=True)
    args = parser.parse_args()

    root = Path(__file__).resolve().parent.parent
    lib = args.lib
    if lib is None:
        engine_dir = args.engine_dir or (root / "engine")
        rel = "release" if (engine_dir / "target" / "release").exists() else "debug"
        lib = engine_dir / "target" / rel / PLATFORM_LIBS[args.platform]
    shaders = args.shaders or (root / "lynx-core" / "shaders" / "compiled")

    pack_lynxengine(
        version=args.version,
        platform=args.platform,
        lib_path=lib,
        out_path=args.out,
        lynx_core_version=args.lynx_core_version,
        core_api_version=args.core_api_version,
        shaders_dir=shaders if shaders.is_dir() else None,
        extras_dir=args.extras_dir if args.extras_dir and args.extras_dir.is_dir() else None,
        ios_xcframework_zip=args.ios_xcframework_zip if args.ios_xcframework_zip and args.ios_xcframework_zip.is_file() else None,
    )


if __name__ == "__main__":
    main()

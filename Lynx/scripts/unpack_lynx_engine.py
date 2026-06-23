#!/usr/bin/env python3
"""Dev utility: decrypt .lynxengine and extract inner zip."""

from __future__ import annotations

import argparse
import hashlib
import hmac
import json
import struct
import sys
import zipfile
from pathlib import Path

try:
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM
except ImportError as exc:  # pragma: no cover
    print("Install cryptography: pip install cryptography", file=sys.stderr)
    raise SystemExit(1) from exc

MAGIC = b"LYNXENG1"
MASTER_SEED = b"LynxEnginePack:v1:PO-Lynx-2026"


def derive_key(version: str, platform: str) -> bytes:
    root = hashlib.sha256(MASTER_SEED).digest()
    return hmac.new(root, f"{version}:{platform}".encode("utf-8"), hashlib.sha256).digest()


def unpack(path: Path, out_dir: Path) -> None:
    raw = path.read_bytes()
    if raw[:8] != MAGIC:
        raise ValueError("bad magic")
    schema = struct.unpack_from("<I", raw, 8)[0]
    if schema != 1:
        raise ValueError(f"unsupported schema {schema}")
    mlen = struct.unpack_from("<I", raw, 12)[0]
    manifest = json.loads(raw[16 : 16 + mlen].decode("utf-8"))
    blob = raw[16 + mlen :]
    if len(blob) < 12 + 16:
        raise ValueError("truncated payload")

    version = manifest["version"]
    platform = manifest["platform"]
    key = derive_key(version, platform)
    nonce = blob[:12]
    plain = AESGCM(key).decrypt(nonce, blob[12:], None)
    expect = manifest.get("payloadSha256", "").lower()
    got = hashlib.sha256(plain).hexdigest()
    if expect and expect != got:
        raise ValueError(f"payload sha256 mismatch: {got} != {expect}")

    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    from io import BytesIO

    with zipfile.ZipFile(BytesIO(plain)) as zf:
        zf.extractall(out_dir)
    print(f"OK: extracted to {out_dir}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("file", type=Path)
    parser.add_argument("-o", "--out", type=Path, required=True)
    args = parser.parse_args()
    unpack(args.file, args.out)


if __name__ == "__main__":
    main()

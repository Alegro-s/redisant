import gzip
import hashlib
import os

from cryptography.hazmat.primitives.ciphers.aead import AESGCM

_NONCE_LEN = 12
_ENCODING = "aes-gcm-gzip-v1"

def derive_voice_key(chat_token: str, username: str) -> bytes:
    raw = f"{chat_token}:nt-voice:v1:{username}".encode("utf-8")
    return hashlib.sha256(raw).digest()

def pack_voice(plain_audio: bytes, chat_token: str, username: str) -> bytes:
    compressed = gzip.compress(plain_audio, compresslevel=6)
    nonce = os.urandom(_NONCE_LEN)
    key = derive_voice_key(chat_token, username)
    ct = AESGCM(key).encrypt(nonce, compressed, None)
    return nonce + ct

def unpack_voice(blob: bytes, chat_token: str, username: str) -> bytes:
    if len(blob) < _NONCE_LEN + 16:
        return blob
    nonce, ct = blob[:_NONCE_LEN], blob[_NONCE_LEN:]
    key = derive_voice_key(chat_token, username)
    compressed = AESGCM(key).decrypt(nonce, ct, None)
    return gzip.decompress(compressed)

def encoding_header() -> str:
    return _ENCODING

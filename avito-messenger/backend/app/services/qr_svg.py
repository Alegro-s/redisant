from __future__ import annotations

def _segno_svg(text: str, scale: int) -> str:
    import segno

    qr = segno.make(text, error="m")
    return qr.svg_inline(scale=scale, dark="#141414", light="#ffffff", xmldecl=False, nodoc=True)

def _pyqrcode_svg(text: str, scale: int) -> str:
    import pyqrcode

    qr = pyqrcode.create(text, error="M")
    return qr.svg(scale=scale, module_color="#141414", background="#ffffff", quiet_zone=2)

def qr_svg_markup(text: str, scale: int = 5) -> str:
    for maker in (_segno_svg, _pyqrcode_svg):
        try:
            return maker(text, scale)
        except Exception:
            continue
    raise RuntimeError("QR backends unavailable")

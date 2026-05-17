from __future__ import annotations

from pathlib import Path


def _normalize_roots(roots: list[Path]) -> list[Path]:
    return [r.resolve() for r in roots]


def resolve_under_roots(rel_path: str, roots: list[Path]) -> Path:
    """Разрешить относительный путь только внутри объединения roots (защита от ..)."""
    if not roots:
        raise ValueError("Не заданы workspace.roots — чтение/запись файлов запрещено.")
    raw = Path(rel_path.replace("\\", "/").lstrip("/"))
    if raw.is_absolute() or ".." in raw.parts:
        raise ValueError("Путь должен быть относительным без '..'.")
    for root in _normalize_roots(roots):
        candidate = (root / raw).resolve()
        try:
            candidate.relative_to(root)
        except ValueError:
            continue
        return candidate
    raise ValueError(f"Путь «{rel_path}» вне разрешённых корней workspace.")


def read_text(
    rel_path: str,
    roots: list[Path],
    *,
    max_chars: int = 120_000,
) -> str:
    path = resolve_under_roots(rel_path, roots)
    if not path.is_file():
        raise FileNotFoundError(str(path))
    text = path.read_text(encoding="utf-8", errors="replace")
    if len(text) > max_chars:
        return (
            text[:max_chars]
            + f"\n\n[… файл обрезан после {max_chars} символов; уточните диапазон строк или путь]"
        )
    return text


def list_dir_formatted(
    rel_dir: str,
    roots: list[Path],
    *,
    max_entries: int = 250,
) -> str:
    """Список имён в каталоге относительно корня workspace (для агента)."""
    rel = (rel_dir or ".").strip() or "."
    path = resolve_under_roots(rel, roots)
    if not path.is_dir():
        raise NotADirectoryError(str(path))
    lines: list[str] = []
    n = 0
    for child in sorted(path.iterdir(), key=lambda p: (not p.is_dir(), p.name.lower())):
        if n >= max_entries:
            lines.append(f"... (показано не более {max_entries} элементов)")
            break
        kind = "dir" if child.is_dir() else "file"
        rel_child = child.relative_to(path)
        lines.append(f"[{kind}] {rel_child.as_posix()}")
        n += 1
    if not lines:
        return "(каталог пуст)"
    return "\n".join(lines)


def list_dir_json(rel_dir: str, roots: list[Path], *, max_entries: int = 500) -> list[dict[str, str]]:
    """Структура для API: name, type, path (posix относительно запрошенного каталога)."""
    rel = (rel_dir or ".").strip() or "."
    base = resolve_under_roots(rel, roots)
    if not base.is_dir():
        raise NotADirectoryError(str(base))
    out: list[dict[str, str]] = []
    for child in sorted(base.iterdir(), key=lambda p: (not p.is_dir(), p.name.lower())):
        if len(out) >= max_entries:
            break
        out.append(
            {
                "name": child.name,
                "type": "dir" if child.is_dir() else "file",
                "path": child.relative_to(base).as_posix(),
            }
        )
    return out


def write_text(rel_path: str, roots: list[Path], content: str) -> str:
    path = resolve_under_roots(rel_path, roots)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    return str(path)

"""Датасеты и экспорт в форматы для внешнего SFT (LlamaFactory и др.)."""
from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any, Iterator

import yaml

from roza.config import Settings

SAFE_NAME = re.compile(r"^[\w.\-]+$")


def datasets_dir(settings: Settings) -> Path:
    p = settings.config_dir / "data" / "datasets"
    p.mkdir(parents=True, exist_ok=True)
    return p


def resolve_dataset_file(settings: Settings, name: str) -> Path:
    """Файл из data/datasets по имени (без path traversal)."""
    name = (name or "").strip().replace("\\", "/").split("/")[-1]
    if not name or not SAFE_NAME.match(name):
        raise ValueError("Некорректное имя файла датасета.")
    root = datasets_dir(settings).resolve()
    p = (root / name).resolve()
    if not str(p).startswith(str(root)) or not p.is_file():
        raise ValueError("Файл датасета не найден.")
    return p


def metrics_path(settings: Settings) -> Path:
    return settings.config_dir / "data" / "metrics_eval.json"


def skills_path(settings: Settings) -> Path:
    return settings.config_dir / "skills.yaml"


def row_messages_to_sharegpt(messages: list[dict[str, Any]]) -> dict[str, Any] | None:
    """Одна строка Roza learn → ShareGPT conversations."""
    conv: list[dict[str, str]] = []
    for m in messages:
        role = str(m.get("role") or "")
        content = str(m.get("content") or "")
        if role == "system":
            continue
        if role == "user":
            conv.append({"from": "human", "value": content})
        elif role == "assistant":
            conv.append({"from": "gpt", "value": content})
    if len(conv) < 2:
        return None
    return {"conversations": conv}


def iter_learn_sharegpt(learn_path: Path) -> Iterator[dict[str, Any]]:
    if not learn_path.is_file():
        return
    with learn_path.open(encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue
            msgs = row.get("messages")
            if not isinstance(msgs, list):
                continue
            sg = row_messages_to_sharegpt(msgs)
            if sg is not None:
                yield sg


def export_learn_to_sharegpt_jsonl(settings: Settings, dest_name: str) -> Path:
    if not SAFE_NAME.match(dest_name):
        raise ValueError("Некорректное имя файла экспорта.")
    dest = datasets_dir(settings) / dest_name
    n = 0
    with dest.open("w", encoding="utf-8") as out:
        for sg in iter_learn_sharegpt(settings.learning_log_path):
            out.write(json.dumps(sg, ensure_ascii=False) + "\n")
            n += 1
    if n == 0:
        dest.unlink(missing_ok=True)
        raise ValueError("Нет подходящих диалогов в журнале обучения.")
    return dest


def load_skills_dashboard(settings: Settings) -> dict[str, Any]:
    p = skills_path(settings)
    if p.is_file():
        with p.open(encoding="utf-8") as f:
            raw = yaml.safe_load(f) or {}
    else:
        raw = {"tree": []}

    metrics_map: dict[str, bool] = {}
    mp = metrics_path(settings)
    if mp.is_file():
        try:
            data = json.loads(mp.read_text(encoding="utf-8"))
            for t in data.get("tasks") or []:
                tid = str(t.get("id", ""))
                if tid:
                    metrics_map[tid] = bool(t.get("ok"))
        except (json.JSONDecodeError, OSError):
            pass

    def annotate(nodes: list[Any]) -> list[Any]:
        out = []
        for n in nodes:
            if not isinstance(n, dict):
                continue
            node = dict(n)
            et = node.get("eval_task")
            if et and str(et) in metrics_map:
                node["status"] = "ok" if metrics_map[str(et)] else "fail"
            else:
                node["status"] = node.get("status") or "unknown"
            ch = node.get("children")
            if isinstance(ch, list) and ch:
                node["children"] = annotate(ch)
            out.append(node)
        return out

    tree = raw.get("tree") or []
    if not isinstance(tree, list):
        tree = []
    return {
        "tree": annotate(tree),
        "metrics_loaded": bool(metrics_map),
        "llm_backend": settings.llm_backend,
    }


def merge_sharegpt_files(settings: Settings, filenames: list[str], dest_name: str) -> Path:
    if not SAFE_NAME.match(dest_name):
        raise ValueError("Некорректное имя выходного файла.")
    root = datasets_dir(settings)
    dest = root / dest_name
    count = 0
    with dest.open("w", encoding="utf-8") as out:
        for name in filenames:
            if not SAFE_NAME.match(name):
                continue
            p = (root / name).resolve()
            if not str(p).startswith(str(root.resolve())) or not p.is_file():
                continue
            with p.open(encoding="utf-8") as inf:
                for line in inf:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        obj = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    if isinstance(obj, dict) and "conversations" in obj:
                        out.write(json.dumps(obj, ensure_ascii=False) + "\n")
                        count += 1
    if count == 0:
        dest.unlink(missing_ok=True)
        raise ValueError("Не удалось объединить файлы (пусто или неверный формат).")
    return dest

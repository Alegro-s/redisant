from __future__ import annotations

import argparse
import sys
from pathlib import Path

from roza.config import load_settings
from roza.eval.metrics import evaluate_all, save_metrics


def run_eval(settings, tasks_path: Path) -> int:
    res = evaluate_all(settings, tasks_path)
    if res.get("error") == "no_tasks":
        print("Нет задач.", file=sys.stderr)
        return 1

    for tr in res.get("tasks") or []:
        tid = tr.get("id", "?")
        if tr.get("error"):
            print(f"--- Задача {tid} ---\nОшибка: {tr['error']}\n")
            continue
        ok = tr.get("ok")
        if ok:
            print(f"--- Задача {tid} ---\nРезультат: OK\n")
        else:
            miss = tr.get("missing") or []
            print(f"--- Задача {tid} ---\nРезультат: FAIL (нет: {', '.join(miss)})\n")

    passed = res.get("passed", 0)
    total = res.get("total", 0)
    pct = res.get("percent", 0)
    print(f"Итого: {passed}/{total} ({pct}%) по проверке must_contain.")
    print(
        "Это грубый индикатор. Для серьёзного бенчмарка используйте выполнение тестов в песочнице (HumanEval и т.п.)."
    )

    save_metrics(settings, res)
    print(f"Метрики сохранены: {settings.config_dir / 'data' / 'metrics_eval.json'}")
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description="Оценка ответов модели на задачи из YAML.")
    p.add_argument(
        "-c",
        "--config",
        type=Path,
        default=None,
        help="Путь к config.yaml",
    )
    p.add_argument(
        "-t",
        "--tasks",
        type=Path,
        default=None,
        help="Путь к code_tasks.yaml (по умолчанию eval/code_tasks.yaml рядом с конфигом)",
    )
    args = p.parse_args()

    try:
        settings = load_settings(args.config)
    except FileNotFoundError as e:
        print(e, file=sys.stderr)
        return 1

    if args.tasks is not None:
        tasks_path = args.tasks.resolve()
    else:
        tasks_path = (settings.config_dir / "eval" / "code_tasks.yaml").resolve()
    if not tasks_path.is_file():
        print(f"Файл задач не найден: {tasks_path}", file=sys.stderr)
        return 1

    return run_eval(settings, tasks_path)


if __name__ == "__main__":
    raise SystemExit(main())

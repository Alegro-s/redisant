"""CLI: python -m roza.train --job path/to/job.json"""
from __future__ import annotations

import argparse
import json
import os
import sys
import traceback
from datetime import datetime
from pathlib import Path

from roza.train.job import write_job_status


def _run_job(job_path: Path) -> int:
    cfg = json.loads(job_path.read_text(encoding="utf-8"))
    status_p = Path(cfg["status_path"])
    log_p = Path(cfg["log_path"])

    def slog(line: str) -> None:
        with log_p.open("a", encoding="utf-8") as f:
            f.write(line.rstrip() + "\n")

    try:
        import logging

        logging.getLogger("transformers").setLevel(logging.WARNING)
        logging.getLogger("trl").setLevel(logging.WARNING)
    except Exception:
        pass

    write_job_status(
        status_p,
        {
            "state": "running",
            "message": "Обучение…",
            "started": datetime.now().isoformat(),
            "output_dir": cfg.get("output_dir", ""),
            "run_name": cfg.get("run_name", ""),
            "pid": os.getpid(),
        },
    )

    try:
        from roza.train.lora_sft import run_lora_sft

        run_lora_sft(cfg, log_p)
    except Exception as e:
        slog(traceback.format_exc())
        write_job_status(
            status_p,
            {
                "state": "error",
                "message": f"{type(e).__name__}: {e}",
                "finished": datetime.now().isoformat(),
                "output_dir": cfg.get("output_dir", ""),
                "run_name": cfg.get("run_name", ""),
                "pid": 0,
            },
        )
        return 1

    write_job_status(
        status_p,
        {
            "state": "done",
            "message": "Готово",
            "finished": datetime.now().isoformat(),
            "output_dir": cfg.get("output_dir", ""),
            "run_name": cfg.get("run_name", ""),
            "pid": 0,
        },
    )
    return 0


def main(argv: list[str] | None = None) -> int:
    argv = argv if argv is not None else sys.argv[1:]
    if argv and argv[0] == "merge":
        from roza.train.merge_adapter import merge_main

        return merge_main(argv[1:])

    ap = argparse.ArgumentParser(prog="roza.train")
    ap.add_argument("--job", type=Path, required=True, help="JSON с параметрами обучения")
    ns = ap.parse_args(argv)
    return _run_job(ns.job.resolve())


if __name__ == "__main__":
    raise SystemExit(main())
